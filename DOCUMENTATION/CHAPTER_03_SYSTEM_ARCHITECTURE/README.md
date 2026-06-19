# CHAPTER 3: SYSTEM ARCHITECTURE

> **PEAT — Pure Electromagnetic Asymmetric Thrust**
> Framework Version 1.1 · Systems Engineering Reference

---

## 3.1 Top-Level System Block Diagram

The PEAT system is a coupled electromagnetic levitation and power-generation platform built around six independent oscillator channels arranged in three orthogonal axes. Each channel shares a common reaction mass, power bus, and control hierarchy.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PEAT SYSTEM TOPOLOGY                              │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                      CONTROL SYSTEM                              │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐   │   │
│  │  │Trajectory│→ │   PID    │→ │  Mixing  │→ │ Current Regs   │   │   │
│  │  │Planner   │  │@1kHz    │  │  Matrix  │  │ @20kHz (×N)    │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────┬───────┘   │   │
│  │                          ▲                           │           │   │
│  │                          │ Kalman                    │           │   │
│  │                    ┌─────┴──────┐                    │           │   │
│  │                    │Sensor Fusion│                   │           │   │
│  │                    └────────────┘                    │           │   │
│  └──────────────────────────────────────────────────────┼───────────┘   │
│                                                         │               │
│  ┌──────────────────────────────────────────────────────┼───────────┐   │
│  │                    POWER BUS                         │           │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │           │   │
│  │  │Battery/  │→ │  48-800V │  │  SiC H-Bridge    │◄──┘           │   │
│  │  │Cap Buffer│  │ DC Bus   │  │  Array (×N)      │               │   │
│  │  └──────────┘  └──────────┘  └────────┬─────────┘               │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                          │                             │
│  ┌───────────────────────────────────────┼─────────────────────────┐   │
│  │           OSCILLATOR ARRAY            │                         │   │
│  │  ┌─────┐  ┌─────┐  ┌─────┐           │                         │   │
│  │  │Z+   │  │Z−   │  │X+   │   ┌───────▼────────┐               │   │
│  │  │Coil │  │Coil │  │Coil │   │  REACTION       │               │   │
│  │  │Pair │  │Pair │  │Pair │   │  MASSES (×3)    │               │   │
│  │  └─────┘  └─────┘  └─────┘   │  magnetically   │               │   │
│  │  ┌─────┐  ┌─────┐  ┌─────┐   │  suspended      │               │   │
│  │  │Y+   │  │Y−   │  │(spare)│  └────────┬───────┘               │   │
│  │  │Coil │  │Coil │  │Coil   │           │                         │   │
│  │  │Pair │  │Pair │  │Pair   │           │                         │   │
│  │  └─────┘  └─────┘  └─────┘           │                         │   │
│  └───────────────────────────────────────┼─────────────────────────┘   │
│                                          │                             │
│  ┌───────────────────────────────────────┼─────────────────────────┐   │
│  │         GENERATION SUBSYSTEM          │                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌───────▼───────┐                 │   │
│  │  │  AFPM    │→ │Rectifier │→ │ Power         │                 │   │
│  │  │Generator │  │ + PFC    │  │ Conditioner   │──→ 48V Bus      │   │
│  │  └──────────┘  └──────────┘  └───────────────┘                 │   │
│  │                                                                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────┐                 │   │
│  │  │Pickup    │→ │MPPT      │→ │DC-DC          │──→ 48V Bus      │   │
│  │  │Coils (×6)│  │Rectifier │  │Converter       │                 │   │
│  │  └──────────┘  └──────────┘  └───────────────┘                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                      SENSOR SUITE                                │   │
│  │  18× Hall Sensors  ·  6× Current Sensors  ·  1× IMU             │   │
│  │  6× Temp Sensors   ·  1× Bus Voltage/Current Monitor             │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                   COMMUNICATION BUS                              │   │
│  │  ┌──────────┐     ┌──────────┐     ┌──────────┐                 │   │
│  │  │CAN-FD    │◄───►│Telemetry │◄───►│Safety    │                 │   │
│  │  │(1 MHz)   │     │(Ethernet)│     │Interlock │                 │   │
│  │  └──────────┘     └──────────┘     └──────────┘                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Subsystem Responsibilities

| Subsystem | Primary Function | Key Components |
|---|---|---|
| **Oscillator Array** | Generate directed thrust via asymmetric EM cycling | 6+ coil pairs, reaction masses, magnetic bearings |
| **Power Bus** | Distribute and condition electrical power | DC bus (48–800V), SiC H-bridge array, battery/cap buffer |
| **Control System** | Close position, force, and current loops | Trajectory planner, PID controller, mixing matrix, current regulators, Kalman filter |
| **Pickup/Generation** | Harvest electrical energy from oscillation + auxiliary gen | Pickup coils, MPPT rectifier, AFPM generator, power conditioner |
| **Sensor Suite** | Measure state for control and telemetry | Hall sensors, current sensors, IMU, temperature monitors |
| **Thermal Management** | Remove I²R waste heat | Coil cooling channels, passive radiators, active fluid loop |
| **Communication** | Inter-module coordination and external telemetry | CAN-FD, Ethernet telemetry, safety interlock circuit |

