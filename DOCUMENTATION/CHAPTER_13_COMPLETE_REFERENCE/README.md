# Chapter 13: Complete Reference

| Attribute | Value |
|-----------|-------|
| **Version** | 1.1 |
| **Status** | OPTIBEST REVIEWED |

---

## 13.1 Parameter Reference — All Dataclasses

### 13.1.1 CoilParams

Defined in: `simulation/peat_sim_v2.py`, `peat_sim/src/PeatSim.jl`

| Symbol | Parameter | Unit | Description | Drone (5 kg) | Human (115 kg) | Hovercar (1,200 kg) |
|--------|-----------|------|-------------|-------------|----------------|--------------------|
| `N` | N_turns | — | Number of wire turns | 100 | 250 | 500 |
| `R` | R_coil | Ω | Coil DC resistance | 0.5 | 1.0 | 2.0 |
| `L∞` | L_inf | H | Inductance at x → ∞ | 0.02 | 0.05 | 0.10 |
| `L₀` | L_close | H | Inductance at x → 0 | 0.10 | 0.25 | 0.50 |
| `d_ref` | d_ref | m | Characteristic distance | 0.010 | 0.015 | 0.025 |
| `Ac` | core_area | m² | Core cross-sectional area | 0.001 | 0.003 | 0.008 |
| `I_max` | max_current | A | Maximum rated current | 50 | 150 | 400 |

### 13.1.2 OscillatorParams

Defined in: `peat_sim/src/PeatSim.jl` (Julia struct), `simulation/peat_sim_v2.py` (Python dataclass)

| Symbol | Parameter | Unit | Description | Drone | Human | Hovercar |
|--------|-----------|------|-------------|-------|-------|----------|
| `m` | mass | kg | Reaction mass | 5 | 115 | 1,200 |
| `x_pp` | stroke | m | Peak-to-peak amplitude | 0.15 | 0.15 | 0.12 |
| `k` | k_mech | N/m | Mechanical spring stiffness | — | — | — |
| `b_m` | b_mech | N·s/m | Mechanical damping | — | — | — |
| `f₀` | f_mech | Hz | Mechanical resonance | 30 | 15 | 10 |
| `V_bus` | V_bus | V | DC bus voltage | 300 | 600 | 800 |
| `η` | eta | — | Modulation depth | 0.30 | 0.20 | 0.25 |
| `b_gen` | b_gen | N·s/m | Generator damping | 250 | 250 | 250 |
| `τ` | — | ms | L/R time constant (effective) | ~50 | ~75 | ~100 |

### 13.1.3 ArrayParams

Defined in: `simulation/peat_sim_v2.py`

| Symbol | Parameter | Unit | Description | Typical |
|--------|-----------|------|-------------|---------|
| `N_coils` | coil_count | — | Number of oscillator pairs | 3-6 (min), 6-8 (optimal) |
| `spacing` | coil_spacing | m | Center-to-center coil distance | 0.1-1.0 |
| `geometry` | array_type | — | Layout geometry | hexagonal or square |

### 13.1.4 Controller Parameters

Defined in: `simulation/calibration_controller.py`

**PID Gains** (per-axis tunable):

| DOF | Kp (N/m) | Ki (N/m·s) | Kd (N·s/m) | Notes |
|-----|----------|-----------|------------|-------|
| Z (hover) | 50,000 | 5,000 | 2,000 | Stiffest — primary load-bearing |
| X (lateral) | 15,000 | 1,500 | 600 | Moderate — lateral control |
| Y (lateral) | 15,000 | 1,500 | 600 | Moderate — lateral control |
| Roll | 500 | 50 | 20 | Torsional stiffness |
| Pitch | 500 | 50 | 20 | Torsional stiffness |
| Yaw | 200 | 20 | 8 | Weakest — yaw drift tolerance |

**KalmanPLL Parameters**:

| Parameter | Value | Description |
|-----------|-------|-------------|
| State dimension | 2 | [phase_rad, frequency_rad/s] |
| Q_process | diag(0.01, 0.1) | Process noise covariance |
| R_measurement | 0.5 | Measurement noise covariance |
| P_initial | diag(π, 100π) | Initial state uncertainty |
| dt | 50 µs | Update period |

**GainScheduler Outputs**:

| Symbol | Parameter | Range | Description |
|--------|-----------|-------|-------------|
| `η` | pump_modulation_depth | 0.05-0.50 | Amplitude of parametric pump |
| `V_pump_max` | max_pump_voltage | 0-V_bus | Voltage limit for pump coil |
| `d_cycle` | pwm_duty_cycle | 0-100% | Current regulation duty |

### 13.1.5 GeneratorParameters

