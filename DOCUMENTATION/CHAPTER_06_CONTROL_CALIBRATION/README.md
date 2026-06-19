# CHAPTER 6: CONTROL & CALIBRATION

**PEAT — Pure Electromagnetic Asymmetric Thrust**

| Field | Value |
|---|---|
| Document Version | 1.0 |
| Framework Version | PEAT v1.1 |
| Status | DRAFT |
| Author | AVIS Engineering |
| Date | 2026-06-19 |

---

## Table of Contents

1. [Control Architecture Overview](#1-control-architecture-overview)
2. [PID Controller per Axis](#2-pid-controller-per-axis)
3. [Control Mixing Matrix](#3-control-mixing-matrix)
4. [Phase-Locked Loop](#4-phase-locked-loop)
5. [Gain Scheduling](#5-gain-scheduling)
6. [Current Regulation](#6-current-regulation)
7. [Calibration Procedure](#7-calibration-procedure)
8. [Adaptive Timing](#8-adaptive-timing)
9. [Startup Sequence](#9-startup-sequence)
10. [Failsafe Modes](#10-failsafe-modes)

---

## 1. Control Architecture Overview

The PEAT control system is organised as a **three-layer hierarchy** with increasing bandwidth and decreasing scope as we move inward:

```
┌──────────────────────────────────────────────────────────────┐
│  OUTER LOOP  —  Trajectory / Mission Layer  (1 kHz)          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  6× PID Controllers (X, Y, Z, Roll, Pitch, Yaw)       │  │
│  │  6-DOF state estimation (quaternion + position)        │  │
│  │  Position hold / trajectory tracking                   │  │
│  │  G-force compensation                                  │  │
│  └───────────────────────┬────────────────────────────────┘  │
│                          │                                    │
│                          ▼                                    │
│  MIDDLE LOOP  —  Mixing Matrix  (20 kHz)                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  6-DOF force/torque demand → N coil current commands   │  │
│  │  Pseudoinverse of 6×N actuation matrix                 │  │
│  │  Distribution among redundant coils                    │  │
│  └───────────────────────┬────────────────────────────────┘  │
│                          │                                    │
│                          ▼                                    │
│  INNER LOOP  —  Current Regulator  (20 kHz)                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  PWM driver with per-coil current feedback             │  │
│  │  Cycle-by-cycle current limiting                       │  │
│  │  Hysteresis-band or PI current controller              │  │
│  │  Overcurrent / desat protection                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 1.1 Layer 1 — Trajectory Control (1 kHz)

The outer loop operates at 1 kHz, running six independent PID controllers — one per degree of freedom. Inputs come from the IMU (accelerometer + gyroscope, fused at 10 kHz, downsampled) and Hall-effect position sensors. Outputs are a desired force/torque vector in 6-DOF space:

```
F_desired = [F_x, F_y, F_z, τ_roll, τ_pitch, τ_yaw]^T
```

This layer also handles:
- **Weight estimation**: integrating vertical thrust demand over time to estimate total system mass
- **Payload shift detection**: monitoring steady-state offset in horizontal PIDs
- **Energy-aware thrust limiting**: reducing commanded acceleration when battery or pump power is constrained

### 1.2 Layer 2 — Mixing Matrix (20 kHz)

The 6-DOF force demand from Layer 1 must be mapped to individual coil currents. With N coils (12 in the baseline 6-oscillator architecture: 2 coils per oscillator × 6 oscillators), this is an **over-actuated** system when N > 6.

The mixing matrix `M` is a `6 × N` matrix where:

```
τ = M · i
```

where `τ ∈ ℝ⁶` is the force/torque vector, `i ∈ ℝ^N` is the coil current vector, and `M_ij` maps the contribution of coil `j` to DOF `i`.

The inverse mapping (currents from desired forces) uses the **Moore–Penrose pseudoinverse**:

```
i = M^+ · τ_desired + (I − M^+ · M) · i_null
```

where `i_null` is any null-space current that produces zero net force — exploitable for loss minimisation or thermal balancing across coils.

### 1.3 Layer 3 — Current Regulation (20 kHz)

Each coil has a dedicated current regulator implemented in the PWM driver. The regulator compares the commanded current (from Layer 2) against the measured coil current (from a current-sense resistor or Hall-effect current sensor) and adjusts the PWM duty cycle to drive the error to zero.

---

## 2. PID Controller per Axis

Six independent PID controllers operate on each degree of freedom. Each follows the standard form:

```
u(t) = K_p · e(t) + K_i · ∫₀ᵗ e(τ) dτ + K_d · de(t)/dt
```

**Implemented in the analog/embedded domain as:**

```
u[k] = K_p · e[k] + K_i · T_s · Σⱼ₌₀ᵏ e[j] + K_d · (e[k] − e[k−1]) / T_s
```

where `T_s = 1 ms` for the outer loop.

### 2.1 Per-Axis Configuration

| DOF | Error Signal | Control Output | Gain Priority |
|---|---|---|---|
| X (longitudinal) | `x_desired − x_measured` | `F_x` | K_p > K_d > K_i |
| Y (lateral) | `y_desired − y_measured` | `F_y` | K_p > K_d > K_i |
| Z (vertical) | `z_desired − z_measured` | `F_z` | K_i > K_p > K_d |
| Roll (φ) | `φ_desired − φ_measured` | `τ_roll` | K_d > K_p > K_i |
| Pitch (θ) | `θ_desired − θ_measured` | `τ_pitch` | K_d > K_p > K_i |
| Yaw (ψ) | `ψ_desired − ψ_measured` | `τ_yaw` | K_p > K_d > K_i |

### 2.2 Z-Axis Integral Emphasis

The Z-axis PID is designed with **integral-dominant** tuning because vertical hover requires zero steady-state error against gravity. The integral term accumulates until the thrust exactly cancels weight. A tracking anti-windup mechanism clamps the integrator:

```
if saturated(u[k]):
    e_int[k] = e_int[k−1]  // freeze integrator
```

### 2.3 Derivative Filtering

Raw position/velocity measurements from the Hall-effect sensors contain switching noise from the PWM drivers. Each derivative term includes a first-order low-pass filter:

```
s · K_d  →  K_d · s / (1 + s · T_f)
```

with `T_f = 3 · T_s` in the discrete implementation:

```
u_d[k] = α · u_d[k−1] + (K_d / T_s) · (e[k] − e[k−1])
```

where `α = T_f / (T_f + T_s)`.

### 2.4 PID to Mixing Matrix Interface

Each PID output is a scalar force or torque demand. These are assembled into the 6-element vector:

```
τ_desired = [F_x, F_y, F_z, τ_x, τ_y, τ_z]^T
```

and passed to the mixing matrix for distribution to individual coils.

---

## 3. Control Mixing Matrix

### 3.1 Actuation Geometry

For a 6-oscillator array with coils labelled as:

```
Z+:  coil ZA (upper), coil ZB (lower)    — vertical lift pair
Z−:  coil ZA' (upper), coil ZB' (lower)  — vertical lift pair
X+:  coil XA (forward), coil XB (aft)     — longitudinal pair
X−:  coil XA' (forward), coil XB' (aft)   — longitudinal pair
Y+:  coil YA (starboard), coil YB (port)  — lateral pair
Y−:  coil YA' (starboard), coil YB' (port)— lateral pair
```

Each coil pair produces a signed force along its primary axis. The 6 × 12 mixing matrix maps 12 coil currents to 6 DOF:

```
┌ F_z ┐   ┌ a₁  a₂  a₃  a₄  0   0   0   0   0   0   0   0  ┐ ┌ i_ZA  ┐
│ F_x │   │ 0   0   0   0   b₁  b₂  b₃  b₄  0   0   0   0  │ │ i_ZB  │
│ F_y │ = │ 0   0   0   0   0   0   0   0   c₁  c₂  c₃  c₄ │ │ i_ZA' │
│ τ_φ │   │ d₁  d₂  d₃  d₄  e₁  e₂  e₃  e₄  f₁  f₂  f₃  f₄ │ │ i_ZB' │
│ τ_θ │   │ g₁  g₂  g₃  g₄  h₁  h₂  h₃  h₄  i₁  i₂  i₃  i₄ │ │ ...   │
└ τ_ψ ┘   └ j₁  j₂  j₃  j₄  k₁  k₂  k₃  k₄  l₁  l₂  l₃  l₄ ┘ └ i_YB' ┘
```

Each non-zero entry `m_ij` is the force-per-ampere contribution of coil `j` to DOF `i`, derived from:

```
m_ij = ½ · ∂L_j/∂x · cos(θ_ji)
```

where `∂L_j/∂x` is the inductance gradient of coil `j` at the nominal operating point and `θ_ji` is the angle between the coil axis and DOF `i`.

### 3.2 The 4-Coil → 6-DOF Rank Deficiency Problem

For the degenerate case of only 4 coils attempting to control 6 DOF, the mixing matrix `M ∈ ℝ⁶ˣ⁴` has rank at most 4. The pseudoinverse solution:

```
i = M^+ · τ_desired
```

where `M^+ = M^T · (M · M^T)⁻¹`

exists mathematically but the solution is **non-unique** — there is a 2-dimensional null space of coil currents that produce zero net force. This manifests as:

1. **Uncontrollable DOFs**: at least 2 axes have zero control authority
2. **Coupling**: commanding one DOF produces unintended forces in others
3. **Inefficiency**: the pseudoinverse spreads current across all coils, increasing I²R losses

The PEAT architecture solves this with **6 orthogonal oscillator pairs** (12 coils total), giving `M ∈ ℝ⁶ˣ¹²`. This is an over-actuated system with a 6-dimensional null space, providing full control authority plus redundancy.

### 3.3 Pseudoinverse Solution

For the full 12-coil system, the minimum-norm solution minimises coil heating for a given thrust:

```
i_cmd = M^T · (M · M^T)⁻¹ · τ_desired
```

This produces the smallest possible `||i||₂` for the required `τ_desired`. The remaining null-space freedom (`i_null ∈ ℝ⁶`) can be used for:

- **Thermal balancing**: shifting current between redundant coils to equalise temperatures
- **Loss minimisation**: projecting into the null space to reduce I²R total
- **Active compliance**: injecting null currents that change effective stiffness without affecting net force

### 3.4 Mixing Matrix Saturation

When a particular coil reaches its current limit (`i_max`), the mixing matrix is recomputed on-the-fly with that coil removed (or deweighted). This graceful degradation prevents a single saturated coil from distorting the force output.

---

## 4. Phase-Locked Loop

The parametric pump requires phase-coherent injection of energy at exactly `2ω₀`. The **KalmanPLL** is a 2-state Kalman filter that tracks the oscillation phase and frequency from noisy Hall-sensor measurements.

### 4.1 State Space Model

```
State vector:       x = [φ, ω]^T    (phase [rad], frequency [rad/s])
State transition:   x_{k|k−1} = F · x_{k−1}
                    F = [[1,  Δt],
                         [0,   1]]
                    
Measurement:        z_k = H · x_k + ν_k
                    H = [1, 0]   (phase measurement)
```

### 4.2 Predict Step

```
x_pred = F · x_est
P_pred = F · P_est · F^T + Q
```

where `Q = σ_q² · I₂` is the process noise covariance, tuned via `process_noise` (default `σ_q² = 1×10⁻⁴`).

### 4.3 Update Step (Phase)

The phase innovation is wrapped to `[−π, π)` to prevent 2π discontinuities from corrupting the filter:

```
δφ = wrap(φ_measured − φ_pred)
S = H · P_pred · H^T + R_phase
K = P_pred · H^T / S
x_est = x_pred + K · δφ
P_est = (I − K · H) · P_pred
```

where `R_phase = 5×10⁻²` (default `measurement_noise`).

### 4.4 Optional Frequency Update

When a direct frequency measurement is available (e.g., from zero-crossing period measurement), a second update step runs:

```
δω = ω_measured − ω_pred
S_f = H_f · P_pred · H_f^T + R_freq
K_f = P_pred · H_f^T / S_f
x_est = x_est + K_f · δω
P_est = (I − K_f · H_f) · P_est
```

where `H_f = [0, 1]` and `R_freq = 2.0` (default `frequency_measurement_noise`).

### 4.5 Tuning Guide

| Parameter | Value | Effect |
|---|---|---|
| `process_noise` | `1×10⁻⁴` | Higher = faster tracking, noisier estimate |
| `measurement_noise` | `5×10⁻²` | Higher = more smoothing, slower response |
| `frequency_measurement_noise` | `2.0` | Trust in direct frequency measurement |

For aggressive maneuvers, `process_noise` should be increased to `1×10⁻³` for faster phase tracking at the expense of noise rejection.

### 4.6 Phase Error Requirement

The parametric pump modulation must be within **5° electrical** of the true 2ω₀ phase:

```
Δφ_required < 5° = 0.087 rad at 2ω₀
```

For a 15 Hz oscillation (2ω₀ = 30 Hz), this corresponds to a timing precision of:

```
Δt = Δφ / (2ω₀) = 0.087 / (2π · 30) ≈ 0.46 ms
```

Easily achieved with the 10 kHz Hall-sensor measurement rate and 1 kHz PLL update.

---

## 5. Gain Scheduling

The `GainScheduler` adapts `η_repel` (the asymmetry ratio) in real-time based on operating conditions.

### 5.1 η_repel Baseline

The asymmetry ratio `η_repel = I_rep / I_att` controls the thrust per cycle:

```
ξ = 1 − η_repel          (asymmetry effectiveness)
F_thrust ∝ ξ · m_r · ω₀ · z₀
```

| η_repel | Regime | Effect |
|---|---|---|
| 0.05–0.15 | High-thrust | Maximum force, harder to control amplitude |
| 0.20 | Baseline | Balanced thrust vs. controllability |
| 0.30–0.60 | Low-thrust | Smooth operation, reduced power draw |

### 5.2 Scheduling Law

The scheduler computes `η_repel` as:

```
η = η_base − k_g · max(g_load − 1.0, 0) − k_A · A_err + k_P · P_err + k_P_low · (P_min − P_pump) · 0.25
```

where the terms represent:

**Load compensation** (`k_g = 0.035` per g): when the vehicle pulls more than 1 g, reduce η to increase thrust margin.

**Amplitude regulation** (`k_A = 0.8`): when oscillation amplitude is below target, reduce η for more thrust; when above, increase η to shed thrust.

**Pump-power regulation** (`k_P = 2×10⁻⁶` per W): when pump power exceeds the maximum (`P_max = 10 kW`), increase η to reduce thrust demand. When pump power is below the minimum (`P_min = 1 kW`) **and** amplitude is below target, reduce η to draw more power into the oscillation.

### 5.3 Clipping

The output is bounded to prevent operation outside safe physical limits:

```
η_clipped = clamp(η, η_min=0.05, η_max=0.60)
```

### 5.4 Energy Balance Controller

A companion `EnergyBalanceController` adjusts the parametric pump modulation depth `h`:

```
h = h_nominal − k_A_eb · A_err − k_P_eb · (P_pump − 0.85 · P_target)
```

where `k_A_eb = 0.12` and `k_P_eb = 1×10⁻⁶`. This independently regulates how aggressively the parametric resonance is driven, complementing the η_repel scheduling.

---

## 6. Current Regulation

### 6.1 PWM Driver Per Coil

Each coil is driven by a dedicated H-bridge PWM driver. The switching frequency is `f_PWM ≥ 20 kHz` (above audible range). The duty cycle `D ∈ [0, 1]` maps to coil voltage as:

```
V_coil = D · V_bus          (for positive current)
V_coil = −D · V_bus         (for negative current — bidirectional H-bridge)
```

### 6.2 Current Feedback

A current-sense resistor (or Hall-effect current sensor) measures the instantaneous coil current `i_meas` at each PWM cycle. Two control strategies are available:

**Hysteresis-band controller** (default):

```
if i_meas < i_cmd − δ:   turn ON  (apply V_bus)
if i_meas > i_cmd + δ:   turn OFF (freewheel or reverse)
```

where the hysteresis band `δ = 0.05 · i_cmd` prevents chattering.

**PI controller** (low-noise mode):

```
e_i[k] = i_cmd − i_meas[k]
u_PI[k] = K_p_i · e_i[k] + K_i_i · Σ e_i[j] · T_PWM
D[k] = clamp(u_PI[k] / V_bus, 0, 1)
```

### 6.3 Cycle-by-Cycle Current Limit

A hardware comparator monitors `i_meas` every PWM cycle. If `i_meas > i_max`, the PWM output is immediately forced to zero (independent of firmware) for the remainder of that cycle. This protects the coils and power semiconductors from overcurrent faults on a per-cycle basis.

```
if i_meas > i_max:
    D = 0                              // immediate turn-off
    fault_counter += 1
    if fault_counter > N_fault:
        shutdown_coil()                // persistent fault → disable
```

### 6.4 Coil Current Modelling

For the simulation, the coil current dynamics are given by:

```
di/dt = (V_applied − i · R − v · i · dL/dx) / L
```

The `v · i · dL/dx` term is the **motional EMF** — the electromechanical back-EMF that couples the electrical and mechanical domains. This is the term through which mechanical work is done on the reaction mass.

---

## 7. Calibration Procedure

The calibration sequence brings a PEAT system from an unpowered state to closed-loop controlled operation. It proceeds through four phases.

### 7.1 Phase 1 — Offset Nulling

**Goal**: Zero all position sensor offsets.

Procedure:
1. Verify mechanical zero: reaction masses centred between coils (visual or mechanical stop)
2. Record Hall-sensor readings for each of the 18 sensors (6 oscillators × 3 sensors)
3. Compute sensor offset:
   ```
   offset_s[i] = V_hall_measured[i, x=0]
   ```
4. Store offsets in non-volatile calibration memory
5. Verify: after nulling, all reported positions read within `±50 μm` of true zero

### 7.2 Phase 2 — Gain Calibration

**Goal**: Determine the relationship between coil current and force output.

Procedure per oscillator:
1. Energise coil A with known current `I_test` (ramp from 0 to `I_max / 4`)
2. Measure resulting reaction-mass displacement via Hall sensors
3. Repeat for coil B
4. Fit force constant:
   ```
   k_F = measured_force / I_test²
   ```
   where `k_F = ½ · dL/dx` at the nominal operating point
5. Repeat for all 6 oscillator pairs
6. Verify: force output is within 5% of analytical prediction

### 7.3 Phase 3 — Cross-Axis Decoupling

**Goal**: Measure and compensate for mechanical/electrical coupling between axes.

Procedure:
1. Drive Z+ oscillator at full amplitude (all others off)
2. Measure induced motion in Z−, X+, X−, Y+, Y− oscillators
3. Populate cross-coupling matrix `C ∈ ℝ⁶ˣ⁶`:
   ```
   C_ij = amplitude_i / amplitude_j   when driving axis j
   ```
4. Compute decoupling pre-compensation:
   ```
   M_compensated = (I + C) · M_nominal
   ```
5. Apply to mixing matrix
6. Verify: crosstalk below 2% per axis pair

### 7.4 Phase 4 — Dynamic Verification

**Goal**: Validate closed-loop performance against specification.

Procedure:
1. Engage PID controllers (all 6 axes)
2. Command a 1 cm step in Z-axis
3. Record rise time, overshoot, settling time
4. Command a 5° pitch step
5. Measure cross-axis disturbance (should be < 0.5° in roll/yaw)
6. Verify against specification:
   - Z-axis settling: < 200 ms
   - Angular settling: < 300 ms
   - Cross-axis coupling: < 5%
   - Steady-state position error: < 0.5 mm

---

## 8. Adaptive Timing

The numerical ODE solver uses **LSODA** (from `scipy.integrate.solve_ivp`) which automatically detects stiffness and switches between Adams (non-stiff) and BDF (stiff) methods.

### 8.1 Solver Configuration

```python
method='LSODA',
max_step=dt_max * 100,    # 1 ms max step for 100 kHz baseline
rtol=1e-6,                 # Relative tolerance
atol=1e-8                  # Absolute tolerance
```

The `max_step` parameter limits how far the solver can advance in a single step. With `dt_max = 10 μs` and `max_step = 100 × dt_max = 1 ms`, the solver can take up to 100 kHz equivalent steps when the system is non-stiff but will automatically take smaller steps during fast transients.

### 8.2 Adaptive Stepping Behaviour

The LSODA solver:

- **Non-stiff regime** (coasting, slow current changes): takes large steps (up to 1 ms), runs at near-Adams efficiency
- **Stiff regime** (fast current rise/decay during switching transients): switches to BDF, takes microsecond-scale steps
- **Switching transients**: automatically reduces step size around coil voltage transitions (attract → coast → repel → coast)

Typical performance for the 115 kg baseline:

| Phase | Step Size | Steps per Cycle |
|---|---|---|
| Attract (current rising) | 1–10 μs | ~3,000 |
| Coast (no drive) | 50–200 μs | ~150 |
| Repel (current rising) | 5–20 μs | ~1,500 |
| Coast (decay) | 50–200 μs | ~150 |

### 8.3 Sampling for Control

The control loops run at fixed intervals regardless of the solver's internal step size:

```
Control output:  u[k] = u(t = k · T_ctrl)
```

where `T_ctrl = 1 ms` for the outer loop. The solver state at each control interval is obtained from the ODE solver's dense output interpolation.

---

## 9. Startup Sequence

The PEAT system startup proceeds through five distinct phases.

### 9.1 Phase 0 — Power-On Self Test (POST)

1. Verify all 18 Hall sensors read nominal (±10% of expected bias)
2. Verify IMU communication and data integrity
3. Check coil continuity (measure winding resistance)
4. Verify bus voltage within operating range (48–800 V)
5. Check all PWM drivers respond to test pulses
6. Verify failsafe timer is cleared
7. Duration: 100 ms

### 9.2 Phase 1 — Frequency Lock

1. Inject a low-level AC current into all coils at the nominal oscillation frequency `ω₀`
2. Measure the resulting oscillation of the reaction masses via Hall sensors
3. Run the KalmanPLL in **open-loop** mode (predict only, no measurement update) for 50 ms
4. Enable phase measurement updates, allow PLL to lock
5. Frequency lock criterion: phase error < 5° for 10 consecutive cycles
6. Duration: 200–500 ms (depending on damping)

### 9.3 Phase 2 — Amplitude Ramp

1. Once PLL is locked, enable the parametric pump (`2ω₀` modulation)
2. Ramp the pump modulation depth `h` from 0 to nominal over 100 ms:

   ```
   h(t) = h_nominal · (t / t_ramp)    for 0 ≤ t ≤ t_ramp
   ```

3. Ramp `η_repel` from 0.50 (conservative) toward baseline 0.20:

   ```
   η(t) = 0.50 − 0.30 · (t / t_ramp)
   ```

4. Monitor amplitude growth; abort if amplitude exceeds 120% of target
5. Duration: 100 ms

### 9.4 Phase 3 — Transition to Closed-Loop

1. When oscillation amplitude reaches 90% of target, engage PID controllers
2. Enable GainScheduler modulation of `η_repel`
3. Enable EnergyBalanceController regulation of `h`
4. Transfer control from open-loop amplitude ramp to closed-loop regulation
5. Duration: 50 ms (seamless)

### 9.5 Phase 4 — Operational Steady-State

1. All three control layers active
2. PID outer loop maintains position/attitude
3. Mixing matrix distributes force commands
4. Current regulators maintain coil currents
5. KalmanPLL tracks phase with steady-state error < 2°
6. Gain scheduler adapts η to load conditions

**Total startup time: 350–650 ms.**

```
Startup Timeline:
POST [100 ms] → Frequency Lock [200–500 ms] → Amplitude Ramp [100 ms]
→ Closed-Loop Transition [50 ms] → Operational Steady-State
```

---

## 10. Failsafe Modes

The PEAT control system defines three failsafe modes, each triggered by specific fault conditions and escalating in severity.

### 10.1 Coast Mode (Soft Degradation)

**Trigger conditions:**
- Phase error exceeds 15° for 3 consecutive cycles
- Amplitude error exceeds 30% for 5 cycles
- Single coil overcurrent fault

**Actions:**
1. Disable parametric pump modulation (`h → 0`)
2. Hold `η_repel` at current value (do not update)
3. Continue PID control at reduced gains (50% nominal)
4. Set oscillation amplitude target to 80% of nominal
5. Log fault for post-flight analysis

**Recovery:**
If the fault clears for 10 consecutive cycles, begin ramping back to normal operation over 200 ms.

### 10.2 Emergency Brake (Active Degradation)

**Trigger conditions:**
- Phase error exceeds 30°
- Amplitude exceeds 150% of target
- Two or more coil faults
- IMU data invalid
- PLL lost lock for 20 ms

**Actions:**
1. Immediately set all coil voltages to zero (FETs off)
2. Engage dynamic brake resistors across all coils (dissipate stored magnetic energy as heat)
3. Set all PID integrators to zero
4. Activate magnetic bearing suspension at maximum stiffness to centre reaction masses
5. Aluminium or copper eddy-current braking plates provide passive velocity reduction:
   ```
   F_brake = −σ · δ · B² · A · v   (proportional to velocity)
   ```
6. Log all states to non-volatile memory at maximum rate

**Recovery:**
Full restart required. System must not re-enter closed-loop control without a complete POST.

### 10.3 Soft-Landing (Controlled Descent)

**Trigger conditions:**
- Bus voltage below minimum operating threshold
- Critical coil failure (open or short circuit detected)
- Over-temperature on multiple coils
- Software watchdog timeout
- Manual pilot-initiated emergency landing

**Actions (power-limited descent):**
1. Reduce oscillation to minimum sustain amplitude (just enough to maintain PLL lock)
2. Set all trajectory targets to zero velocity descent at 2 m/s
3. Prioritise Z-axis thrust (gravity cancellation) over horizontal control
4. Reduce attitude control bandwidth to minimum (allow ±5° drift)
5. If sufficient power remains, execute a 0.5 m/s² deceleration starting at 5 m altitude
6. On ground contact (detected via accelerometer or contact sensor):
   - Immediately de-energise all coils
   - Engage mechanical brakes if available

**Minimum power budget for soft-landing from 10 m at 2 m/s:**
```
Descent time: 5 s
Power required: ~40% of hover power (reduced amplitude, lower η)
Energy required: ~200 kW · 5 s = ~1 MJ for 115 kg baseline
```

### 10.4 Failsafe Priority Matrix

| Condition | Coast | Emergency Brake | Soft Landing |
|---|---|---|---|
| Single coil fault | ✓ | | |
| Phase error > 15° | ✓ | | |
| Phase error > 30° | | ✓ | |
| Amplitude > 150% | | ✓ | |
| Bus undervoltage | | | ✓ |
| Pilot emergency | | | ✓ |
| Watchdog timeout | | | ✓ |
| Multiple coil faults | | ✓ | |
| IMU failure | | ✓ | |
| Over-temp (caution) | ✓ | | |
| Over-temp (critical) | | ✓ | |

---

## References

- `simulation/calibration_controller.py`: Implementation of KalmanPLL, GainScheduler, EnergyBalanceController
- `simulation/peat_sim.py`: SingleOscillatorODE drive state machine, SixOscillatorArray 34-state ODE, LSODA solver integration
- `PEAT_MASTER.md` Section 6: Control & Calibration architecture overview
- `DOCUMENTATION/CHAPTER_03_SYSTEM_ARCHITECTURE/README.md`: Sensor array and coil placement details
- `DOCUMENTATION/CHAPTER_05_ENERGY_BALANCE/README.md`: Energy flow and pump-power budgeting