---

## 3.2 Coil Topology

### 3.2.1 Minimum Configuration: 6-Coil / 3-Axis Array

The minimum viable PEAT configuration uses six independent electromagnetic channels arranged as three opposing pairs, one pair per Cartesian axis:

```
            Z−
            ●
            │
      Y−●───┼───●Y+
            │
            ●
            Z+
```

Each axis pair shares a reaction mass that oscillates between the two coils. The six coils provide full 6-DOF authority:

| Coil Pair | Translation | Rotation |
|---|---|---|
| Z+/Z− | Vertical (Z, primary lift) | Yaw (Z-axis rotation) |
| X+/X− | Longitudinal (X, forward/back) | Roll (X-axis rotation) |
| Y+/Y− | Lateral (Y, left/right) | Pitch (Y-axis rotation) |

**Coupled DOF Management:** Translation and rotation on the same axis are decoupled through differential excitation. For the Z pair:
- Common-mode amplitude: Z translation (lift)
- Differential amplitude: Yaw torque

This is valid provided the reaction mass geometry separates the center of mass from the axis of rotation. In practice, adding more coils per axis (Section 3.2.3) improves decoupling.

### 3.2.2 Per-Coil Construction

Each individual coil assembly comprises three independent windings sharing a common magnetic circuit:

```
┌─────────────────────────────────────┐
│  PUMP WINDING                       │
│  (motor mode, parametric drive)     │
│  N_pump turns, L_pump, R_pump       │
├─────────────────────────────────────┤
│  PICKUP WINDING                     │
│  (generator mode, MPPT rectified)   │
│  N_pickup turns, L_pickup, R_pickup  │
├─────────────────────────────────────┤
│  SUSPENSION WINDING                 │
│  (magnetic bearing, centering + DC  │
│   bias for gravity preload)         │
│  N_sus turns, L_sus, R_sus          │
└─────────────────────────────────────┘
```

This three-winding topology mirrors a transformer: the pump winding is the primary (energy in), the pickup winding is the secondary (energy out), and the oscillating reaction mass is the moving core. Unlike a transformer, the core motion produces mechanical work.

### 3.2.3 Expansion Paths: 8-Coil and 12-Coil Configurations

**8-Coil Configuration:** Adds two redundant coils on the Z-axis, the most load-critical axis:
```
Z−a    Z−b
  ●    ●
    Y−●──●Y+
    X−●──●X+
  ●    ●
Z+a    Z+b
```
Benefits: Redundancy for safety-critical lift, improved yaw authority, graceful degradation on single-coil failure.

**12-Coil Configuration:** Four coils per axis in a quadrature arrangement:
```
Z−a──────────Z−b
  │            │
  │  Y+●  ●Y+  │
  │  X+●  ●X+  │
  │            │
Z+a──────────Z+b
```
Benefits: Full 6-DOF decoupling without cross-coupling compensation, 50% thrust margin on any axis, fault tolerance (N-2 for all axes).

### 3.2.4 Electrical Parameter Ranges

| Parameter | Baseline (48V) | Upgraded (800V SiC) | Rationale |
|---|---|---|---|
| Inductance per winding | 0.1–5 mH | 1–20 mH | Higher V → more turns → higher L |
| Resistance per winding | 0.1–1.0 Ω | 0.05–0.5 Ω | Lower I → thinner wire possible |
| Peak current | 10–100 A | 5–40 A | I²R ∝ 1/V² for same power |
| PWM frequency | 5–20 kHz | 20–50 kHz | SiC switches faster with lower loss |
| dL/dx target | ≥ 10 μH/mm | ≥ 20 μH/mm | Iron core or smaller gap |

---

## 3.3 Reaction Mass

### 3.3.1 Role and Physics

The reaction mass is the inertial element that the oscillating magnetic field pushes against. Per Newton's third law, the time-averaged force on the reaction mass equals and opposes the thrust delivered to the vehicle frame.

```
  F_coil_on_mass  =  −F_mass_on_frame
  ⟨F_thrust⟩       =  −⟨F_mass_oscillation⟩
```

The reaction mass stores kinetic energy during each half-cycle and returns it during the other half. The net energy per cycle (attraction impulse minus repulsion impulse) appears as useful thrust.

### 3.3.2 Design Constraints

| Constraint | Requirement | Rationale |
|---|---|---|
| Stroke clearance | ≥ 2× z₀ + 5 mm safety margin | Must never contact coil faces |
| Mechanical stiffness | First resonance > 10× oscillation frequency | Avoid structural coupling |
| Magnetic permeability | μ_r > 100 (ferromagnetic) for iron-core designs; μ_r ≈ 1 (paramagnetic) for eddy-current reduction | Trade: higher μ_r increases force density but also eddy losses |
| Mass tolerance | ±1% of design value | Imbalance creates vibration |
| Thermal stability | CTE < 15 ppm/K, survive 200°C | I²R heating from adjacent coils |
| Electrical isolation | > 1 MΩ to coil assembly | Prevent ground loops |