| Symbol | Parameter | Unit | Description | Value |
|--------|-----------|------|-------------|-------|
| `b_gen` | damping_coefficient | N·s/m | Pickup coil EM damping | 250 |
| `p` | pole_pairs | — | AFPM pole count | 8 |
| `RPM` | rotation_speed | rpm | Generator shaft speed | 3,000 |
| `K_v` | voltage_constant | V/(rad/s) | Generator voltage constant | 0.05 |
| `R_gen` | winding_resistance | Ω | Generator copper loss | 0.5 |
| `P_avg` | self_power | W | Average self-powering | 2.17 |

---

## 13.2 Physical Constants

| Constant | Symbol | Value | Units |
|----------|--------|-------|-------|
| Permeability of free space | μ₀ | 4π × 10⁻⁷ | H/m |
| Resistivity of copper (20°C) | ρ_cu | 1.68 × 10⁻⁸ | Ω·m |
| Resistivity of aluminum | ρ_al | 2.65 × 10⁻⁸ | Ω·m |
| Resistivity of iron | ρ_fe | 9.71 × 10⁻⁸ | Ω·m |
| Relative permeability (iron) | μ_r | ~5,000 | — |
| Relative permeability (air) | μ_r | 1.00000037 | — |
| Electron charge | e | 1.602 × 10⁻¹⁹ | C |
| Boltzmann constant | k_B | 1.381 × 10⁻²³ | J/K |
| Gravitational acceleration | g | 9.80665 | m/s² |

### Material Properties for Reaction Mass

| Material | Density (kg/m³) | μ_r | σ (MS/m) | Use Case |
|----------|----------------|-----|----------|----------|
| Iron (99.9% pure) | 7,874 | ~5,000 | 10.3 | Maximum force coupling |
| Steel 1018 | 7,870 | ~1,000 | 6.6 | Cost-effective, strong |
| Ferrite (MnZn) | 4,800 | ~2,000 | 0.1 | Lightweight, high-frequency |
| Silicon steel | 7,650 | ~4,000 | 2.0 | Laminated, low eddy current |
| Permalloy | 8,700 | ~10,000 | 2.0 | High permeability (expensive) |

---

## 13.3 Formula Reference

### Inductance Modulation
$$L(x) = L_{\infty} + \frac{L_0 - L_{\infty}}{1 + (x/d_{ref})^2}$$

### Magnetic Force
$$F_{mag} = \frac{1}{2} \frac{dL}{dx} \cdot i^2$$

Where:
$$\frac{dL}{dx} = -\frac{2x}{d_{ref}^2} \cdot \frac{L_0 - L_{\infty}}{(1 + (x/d_{ref})^2)^2}$$

### Power Balance
$$P_{net} = P_{pump} - P_{copper} - P_{pickup}$$

$$P_{pump} = V_{bus} \cdot i_A(t)$$
$$P_{copper} = i_A^2 R_A + i_B^2 R_B$$
$$P_{pickup} = b_{gen} \cdot v^2$$

### Generator Damping
$$b_{gen} = \frac{(dL/dx)^2_{peak} \cdot i^2_{nom}}{2 \cdot R_{gen}}$$

### Parametric Resonance Condition
$$\omega_{drive} = 2\omega_0$$

$$\omega_0 = \sqrt{\frac{k}{m}}$$

### PID Control Law
$$u(t) = K_p e(t) + K_i \int_0^t e(\tau)d\tau + K_d \frac{de(t)}{dt}$$

### Mixing Matrix
$$\mathbf{I}_{coils} = \mathbf{M}^+ \cdot \mathbf{F}_{desired}$$

Where $\mathbf{M}^+ = \mathbf{M}^T(\mathbf{MM}^T)^{-1}$ (pseudoinverse)

### L/R Time Constant
$$\tau = \frac{L}{R}$$

### Coil Energy Storage
$$E = \frac{1}{2}LI^2$$

### PWM Duty Cycle
$$d(t) = \frac{i_{desired}}{V_{bus} / R}$$

### Electromagnetic Force (General)
$$F = \frac{1}{2} I^2 \frac{dL}{dx}$$

### Peak Force at Resonance
$$F_{peak} = \frac{\pi}{2} \cdot Q \cdot \eta \cdot \frac{L_{avg} i_{peak}^2}{stroke}$$

Where $Q = \frac{1}{2\zeta}$ (mechanical quality factor)

---

## 13.4 Complete File Index

### Root Files

