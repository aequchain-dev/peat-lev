# Chapter 9: Simulation Suite

| Attribute | Value |
|-----------|-------|
| **Version** | 1.1 |
| **Status** | OPTIBEST REVIEWED |

The PEAT simulation suite consists of **three independent codebases** developed in parallel,
each serving a distinct purpose within the overall framework:

| Track | Language | Location | Purpose | Lines | Tests |
|-------|----------|----------|---------|-------|-------|
| **A** | Julia | `peat_sim/` | Single-oscillator ODE feasibility study | 2,404 | 71 |
| **B** | Julia | `sim/` | Calibrated levitation (1-DOF → 6-DOF) | ~1,500 | — |
| **C** | Python | `simulation/` | Analytical sweeps & control calibration | ~1,700 | — |

---

## 9.1 Track A — Single-Oscillator ODE (`peat_sim/`)

### 9.1.1 Purpose
Model a single oscillator pair (two coils + reaction mass) with full electromagnetic
coupling to determine whether the asymmetric push-pull drive can sustain oscillation
against generator damping.

### 9.1.2 Key Files

| File | Description |
|------|-------------|
| `src/PeatSim.jl` | 2,404-line module — coupled ODE, drive logic, energy balance |
| `scripts/sweep.jl` | Parameter sweep across 10,260 configurations |
| `scripts/feasibility.jl` | Feasibility region analysis |
| `scripts/geometry_sweep.jl` | Coil geometry optimization sweep |
| `scripts/mass_scaling.jl` | System mass dependency analysis |
| `scripts/thrust_measure.jl` | Thrust measurement and energy balance |
| `test/` | 71 unit tests (all passing) |
| `SUMMARY.md` | Sweep results summary |
| `docs/ROOT_CAUSE_NOTE.md` | Root cause analysis |

### 9.1.3 Core Architecture — `PeatSim.jl`

```text
┌─────────────────────────────────────────────────────────────┐
│                    PeatSim.jl Module                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  OscillatorParams ───→ solve_oscillator ───→ ODESolution     │
│       │                      │                               │
│       │              ┌───────┴────────┐                      │
│       │              │                │                      │
│       ▼              ▼                ▼                      │
│  init_params    get_drive_state   drive_voltage              │
│  (sets t_half,  (velocity-ref)   (current-limited)          │
│   t_attract,                                                 │
│   t_repel,      effective_L      compute_power_balance       │
│   b_gen)        (L(x) model)     (P_net verification)        │
│                                                              │
│  Solver: AutoTsit5(Rodas5P) — adaptive timestep              │
│  with max 10,000 steps at 50 µs resolution                   │
└─────────────────────────────────────────────────────────────┘
```

### 9.1.4 Oscillator Parameter Dataclass

The `OscillatorParams` struct contains all parameters for a single oscillator
pair:

```julia
struct OscillatorParams
    # Mechanical
    m::Float64          # Reaction mass [kg]
    stroke::Float64     # Peak-to-peak amplitude [m]
    k_mech::Float64     # Mechanical spring [N/m]
    b_mech::Float64     # Mechanical damping [N·s/m]
    f_mech::Float64     # Mechanical resonance [Hz]
    x0::Float64         # Initial displacement [m]
    v0::Float64         # Initial velocity [m/s]

    # Coil parameters (dual-coil)
    coil_A::CoilParams  # Primary drive coil
    coil_B::CoilParams  # Secondary drive coil
    d_react::Float64    # Mass-to-coil-face distance [m]
    gap::Float64        # Gap between coils [m]

    # Drive parameters
    V_bus::Float64      # DC bus voltage [V]
    drive_ratio::Float64 # Drive asymmetry factor
    eta::Float64        # Modulation depth (parametric pump)

    # Generator parameters
    b_gen::Float64      # Generator damping coefficient [N·s/m]
    L_gen::Float64      # Generator inductance [H]
    R_gen::Float64      # Generator resistance [Ω]
end
```

### 9.1.5 Drive State Machine

The drive state machine (`get_drive_state`) is the core control logic:

```
Velocity v(t) > 0 (mass moving +x):
    └─▶ ATTRACT coil_A (+V_bus) ──▶ Force toward +x

Velocity v(t) < 0 (mass moving -x):
    └─▶ REPEL coil_A  (-V_bus) ──▶ Force toward -x

Boundary (v ≈ 0): COAST (0 V)

Note: The polarity was INVERTED in the original code. The fixed version
uses the correct velocity-referenced logic shown above.
```

### 9.1.6 Key Discovery — Power Insufficiency

The most important result from Track A:

| Parameter | Value | Description |
|-----------|-------|-------------|
| b_gen | 250 N·s/m | Generator damping coefficient |
| P_gen (peak) | ~1,000 W | Power extracted by generator damping at v ≈ 2 m/s |
| P_drive (max) | ~288 W | Maximum power bus can supply per active coil |
| ΔE (best) | -2.3 J/cycle | Energy loss per cycle — oscillation decays |
| I²R fraction | 99.2% | Fraction of input power lost to copper heating |
| τ = L/R | 100 ms | Coil L/R time constant |
| t_half-cycle | 33 ms | Available drive window |
| Current reversal | ~24% | Fraction of target current reached in available time |

The **root cause** is that the L/R time constant (100 ms) far exceeds the
available drive window (33 ms), so the coil current cannot reverse fast
enough to produce useful force in the correct direction. This causes the
drive to extract energy from the mechanical system during part of each
cycle (negative power), heavily damping the oscillation.

### 9.1.7 71-Passing Test Suite

| Category | Tests | Focus |
|----------|-------|-------|
| Physics | 24 | L(x) model, force equations, resonance, energy conservation |
| Control | 18 | Drive state machine, timing, commutation |
| Scaling | 12 | Parameter scaling laws, mass dependence |
| Energy | 10 | Power balance, efficiency, thermal budget |
| Edge Cases | 7 | Zero mass, zero voltage, infinite resistance, NaN handling |

### 9.1.8 Running Track A

```bash
cd peat_sim
julia --project=. -e 'using Pkg; Pkg.test()'    # Run all 71 tests
julia --project=. scripts/sweep.jl               # 10,260-config sweep
julia --project=. scripts/feasibility.jl         # Feasibility region
julia --project=. scripts/thrust_measure.jl      # Thrust measurement
```

---

## 9.2 Track B — Calibrated Levitation (`sim/`)

### 9.2.1 Purpose
Simulate a complete magnetic levitation system with calibrated electromagnets,
PM bias, and 6-DOF control.

### 9.2.2 Key Files

| File | Description |
|------|-------------|
| `src/LevitationSim.jl` | 1-DOF PM-biased hover simulation (Phase 1) |
| `src/Levitation6D.jl` | 6-DOF with lateral divergence fix (Phase 2) |
| `scripts/phase1_hover.jl` | Phase 1 hover demo |
| `scripts/phase2_6dof.jl` | Phase 2 6-DOF demo |
| `scripts/debug_6dof.jl` | 6-DOF debug/analysis |
| `docs/lateral_divergence_fix_CERTIFICATION.md` | Certification document |

### 9.2.3 Phase 1 — 1-DOF Hover

`LevitationSim.jl` models a single-axis levitation system with:
- Permanent magnet bias for hover offset
- PID control for position regulation
- PWM current regulation
- Validated hover at 1.3 mm with <0.1 mm RMS disturbance

```text
                 z(t)
                  ▲
                  │    ┌──────────────┐
                  │    │  Reaction     │
                  │    │    Mass       │
                  │    │              │
                  │    └──────┬───────┘
                  │           │
                  │    ┌──────┴───────┐
                  │    │   Coil + PM  │
                  │    │   (biased)   │
                  │    └──────────────┘
                  └──────────────────────────► t
```

### 9.2.4 Phase 2 — 6-DOF Levitation

`Levitation6D.jl` extends to full rigid-body control:
- 6 DOF: X, Y, Z, Roll, Pitch, Yaw
- 4-coil minimum configuration with rank-4 pseudoinverse
- 0.52 mm RMS lateral control (improved from 272 m — **523,000× improvement**)
- Self-powering via AFPM generator: 2.17 W average