### 3.3.3 Material Selection

| Material | Density (kg/m³) | μ_r | Relative Cost | Eddy Loss | Recommendation |
|---|---|---|---|---|---|
| Mild steel (1018) | 7,870 | ~200 | $ | High | Baseline, iron-core coils |
| Laminated Si steel | 7,650 | ~2,000 | $$ | Low | Best for pump coils |
| Ferrite (MnZn) | 4,800 | ~2,000 | $$ | Very low | High-frequency prototypes |
| Aluminum 6061 | 2,700 | 1.0 | $$ | N/A | Non-magnetic carrier |
| Tungsten alloy | 17,000 | 1.0 | $$$$ | N/A | High-density mass needed |
| Copper (OFHC) | 8,960 | 1.0 | $$$ | N/A | Heat sink + mass combined |

**Recommended hybrid construction:** A laminated silicon steel core provides the magnetic circuit, housed in an aluminum carrier that also serves as a heat conductor. Tungsten inserts adjust mass without increasing volume.

### 3.3.4 Mounting and Suspension

Each reaction mass is suspended by active magnetic bearings that provide:
- **Axial confinement:** The pump/attraction coils themselves provide centering force along the oscillation axis
- **Radial centering:** Dedicated suspension coils (or passive reluctance centering from shaped pole faces)
- **Gravity preload:** A DC bias current in the Z-axis suspension coil counteracts weight

The active suspension loop runs at ≥ 10× the oscillation frequency. For a 15 Hz oscillation, this demands ≥ 150 Hz bandwidth — easily achieved with 20 kHz current regulators.

```
┌─ MAGNETIC SUSPENSION SCHEME ──────────────────────────────────────────┐
│                                                                        │
│      ┌──────┐              ┌──────┐                                   │
│      │Coil A│              │Coil B│                                   │
│      └──┬───┘              └──┬───┘                                   │
│         │                     │                                        │
│         ▼                     ▼                                        │
│    ┌──────────────────────────────────────┐                            │
│    │          REACTION MASS               │                            │
│    │  (laminated steel + aluminum carrier)│                            │
│    └──────────────────────────────────────┘                            │
│         ▲                     ▲                                        │
│      ┌──┴───┐              ┌──┴───┐                                   │
│      │Radial│              │Radial│                                   │
│      │Bearing│             │Bearing│                                   │
│      └──────┘              └──────┘                                   │
│                                                                        │
│    Stroke: 2·z₀ │ Gap to coil at full deflection: ≥ 5 mm             │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.3.5 Mass Allocation Across Axes

| Axis | Fraction of Total | Rationale |
|---|---|---|
| Z (vertical) | 50% | Primary lift — highest force requirement |
| X (longitudinal) | 30% | Forward thrust — secondary priority |
| Y (lateral) | 20% | Lateral maneuvering — lowest duty cycle |

Total reaction mass = 10–15% of vehicle mass at scale. For the 115 kg human-scale baseline: m_r = 17.25 kg, split as 8.6 kg Z, 5.2 kg X, 3.5 kg Y.

---

## 3.4 Power Bus Architecture

### 3.4.1 Baseline: 48V DC Bus

The 48V baseline is chosen for safety (SELV limits), component availability, and compatibility with existing drone/aerospace power systems.

```
48V Baseline Architecture:

  AFPM Gen → Rectifier → 48V Bus ─┬─ Battery/Cap Buffer (48V nominal)
                                   ├─ SiC Half-Bridge × N (coil drivers)
                                   ├─ 48→12V converter → sensor power
                                   ├─ 48→5V converter → MCU/logic power
                                   └─ 48→3.3V converter → isolated CAN/xcvr

  Bus capacitance: ≥ 10 mF (low-ESR electrolytic + ceramic bypass)
  Transient response: < 100 μs for ±10 A step load change
  Ripple: < 1% at 20 kHz (PWM fundamental)
```

**Component budget at 48V, 100 kW system:**
- Bus current: ~2,100 A
- I²R copper losses: ~99.7 kW (dominant)
- Practical limit: current density in bus bars becomes a mechanical design problem above ~500 A. At 48V/100 kW, the bus alone requires 4× parallel 4/0 AWG cables or custom laminated bus bars.

### 3.4.2 Upgrade Path: 800V SiC

The primary efficiency lever is higher bus voltage. The 48V → 800V transition delivers a 16× reduction in I²R losses for the same power throughput (P = V·I, I²R ∝ (P/V)²·R).

```
800V SiC Upgrade Architecture:

  AFPM Gen → PFC Rectifier → 800V Bus ─┬─ SiC H-Bridge × N (full bridge)
                                        │   (1200V SiC MOSFETs, R_ds(on) < 20 mΩ)
                                        ├─ 800→48V DC-DC (isolated, 2 kW)
                                        │   └─ legacy 48V loads
                                        ├─ 800→12V DC-DC → sensor power
                                        ├─ 800→5V DC-DC (isolated) → MCU/logic
                                        └─ 800→3.3V DC-DC (isolated) → CAN/xcvr

  Bus capacitance: ≥ 2 mF (film capacitor, 1200V rating)
  Switching frequency: 20–50 kHz (SiC enables high f with lower loss)
  dv/dt: < 10 V/ns (gate resistor tuned for EMI)