| File | Description | Version | Lines |
|------|-------------|---------|-------|
| `README.md` | Project overview and quick-start guide | 1.1 | — |
| `PEAT_MASTER.md` | Master framework document | 1.1 | 715 |
| `PEAT_Framework_Presentation.html` | Interactive landing page | 1.1 | 28,219 |
| `.gitignore` | Version control exclusions | — | — |

### Framework Directory

| File | Description | Version | Lines |
|------|-------------|---------|-------|
| `FRAMEWORK/levitation_framework.md` | Levitation system specification | 1.1 | 740 |

### Simulation Track A — `peat_sim/`

| File | Description | Lines |
|------|-------------|-------|
| `peat_sim/src/PeatSim.jl` | Single-oscillator ODE module | 2,404 |
| `peat_sim/scripts/sweep.jl` | 10,260-config parameter sweep | — |
| `peat_sim/scripts/feasibility.jl` | Feasibility region analysis | — |
| `peat_sim/scripts/geometry_sweep.jl` | Coil geometry optimization | — |
| `peat_sim/scripts/mass_scaling.jl` | Mass dependency analysis | — |
| `peat_sim/scripts/thrust_measure.jl` | Thrust measurement harness | — |
| `peat_sim/test/` | 71 unit tests | — |
| `peat_sim/SUMMARY.md` | Sweep results and fix history | — |
| `peat_sim/docs/ROOT_CAUSE_NOTE.md` | Power insufficiency root cause | 85 |

### Simulation Track B — `sim/`

| File | Description | Lines |
|------|-------------|-------|
| `sim/src/LevitationSim.jl` | 1-DOF PM-biased hover simulation | ~800 |
| `sim/src/Levitation6D.jl` | 6-DOF levitation with lateral fix | ~700 |
| `sim/scripts/phase1_hover.jl` | Phase 1 hover demo | — |
| `sim/scripts/phase2_6dof.jl` | Phase 2 6-DOF demo | — |
| `sim/scripts/debug_6dof.jl` | 6-DOF debug/analysis | — |
| `sim/docs/lateral_divergence_fix_CERTIFICATION.md` | Certification document | — |

### Simulation Track C — `simulation/`

| File | Description | Lines |
|------|-------------|-------|
| `simulation/peat_sim_v2.py` | v2 analytical model with calibrated losses | 1,363 |
| `simulation/peat_sim.py` | Original analytical model | — |
| `simulation/calibration_controller.py` | Kalman PLL, PID, gain scheduling | 346 |
| `simulation/verify_peat.py` | Analytical vs numerical cross-check | 67 |

### Simulation Consolidation

| File | Description |
|------|-------------|
| `SIMULATION/README.md` | Unified navigation index for all tracks |

### Documentation Directory

| File | Description | Version |
|------|-------------|---------|
| `DOCUMENTATION/README.md` | Documentation index | 1.1 |
| `DOCUMENTATION/CHAPTER_01_FOUNDATIONS/README.md` | Foundations & Premise | 1.1 |
| `DOCUMENTATION/CHAPTER_02_CORE_PHYSICS/README.md` | Core Physics | 1.1 |
| `DOCUMENTATION/CHAPTER_03_SYSTEM_ARCHITECTURE/README.md` | System Architecture | 1.1 |
| `DOCUMENTATION/CHAPTER_04_OSCILLATOR_DESIGN/README.md` | Oscillator Design | 1.1 |
| `DOCUMENTATION/CHAPTER_05_ENERGY_BALANCE/README.md` | Energy Balance & Power | 1.1 |
| `DOCUMENTATION/CHAPTER_06_CONTROL_CALIBRATION/README.md` | Control & Calibration | 1.1 |
| `DOCUMENTATION/CHAPTER_07_6DOF_LEVITATION/README.md` | 6-DOF Levitation | 1.1 |
| `DOCUMENTATION/CHAPTER_08_USE_CASE_SCALING/README.md` | Use-Case Scaling | 1.1 |
| `DOCUMENTATION/CHAPTER_09_SIMULATION_SUITE/README.md` | Simulation Suite | 1.1 |
| `DOCUMENTATION/CHAPTER_10_VERIFICATION_VALIDATION/README.md` | Verification & Validation | 1.1 |
| `DOCUMENTATION/CHAPTER_11_COMPLIANCE_LICENSING/README.md` | Compliance, Licensing & Regulation | 1.1 |
| `DOCUMENTATION/CHAPTER_12_ROADMAP/README.md` | Roadmap & Next Steps | 1.1 |
| `DOCUMENTATION/CHAPTER_13_COMPLETE_REFERENCE/README.md` | Complete Reference | 1.1 |

---

## 13.5 Glossary