The lateral divergence fix was achieved through:
1. PM centering for passive lateral restoring force
2. Direct lateral actuation via differential coil activation
3. Rank-4 pseudoinverse mixing matrix (6 DOF → 4 coil currents)

### 9.2.5 Running Track B

```bash
cd sim
julia --project=. -e 'include("scripts/phase2_6dof.jl")'
julia --project=. -e 'include("scripts/phase1_hover.jl")'
```

---

## 9.3 Track C — Analytical Sweeps (`simulation/`)

### 9.3.1 Purpose
Fast analytical parameter sweeps and control calibration, independent of
the Julia ODE solver for rapid iteration.

### 9.3.2 Key Files

| File | Description |
|------|-------------|
| `peat_sim_v2.py` | v2 analytical model — calibrated loss terms, 3-scale verification |
| `peat_sim.py` | Original analytical model (v1) |
| `calibration_controller.py` | Kalman PLL, PID, gain scheduling, energy balance controller |
| `verify_peat.py` | Cross-check analytical vs numerical at 3 scales |

### 9.3.3 `peat_sim_v2.py` Architecture

```text
CoilParams ───→ OscillatorParams ───→ ArrayParams
     │                │                    │
     │                │                    │
     ▼                ▼                    ▼
AnalyticalModel ──→ SixOscillatorArray
     │                    │
     │                    ▼
     │            create_oscillator_for_scale(M, f, ratio, eta)
     │                    │
     ▼                    ▼
full_energy_balance() → Power budget per scale
```

### 9.3.4 Calibration Controller (`calibration_controller.py`)

The calibration controller provides deterministic reference control:

```text
KalmanPLL ──→ GainScheduler ──→ EnergyBalanceController
   │               │                     │
   │          ┌─────┴─────┐              │
   ▼          ▼           ▼              ▼
PhaseEst  PumpDepth   CurrentLimits  PowerRegulation
```

- **KalmanPLL**: 2-state (phase, frequency) Kalman filter for phase-locked loop
- **GainScheduler**: η modulation depth adjustment based on load, amplitude, pump power
- **EnergyBalanceController**: Regulates pump power to match generator load

### 9.3.5 Three-Scale Verification

`verify_peat.py` cross-checks the analytical model against numerical
simulation at three mass scales:

| Scale | Mass | Frequency | η | Analytical P_net | Numerical P_net | Error |
|-------|------|-----------|----|-----------------|-----------------|-------|
| Drone | 5 kg | 30 Hz | 0.30 | — | — | <5% |
| Human | 115 kg | 15 Hz | 0.20 | — | — | <5% |
| Hovercar | 1,200 kg | 10 Hz | 0.25 | — | — | <5% |

### 9.3.6 Running Track C

```bash
cd simulation
python3 verify_peat.py           # Cross-check verification
python3 -c "from peat_sim_v2 import *; # Interactive exploration"
```

---

## 9.4 Cross-Track Relationships

```text
┌─────────────────────────────────────────────────────────┐
│               PEAT Simulation Suite                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Track A (Julia ODE)  ←── validates ──→  Track C (Python Analytical)
│  peat_sim/                         simulation/           │
│  • Detailed transient               • Fast parameter     │
│  • Adaptive solver                  sweeps               │
│  • 71 tests                         • 3-scale verify     │
│                                  ↑                      │
│                                  │ informs              │
│  Track B (Julia Hover) ────────────┘                    │
│  sim/                                                     │
│  • 1-DOF → 6-DOF                                        │
│  • PM bias + active control                              │
│  • 0.52mm RMS certification                              │
└─────────────────────────────────────────────────────────┘
```

---

## 9.5 Reproducibility

All simulations use deterministic parameter sets and fixed random seeds.
Results are reproducible across platforms:

1. **Track A**: `julia --project=. scripts/sweep.jl` produces identical output
2. **Track B**: Fixed parameter set in `phase2_6dof.jl`
3. **Track C**: All `create_oscillator_for_scale()` calls are pure functions

For full reproducibility, use the exact Julia and Python versions specified
in the project environment files.