```

**Component budget at 800V, 100 kW system:**
- Bus current: ~125 A (manageable with single 2/0 AWG or 6 mm Cu bus bar)
- SiC MOSFETs: 1200V, R_ds(on) ≤ 20 mΩ, TO-247 or module package
- Gate drivers: Isolated, > 5 A peak, with desaturation detection
- DC-link capacitors: 2–5 mF film type, self-healing

### 3.4.3 Bus Protection and Sequencing

```
┌─ POWER-UP SEQUENCE ───────────────────────────────────────────────────┐
│                                                                        │
│  1. Pre-charge: limit inrush via NTC thermistor or active pre-charge   │
│     resistor (I < 5 A until bus reaches 90% nominal)                   │
│  2. Bus cap charged → close main contactor                            │
│  3. Enable auxiliary supplies (48V → 12V → 5V → 3.3V)                │
│  4. MCU boots → self-test → sensor initialization                     │
│  5. Enable gate drive bias supplies (isolated)                        │
│  6. Arm H-bridge outputs — start with zero duty cycle                 │
│  7. Ramp to operating point over 100 ms soft-start                    │
│  8. Engage control loops (current → force → trajectory)               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

Protection features:
- **Overcurrent:** Per-channel desaturation detection (< 2 μs trip), bus-wide hall-effect sensor
- **Overvoltage:** Active clamp (bus voltage > 105% → dump load engaged)
- **Undervoltage:** Brown-out protection, graceful coast-down on bus < 80% nominal
- **Reverse polarity:** Series Schottky diode on main bus input
- **Emergency dump:** IGBT dump circuit → 10 Ω, 10 kW resistor bank

---

## 3.5 Control Hierarchy

The PEAT control system is a three-tier cascade architecture, separated by bandwidth and function.

```
┌─ CONTROL HIERARCHY ─────────────────────────────────────────────────────┐
│                                                                          │
│  TIER 1 — OUTER LOOP (Trajectory + Position PID)                        │
│  ─────────────────────────────────────────────────────────────────────── │
│  Rate:     1 kHz                                                         │
│  Input:    6-DOF desired position from flight plan / joystick            │
│  Process:  Kalman-filtered state estimate vs. trajectory reference       │
│  Output:   Desired 6-DOF force vector F_desired ∈ ℝ⁶                    │
│  Law:      PID + feed-forward + gravity compensation                     │
│                                                                          │
│       F_desired_j = Kp_j·e_j + Ki_j·∫e_j·dt + Kd_j·d(e_j)/dt          │
│                    + m·a_desired_j + m·g_j                              │
│                                                                          │
│  TIER 2 — MID LOOP (Mixing Matrix / Force Allocation)                   │
│  ─────────────────────────────────────────────────────────────────────── │
│  Rate:     1 kHz (synchronous with outer loop)                           │
│  Input:    F_desired ∈ ℝ⁶                                               │
│  Process:  Pseudoinverse of actuation matrix                             │
│  Output:   Desired per-coil currents i_desired ∈ ℝᴺ                    │
│  Law:      i_desired = A⁺ · F_desired                                   │
│                                                                          │
│       A = [a₁ a₂ … aₙ]    where aⱼ ∈ ℝ⁶ = force/moment per amp         │
│       A⁺ = Aᵀ(AAᵀ)⁻¹     (Moore-Penrose pseudoinverse)                 │
│                                                                          │
│  For N > 6: null-space projection for current minimization               │
│       i = A⁺·F + (I − A⁺A)·z    where z optimizes ∥i∥₂                 │
│                                                                          │
│  TIER 3 — INNER LOOP (Per-Coil Current Regulation)                      │
│  ─────────────────────────────────────────────────────────────────────── │
│  Rate:     20 kHz (every PWM cycle)                                      │
│  Input:    i_desired per coil, i_measured per coil                       │
│  Process:  PI current error compensator → duty cycle                     │
│  Output:   PWM duty + polarity for each H-bridge                         │
│  Law:      V_applied = Kp_c·(i_des − i_meas) + Ki_c·∫(i_des−i_meas)dt  │
│                                                                          │
│       For each PWM cycle:                                                │
│         1. Sample i_meas (via LEM or shunt)                              │
│         2. Compute error e_i = i_desired − i_measured                    │
│         3. PI compensator → V_command                                    │
│         4. PWM modulator → duty = V_command / V_bus                      │
│         5. Polarity sign = sign(V_command)                               │
│         6. Apply to H-bridge with dead-time insertion                    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 3.5.1 Calibration PLL (Cross-Tier Synchronization)

The parametric pump requires the inner loop to inject energy at exactly 2× the oscillation frequency. A Kalman-filtered phase-locked loop synchronizes all three tiers:

| PLL Function | Input | Output | Rate |
|---|---|---|---|
| State estimation | Hall sensor zero-crossings | ω₀, φ, amplitude, damping | 10 kHz |
| Pump phase reference | Kalman state | φ_pump = 2·φ_osc + π/2 (thruster) or −π/2 (generator) | 1 kHz |
| Gain scheduling | Mass estimate, G-load, SOC | η_repel from lookup table | 10–100 Hz |

**Phase error requirement:** < 5° electrical (< 0.087 rad at 2ω₀). For 15 Hz oscillation, 2ω₀ = 30 Hz, 5° = 0.46 ms timing precision — easily met at 10 kHz measurement rate.

### 3.5.2 Asymmetry Ratio Modulation

The inner loop implements the asymmetry ratio η_repel directly via pulse-width control within each oscillation half-cycle:

```
Each oscillation half-cycle (T/2 = 1/(2f)) is divided into four phases:

  ┌──────────┬──────────┬──────────┬──────────┐
  │ ATTRACT  │  COAST   │  REPEL   │  COAST   │
  │ (pump on,│ (coast,  │ (pump    │ (coast,  │
  │  high V) │  no V)   │  reverse)│  no V)   │
  └──────────┴──────────┴──────────┴──────────┘
  ├─ t_att ──┤─ t_c1 ──┤─ t_rep ──┤─ t_c2 ──┤
  ├─────────────── T/2 ────────────────┤

  η_repel = I_rep / I_att ≈ (t_rep · V_rep) / (t_att · V_att)
