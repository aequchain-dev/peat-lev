# PEAT Project — Technical Summary

## What is PEAT?

Parametric Electro-Active Thruster (PEAT): levitation via dual-coil electromagnetic oscillation. The reaction mass oscillates between two coils; the drive alternates attract/repel at the oscillation frequency (2× the mechanical resonance), pumping energy into the system. The thrust (vehicle lift) is the reaction force on the chassis.

## Three Simulation Tracks

### 1. `sim/` — 6-DOF Magnetic Levitation (Julia)

**File:** `src/Levitation6D.jl` (932 lines)

A 4-coil PM-biased electromagnetic array with:

- **6-DOF PID control** (x, y, z, roll, pitch, yaw) via actuation matrix pseudoinverse
- **Bidirectional current regulators** per coil
- **PM bias** (14 N/coil at reference gap) handles static weight, coils provide control authority
- **Lateral divergence fix** (OPTIBEST certified 2026-06-14): Added `k_lat_direct = 0.5 N/A` + passive PM centering `k_center_total = 20000 N/m`

**Key results:**
- X/Y error: **272 m → 0.52 mm** (523,000× improvement)
- Z error: ~0.00 mm
- 0.52 mm residual is a **rank-4 fundamental limit** (4 coils, 6 DOFs)
- Self-powered at 2.17 W average

**Scripts:**
- `scripts/phase1_hover.jl` — basic hover
- `scripts/phase2_6dof.jl` — full 6-DOF simulation
- `scripts/debug_control.jl`, `debug_trace.jl`, `debug_pinv.jl` — diagnostics

**Docs:** `docs/lateral_divergence_fix_CERTIFICATION.md`

---

### 2. `peat_sim/` — PEAT Thruster ODE Model (Julia)

**File:** `src/PeatSim.jl` (2404 lines)

Full coupled ODE model of a single-axis dual-coil electromagnetic oscillator:

**Core physics:**
- Sigmoid inductance model: `L(x) = L_base + ΔL·(1 + tanh(x/δ_L))/2` (naturally bounded, no clamping)
- Push-pull drive with velocity-referenced state machine (ATTRACT/REPEL/COAST)
- L/R current-rise limitation — exact `⟨i²⟩` integral via `_lr_rms_factor`
- Selective zero-crossing braking to prevent residual-current opposition
- Generator damping from pickup coil
- ContinuousCallack for velocity zero-crossing phase tracking

**Analytical model:**
- `analytical_thrust()` — closed-form thrust including L/R-limited current rise
- `analytical_power()` — pump power, copper loss, thrust power, pickup recovery
- `stroke_dldx_correction()` — position-weighted dL/dx averaging over stroke
- `saturated_dldx_peak()` — current-dependent permeability saturation model
- `check_hover_feasibility()` — feasibility check for any parameter set

**Power balance closure** — tracks magnetic field energy (`E_mag = 0.5·L·i²`) for full energy conservation validation.

**Coil geometry engine:**
- `CoilDesign` → `coil_params()`: winding geometry → R_coil, L_base, L_max
- AWG table, Nagaoka's coefficient, Wheeler approximation
- Geometry sweep to discover τ/t_half operating regimes (current_limited / transitional / inductance_dominated)

**H-bridge loss model:**
- `SiCMOSFETParams` + `compute_h_bridge_losses()`: conduction, switching, dead-time, gate-drive losses
- First-order RL current waveform model
- `h_bridge_sweep()`: rank coil geometries by efficiency

**Parameter sweeps:**
- `run_sweep()` (sequential) + `run_sweep_parallel()` (multi-threaded) — analytical
- `run_ode_sweep()` — ODE-based sweep over V_bus, L_max, R_load, etc.
- `cycle_feasibility()` — ODE-based self-sustaining oscillation check via energy at turning points

**Six-axis system:** `SixAxisParams`, `SixAxisState`, `six_axis_ode!` — 6 oscillators in hexagon for full 6-DOF thrust.

**Test suite:** `test/runtests.jl` — 78 `@test` assertions covering parameter init, drive state machine, analytical thrust, hover feasibility, ODE solver, power balance, parameter sweeps, saturated dL/dx, stroke correction, nonlinear thrust, nonlinear feasibility.

**Root cause note:** `docs/ROOT_CAUSE_NOTE.md` — documents the fundamental power insufficiency (generator damping ~1000 W vs drive ~288 W at 48 V) and inverted drive polarity bug that was fixed.

**Scripts:**
- `scripts/demo.jl` — single-config run with analytical + numerical comparison
- `scripts/sweep.jl` — large parameter sweep
- `scripts/thrust_measure.jl` — thrust measurement sweep
- `scripts/feasibility_scanner.jl` — corridor-of-feasibility scan
- `scripts/geometry_sweep.jl` — coil geometry regime discovery
- `scripts/validate_stroke_correction.jl` — stroke correction cross-check

---

### 3. `simulation/` — Python Analytical + Calibration Models

**Files:**
- `peat_sim_v2.py` (~600 lines) — Analytical model with `AnalyticalModel`, `SixOscillatorArray`, RK4 numerical integrator, energy balance, multi-oscillator assembly
- `calibration_controller.py` (346 lines) — Kalman-filter PLL, gain scheduling, energy-balance regulation for the 2ω₀ parametric pump
- `verify_peat.py` (67 lines) — Cross-check analytical vs numerical across 3 mass scales (5 kg drone, 115 kg human, 1200 kg hovercar)

---