| Term | Definition |
|------|------------|
| **AFPM** | Axial Flux Permanent Magnet — generator topology for self-powering |
| **Asymmetric Drive** | Drive waveform where attract and repel phases have different durations or intensities |
| **b_gen** | Generator damping coefficient (N·s/m) — electromagnetic drag from pickup coil |
| **CC0** | Creative Commons Zero — public domain dedication, no rights reserved |
| **Coil Pair** | Two identical coils on opposite sides of a reaction mass |
| **DOF** | Degree Of Freedom — independent axis of motion (6 for rigid body: X, Y, Z, Roll, Pitch, Yaw) |
| **EFE Filter** | Seven-principle sustainable engineering framework guiding material/energy choices |
| **Generator Damping** | Electromagnetic force opposing motion, proportional to velocity, caused by energy extraction |
| **I²R Loss** | Copper loss — power dissipated as heat in coil windings |
| **L/R Time Constant** | τ = L/R — characteristic time for current to change in an inductive circuit |
| **Lateral Divergence** | Inherent lateral instability in pure magnetic levitation; controlled by active feedback |
| **Mechanism A** | Thrust via pure electromagnetic asymmetry — no moving mechanical parts for propulsion |
| **Mixing Matrix** | Linear transformation mapping 6 DOF force commands to N coil currents |
| **Modulation Depth (η)** | Amplitude of the parametric pump modulation, 0-100% |
| **OPTIBEST** | Premium engineering framework: 7 Dimensions × 9 Phases × 5 Verification Methods |
| **Parametric Resonance** | Oscillation amplification by modulating a system parameter at 2× natural frequency |
| **PEAT** | Pure Electromagnetic Asymmetric Thrust |
| **Pickup Coil** | Secondary coil that extracts energy from the oscillating magnetic field |
| **PID** | Proportional-Integral-Derivative controller |
| **PLL** | Phase-Locked Loop — synchronizes drive timing with mechanical oscillation |
| **PM Bias** | Permanent Magnet bias — provides offset levitation force, reducing coil power |
| **Pseudoinverse** | Moore-Penrose pseudoinverse — optimal solution to underdetermined linear systems |
| **PWM** | Pulse Width Modulation — switching strategy for coil current regulation |
| **Reaction Mass** | The mass being levitated; interacts with the electromagnetic field |
| **SiC** | Silicon Carbide — wide bandgap semiconductor enabling high-voltage switching |
| **Simultaneous Generation** | Extracting electrical power from the levitation field without affecting levitation |
| **Tsit5** | Tsitouras 5(4) Runge-Kutta method — adaptive ODE solver |
| **η** | See Modulation Depth |
| **2ω₀** | Twice the mechanical resonance frequency — the parametric pump frequency |
| **6-oscillator** | 6 coil pairs in a hexagonal/rectangular array for full 6-DOF control |

---

## 13.6 Simulation Output Legend

### Julia ODE Simulator (`sweep.jl`) Output

When running the sweep script, columns are:

| Column | Format | Description |
|--------|--------|-------------|
| `mass` | `5.0` | Reaction mass in kg |
| `freq` | `30.0` | Mechanical frequency in Hz |
| `V_bus` | `300.0` | Drive voltage in V |
| `thrust` | `0.023` | Net thrust in N (positive = upward) |
| `delta_E` | `-2.3` | Energy change per cycle in J (negative = decay) |
| `P_pump` | `45.4` | Pump input power in W |
| `P_copper` | `45.0` | I²R loss power in W |
| `P_pickup` | `16.0` | Pickup recovery power in W |
| `P_net` | `-15.6` | Net power balance in W (negative = loss) |
| `status` | `DECAY` | Regime classification: `DECAY`, `SUSTAIN`, `GROW` |

### Python Verify (`verify_peat.py`) Output

| Column | Description |
|--------|-------------|
| `Metric` | Power component name |
| `Analytical` | Analytical model prediction |
| `Numerical` | ODE simulation result |
| `Error %` | Percentage difference between analytical and numerical |

### 6-DOF Simulation Output

| Metric | Description |
|--------|-------------|
| `X_rms` | Lateral X position RMS error (mm) |
| `Y_rms` | Lateral Y position RMS error (mm) |
| `Z_mean` | Mean hover height (mm) |
| `Roll_rms` | Roll angle RMS error (mrad) |
| `Pitch_rms` | Pitch angle RMS error (mrad) |
| `Yaw_drift` | Yaw drift rate (°/s) |
| `P_self` | Self-powering AFPM output (W) |
| `dof_status` | Per-DOF status: `STABLE`, `BOUNDARY`, `DIVERGENT` |

---

*This is a living reference. As the framework evolves, update this chapter to reflect new parameters, equations, and capabilities. Last updated: 2026-06-19.*