```

The Kalman PLL ensures the phase of these pulses tracks the actual mechanical oscillation, compensating for load changes, thermal drift, and manufacturing tolerances.

---

## 3.6 Sensor Suite

### 3.6.1 Sensor Count and Placement

| Sensor Type | Count | Location | Purpose |
|---|---|---|---|
| Hall effect (linear) | 12 | 4 per axis, differential pair at each coil | Reaction mass position within stroke |
| Hall effect (limit) | 6 | 1 per coil, stroke end | Absolute position reference, safety |
| IMU (6-DOF) | 1 | Frame center | Vehicle acceleration + angular rate |
| Current sensor (LEM) | 6 | 1 per coil H-bridge output | Closed-loop current regulation |
| Temperature (NTC/RTD) | 6 | 1 per coil, embedded in winding | Thermal monitoring, protection |
| Bus voltage monitor | 1 | DC bus input | Over/undervoltage protection |
| Bus current monitor | 1 | DC bus input | Power tracking, fault detection |

**Total: 33 sensor channels** sampled at 10 kHz (over-sampled, decimated to loop rates).

### 3.6.2 Position Sensing

The primary position measurement uses differential Hall effect sensors:

```
  ┌─ HALL SENSOR PAIR PER COIL ──────────────────────────────────────────┐
  │                                                                        │
  │                       REACTION MASS                                    │
  │                  ┌──────────────┐                                      │
  │                  │   S  N  S  N │ ← magnet strip on mass               │
  │                  └──────────────┘                                      │
  │                        │                                               │
  │    Coil A ─────────────┼───────────── Coil B                           │
  │                        │                                               │
  │    H1──H2             │││             H3──H4                          │
  │    (H1+H2) diff = position relative to Coil A                         │
  │    (H3+H4) diff = position relative to Coil B                         │
  │    (H1+H2) − (H3+H4) = absolute position in gap                       │
  │                                                                        │
  │  Resolution: 10–100 μm (12-bit ADC, 3.3V range, 10 mV/mT sensitivity) │
  │  Range: ±z₀ × 1.5 (over-range detection)                              │
  └────────────────────────────────────────────────────────────────────────┘
```

The differential pair cancels common-mode fields (including the Earth's field and nearby coil stray fields) to first order. Residual common-mode error is < 2% of reading.

### 3.6.3 Current Sensing

Each H-bridge output includes a closed-loop Hall-effect current transducer (LEM or equivalent):

| Specification | Value |
|---|---|
| Measuring range | ±150 A (48V), ±60 A (800V) |
| Bandwidth | DC–200 kHz |
| Response time | < 1 μs |
| Accuracy | ±0.5% of reading |
| Isolation | Galvanic, > 2 kV |

The current signal feeds directly into the 20 kHz PI current regulator with < 2 μs total delay (sensor + ADC + PI computation + PWM update).

### 3.6.4 Sensor Fusion

A Kalman filter fuses all sensor data at 10 kHz into a single state estimate:

```
State vector (22 states):
  x ∈ ℝ⁶  : Vehicle position and orientation (6-DOF)
  v ∈ ℝ⁶  : Vehicle linear/angular velocity
  r ∈ ℝ⁶  : Reaction mass positions (3 axes × 2 masses = 6)
  ṙ ∈ ℝ⁶  : Reaction mass velocities
  b_g ∈ ℝ³ : Gyroscope bias
  b_a ∈ ℝ³ : Accelerometer bias

Measurements (33 channels):
  Hall positions (12), Hall limits (6 over-range bits)
  IMU accel (3), IMU gyro (3)
  Bus voltage (1), bus current (1)
  Current setpoint vs actual (6 error terms — not directly measured
    but inferred from regulator tracking)
```

---

## 3.7 Generation Subsystem

### 3.7.1 Primary: AFPM Generator

The Axial Flux Permanent Magnet (AFPM) generator provides the primary electrical power source, converting mechanical shaft power into DC bus voltage.

```
┌─ AFPM GENERATOR SPECIFICATION ─────────────────────────────────────────┐
│                                                                         │
│  Topology:   Dual-rotor, single-stator axial flux                      │
│  Rotor:      Surface-mount NdFeB N52 magnets on steel back-iron        │
│  Stator:     Ironless PCB stator (low eddy current) or slotted iron    │
│  Phases:     3-phase, wye or delta                                     │
│  Poles:      16–24 (scales with diameter)                              │
│  Rating:     Continuous: 110 kW (human-scale), Peak: 150 kW            │
│  Speed:      3000–6000 RPM (direct drive, no gearbox)                  │
│  Efficiency: > 92% at rated power                                      │
│  Cooling:    Air-cooled (forced) or liquid-cooled at > 50 kW           │
│                                                                         │
│  Output:     3-phase AC, 100–600 Vrms (depends on RPM, load)           │
│  → Rectifier → PFC → DC bus                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.7.2 Rectification and Power Conditioning

Two rectification stages handle the two generation sources:

| Source | Rectifier Type | Topology | Control |
|---|---|---|---|
| AFPM (primary) | Active PFC rectifier | 3-phase IGBT/SiC bridge | Bus voltage regulation (380V/800V) |
| Pickup coils (secondary) | MPPT boost rectifier | 6× interleaved boost, diode bridge per coil | Load impedance matching for max power transfer |

**AFPM rectification path:**
```
  AFPM → 3-phase EMI filter → SiC half-bridge × 3 (active rectifier)
       → DC link cap → bus voltage regulation loop
       → PFC: input current sinusoidal, PF > 0.98
       → Bus regulation: V_bus = V_ref ± 2%, 1 kHz bandwidth
```

**Pickup coil rectification path:**
```
  Pickup coil AC → full-wave diode bridge → DC link cap → MPPT boost converter
       → MPPT algorithm: perturb-and-observe, 100 Hz update rate
       → Virtual resistance: R_load = V_pickup² / P_target
       → Boost output feeds DC bus through isolation diode
```

### 3.7.3 Simultaneous Generation Physics

The pickup coils see the same oscillating magnetic flux as the pump coils. The induced voltage in both coil sets is:

```
  V_pump   = N_pump · dΦ/dt   (back-EMF, countered by driver)
  V_pickup = N_pickup · dΦ/dt  (rectified and harvested)

  Where dΦ/dt = (dΦ/dx) · (dx/dt) and dx/dt = reaction mass velocity
```

The pickup load creates a drag force on the oscillation (Lenz's law), which the pump coil must overcome. The steady-state energy balance per cycle:

```
  E_pump_in = E_thrust + E_pickup + E_loss
  
  Typical split at 115 kg baseline (numerical ODE):
    E_pump_in:  100%  (100.7 kW)
    E_loss:      99.0% (I²R copper)
    E_thrust:     5.0%
    E_pickup:     0.06%
```

The pickup recovery is small (~0.06% of input) due to the weak magnetic coupling between the oscillating reaction mass and the separate pickup windings. The pickup coils share the same magnetic circuit as the pump coils, and the flux is dominated by the pump excitation. Practical upper bound for simultaneous generation is 5–10% of total input, and this directly subtracts from thrust capability.

---

## 3.8 Thermal Management

### 3.8.1 Heat Sources and Magnitudes

The numerical ODE simulation for the 115 kg human-scale baseline reveals the thermal reality:

| Heat Source | Power (kW) | % of Total | Location |
|---|---|---|---|
| Coil I²R loss | 99.7 | 99.0 | Coil windings (all 6 coils) |
| SiC switching loss | ~1.0 | ~1.0 | H-bridge modules |
| Bearing eddy current | ~0.05 | ~0.05 | Reaction mass / bearings |
| Pickup coil I²R | ~0.01 | ~0.01 | Pickup windings |

**Total heat to reject: ~101 kW (continuous hover)**

This is the dominant engineering challenge. At 48V, each of the 6 coils dissipates ~16.6 kW as heat. Even at 800V with optimized coils, expect 30–50 kW total heat rejection.

### 3.8.2 Per-Coil Thermal Model

```
  R_θ_junction-ambient required:
    T_max_winding = 180°C (class H insulation)
    T_ambient     = 40°C  (worst-case)
    P_diss_coil   = 16.6 kW (per coil at 48V)
    
    R_θ_required = (180 − 40) / 16,600 = 0.0084 K/W  ← extremely low
  → 48V baseline requires aggressive liquid cooling
  → 800V upgrade: P_diss ≈ 5–8 kW per coil → R_θ ≈ 0.017–0.028 K/W
```

### 3.8.3 Cooling Strategies

| Strategy | Heat Transfer Coefficient | Max Flux | Complexity | Recommended For |
|---|---|---|---|---|
| **Passive conduction** | ~10 W/m²·K | ~1 kW/m² | Low | Control electronics only |
| **Forced air** | 50–100 W/m²·K | ~5 kW/m² | Low | 800V SiC heatsinks |
| **Oil immersion** | 200–500 W/m²·K | ~20 kW/m² | Medium | Coil windings (direct) |
| **Water-glycol cold plate** | 500–2,000 W/m²·K | ~50 kW/m² | High | Coils, power modules |
| **Two-phase (evaporative)** | 2,000–10,000 W/m²·K | ~200 kW/m² | Very high | Future high-density builds |
| **Cryogenic (LN₂, 77K)** | N/A (R drops 6×) | N/A | Extreme | Superconducting path |

**Baseline thermal architecture (800V upgrade):**

```
┌─ COOLING LOOP SCHEMATIC ───────────────────────────────────────────────┐
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │  Coil 1–6    │    │  SiC H-bridge│    │  AFPM stator │              │
│  │  (water-glycol│   │  cold plates  │    │  (water-glycol│             │
│  │   jacket per  │   │  (6×, paral.)│    │   jacket)    │              │
│  │   coil)       │    │              │    │              │              │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘              │
│         │                  │                   │                        │
│         └──────────────────┼───────────────────┘                        │
│                            │                                            │
│                     ┌──────▼───────┐                                    │
│                     │  Pump +      │                                    │
│                     │  Expansion   │                                    │
│                     │  Tank +      │                                    │
│                     │  Filter      │                                    │
│                     └──────┬───────┘                                    │
│                            │                                            │
│                     ┌──────▼───────┐                                    │
│                     │  Radiator    │                                    │
│                     │  (forced air,│                                    │
│                     │  aircraft-   │                                    │
│                     │  grade)      │                                    │
│                     └──────────────┘                                    │
│                                                                         │
│  Coolant: 50/50 water-glycol                                          │
│  Flow rate: ~40 L/min at 3 bar ΔP                                     │
│  Radiator: 0.5 m² frontal area, 10 kW/m²·K (flight speed provides RAM) │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.8.4 Passive Thermal Considerations

Even with active cooling, passive elements are critical:

- **Coil potting:** Thermally conductive epoxy (3–5 W/m·K) fills winding voids, conducts heat to outer jacket
- **Aluminum chassis:** Serves as a heat spreader (> 200 W/m·K), distributes hot spots
- **Phase-change materials:** Paraffin-based PCM (50–60°C melt point) absorbs transient peaks during maneuvers
- **Thermal interface:** 0.1 mm gap pad with 5 W/m·K between coil and cold plate

---

## 3.9 Communication Architecture

### 3.9.1 Real-Time Control Bus

The primary inter-module communication uses CAN-FD (Controller Area Network with Flexible Data-Rate):

| Parameter | Value | Rationale |
|---|---|---|
| Protocol | CAN-FD 2.0 | Deterministic, automotive-grade, widely available |
| Bit rate | 1 Mbps (arbitration), 5 Mbps (data) | Balances noise immunity vs throughput |
| Topology | Dual-redundant bus | Fault tolerance |
| Frame format | 64-byte payload, extended ID | Enough for per-coil setpoint + status |
| Cycle time | 250 μs (4 kHz bus rate) | Exceeds 1 kHz outer loop requirement |
| Nodes | 12 (6× local coil controllers, 1× central, 1× IMU, 1× power manager, 3× spare) | |
| Protocol | Custom lightweight: sequence number, CRC-16, timeout detection | No CANopen overhead |

**CAN-FD message map:**

| Message ID | Sender | Payload | Rate | Priority |
|---|---|---|---|---|
| 0x100 | Central → Coil N | i_desired, polarity, mode | 4 kHz | Critical |
| 0x200 | Coil N → Central | i_meas, position, temp, fault | 4 kHz | Critical |
| 0x300 | IMU → Central | Accel (3×), gyro (3×), timestamp | 4 kHz | Critical |
| 0x400 | Power Mgr → Central | V_bus, I_bus, SOC, temp | 1 kHz | High |
| 0x500 | Central → All | Synchronization pulse | 4 kHz | Critical |

### 3.9.2 Telemetry Link

A higher-bandwidth Ethernet link carries non-real-time data for monitoring, logging, and external control:

| Parameter | Value |
|---|---|
| Physical layer | 100BASE-TX (shielded, automotive-grade) |
| Protocol | UDP (real-time) + TCP (configuration/logging) |
| Data rate | 1 Mbps sustained (conservative, 100 Mbps link) |
| Latency | < 10 ms UDP, unbounded TCP (for logging only) |

**Telemetry streams:**
1. **System health** (10 Hz): Bus voltage, temperatures, fault flags
2. **6-DOF state** (100 Hz): Position, velocity, attitude (Kalman estimate)
3. **Per-coil waveform** (1 kHz): Current, voltage, position (diagnostic, on-demand)
4. **Power flow** (10 Hz): Pump power, pickup power, bus power, generator power, net

### 3.9.3 Safety Interlock

The safety interlock is a separate, hardware-only circuit independent of the main control and communication buses:

```
┌─ SAFETY INTERLOCK CHAIN ───────────────────────────────────────────────┐
│                                                                         │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                │
│  │  E-Stop      │   │  Position    │   │  Over-       │                │
│  │  Button (1×) │   │  Limit       │   │  temperature │                │
│  │              │   │  Switches    │   │  (thermostat) │                │
│  │  (NC, break  │   │  (6×, NC,    │   │  (6×, NC,    │                │
│  │   to open)   │   │   break if   │   │   break if   │                │
│  │              │   │   exceeded)  │   │   exceeded)  │                │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘                │
│         │                 │                   │                          │
│         └─────────────────┼───────────────────┘                          │
│                           │                                              │
│                    ┌──────▼───────┐                                      │
│                    │  AND chain   │  (all NC in series)                  │
│                    │  (hardwired, │                                      │
│                    │   failsafe)  │                                      │
│                    └──────┬───────┘                                      │
│                           │                                              │
│                    ┌──────▼───────┐                                      │
│                    │  Gate Drive  │  Enable line → all H-bridges         │
│                    │  Enable      │  (pulled low → all FETs off)         │
│                    │  (active     │                                      │
│                    │   high)      │                                      │
│                    └──────────────┘                                      │
│                                                                         │
│  Any interrupion in the chain:                                         │
│    1. All H-bridge outputs go to high-impedance (FETs off) < 1 μs     │
│    2. Coil currents freewheel through body diodes                       │
│    3. Reaction mass returns to mechanical center (spring-centered)      │
│    4. Emergency descent: controlled dump resistor engagement            │
│    5. MCU detects interlock trip via optocoupler, initiates recovery    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.9.4 Timing Budget

The end-to-end control latency budget for the critical path (sensor → Kalman → PID → mixing → current regulator → PWM):

```
  ┌─ LATENCY BUDGET ──────────────────────────────────────────────────────┐
  │                                                                        │
  │  Stage                              Time       Cumulative              │
  │  ─────────────────────────────────────────────────────────────────    │
  │  Hall sensor ADC (12-bit, 1 μs)    1 μs       1 μs                    │
  │  Current sensor (LEM, 0.5 μs)      1 μs       2 μs                    │
  │  CAN-FD frame reception (64 byte)  25 μs     27 μs                    │
  │  Kalman filter prediction           5 μs     32 μs                    │
  │  Kalman filter update              10 μs     42 μs                    │
  │  PID control law                    5 μs     47 μs                    │
  │  Mixing matrix (pseudoinverse)      5 μs     52 μs                    │
  │  Current PI compensator (×6)        8 μs     60 μs                    │
  │  PWM update + dead-time             2 μs     62 μs                    │
  │  Gate drive propagation             1 μs     63 μs                    │
  │  Current slew (L/R) to setpoint    10 μs     73 μs                    │
  │                                                                        │
  │  Total sensor-to-force latency:     < 100 μs                          │
  │  Loop margin at 20 kHz (50 μs       > 30% margin                      │
  │    available, 73 μs used at peak)                                      │
  │                                                                        │
  └────────────────────────────────────────────────────────────────────────┘
```

---

## 3.10 Architecture Decisions Summary

| Decision | Choice | Alternatives Considered | Rationale |
|---|---|---|---|
| Oscillator count | 6 minimum, expandable to 8/12 | 4 (under-actuated), 8 (cost) | 6 is minimum for full 6-DOF rank |
| Reaction mass | Separate per axis | Combined 3D mass, gimbal | Simpler dynamics, independent axis control |
| Power bus voltage | 48V baseline / 800V upgrade | 400V, 1kV | 48V for safety + prototyping; 800V for efficiency |
| Current regulation | 20 kHz PI + PWM | Hysteretic, predictive | Simple, proven, adequate bandwidth |
| Position sensing | Differential Hall effect | Laser, inductive, capacitive | Low cost, adequate resolution (100 μm) |
| Interconnect | CAN-FD | EtherCAT, SPI daisy chain | Deterministic, fault-tolerant, adequate bandwidth |
| Cooling | Water-glycol cold plate | Oil immersion, air only | Required for >50 kW heat rejection |
| Generator | AFPM (separate unit) | Integrated pickup-only | Pickup can't provide 100 kW; external gen needed |

---

*End of Chapter 3 — System Architecture*
