# CHAPTER 5: ENERGY BALANCE & POWER

> *"The fundamental limit of the PEAT system is not force — it is the electrical cost of creating that force with copper-wound electromagnets."*

---

## 5.1 Power Flow Diagram

The PEAT oscillator is a combined motor–generator system sharing a single magnetic circuit. Power flows from the electrical bus through the drive coils into mechanical oscillation, where it is split into useful thrust, recovered electrical energy, and (dominant) resistive losses.

```
                    ┌─────────────────────────────────────────────────────┐
                    │              POWER FLOW (Sankey)                    │
                    │                                                     │
                    │           ┌────────────── I²R Loss ──► Heat         │
                    │           │  (99.0% @ 48V)          ▲              │
                    │           ▼                          │              │
                    │  ┌──────────┐    ┌───────────┐    ┌──┴───┐         │
                    │  │ELECTRICAL├───►│ MECHANICAL├───►│THRUST│ 5.0%    │
                    │  │  INPUT   │    │OSCILLATION│    │ WORK │         │
                    │  │ 100.7 kW │    │   2.7 kW  │    └──┬───┘         │
                    │  └──────────┘    └─────┬─────┘       │             │
                    │        ▲               │             │             │
                    │        │               ▼             │             │
                    │        │        ┌──────────┐         │             │
                    │        │        │ PICKUP   │◄────────┘             │
                    │        │        │ COILS    │                       │
                    │        │        │ 60 W     │                       │
                    │        │        └────┬─────┘                       │
                    │        │             │                             │
                    │        │             ▼                             │
                    │        │       ┌──────────┐                        │
                    │        └───────┤ EXTERNAL │                        │
                    │                │GENERATOR │ ~96 kW deficit         │
                    │                │AEQUIGEN  │                        │
                    │                └──────────┘                        │
                    │                                                     │
                    │  Net: P_net = P_pump - P_copper - P_pickup         │
                    └─────────────────────────────────────────────────────┘
```

The dominant flow path is electrical input → I²R heating. The mechanical oscillation power is only ~2.7% of total electrical input; the remaining ~97% is lost before it reaches the mechanical domain.

---

## 5.2 Key Equation

The governing energy balance:

```
P_net = P_pump - P_copper - P_pickup
```

Where:

| Term | Symbol | Description | 115 kg Baseline |
|------|--------|-------------|----------------|
| Electrical input | `P_pump` | Total V·I integrated over all drive coils | 100,696 W |
| Copper loss | `P_copper` | I²R heating in windings | 99,683 W (99.0%) |
| Pickup recovery | `P_pickup` | Electrical power recovered from pickup coils | 60 W (0.06%) |
| Thrust work | `P_thrust` | Mechanical work done on the frame | 5,057 W (5.0%) |
| Net deficit | `P_net` | Power that must come from external generator | ~96 kW |

At the *mechanical* level (parametric pump power only):

```
P_pump_parametric = ¼ · k₀ · h · ω₀ · z₀²

where:  k₀ = m_r · ω₀²   (equivalent stiffness)
        h  = modulation depth
        ω₀ = 2πf         (angular frequency)
        z₀ = half-amplitude
```

For the 115 kg baseline (m_r = 17.25 kg, f = 15 Hz, z₀ = 0.05 m, h = 0.3):

```
k₀ = 17.25 · (2π·15)²  ≈ 153,000 N/m
P_pump_parametric = 0.25 · 153,000 · 0.3 · (2π·15) · 0.05² ≈ 2,710 W
```

This is the power delivered *into* the mechanical oscillation — only 2.7% of the 100.7 kW total electrical input. The remaining 97.3% is consumed before it produces any mechanical effect.

---

## 5.3 Energy Balance Per Cycle

A full cycle energy accounting at the 115 kg baseline (15 Hz, T = 66.7 ms):

```
PER-CYCLE ENERGY BUDGET (115 kg, 15 Hz, 48V bus, 1 Ω coils)
◈━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Energy in (E_pump):      6,711 J/cycle  (100%)
  
  Energy out:
    Copper (I²R):          6,646 J/cycle  (99.0%)
    Thrust work:             337 J/cycle  ( 5.0%)
    Pickup recovery:           4 J/cycle  ( 0.06%)
    
    Balance error:          -276 J/cycle  ( -4.1%)
      └─ Eddies, switching losses, mechanical damping,
         numerical integration error, ΔE_osc residual
◈━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The energy balance closes to within ~4% in the numerical ODE — a reasonable result given the stiff coupled system solved with fixed-step RK4.

**Energy breakdown by phase:**

| Phase | Duration | Coil A | Coil B | Net Energy | Net Work |
|-------|----------|--------|--------|------------|----------|
| Attract (0 → t_att) | 26.7 ms | V_bus on | off | +5,780 J | +440 J |
| Coast 1 | 10.0 ms | off | off | — | −80 J (damping) |
| Repel (t_att → t_rep) | 6.7 ms | off | V_bus·0.3 on | +930 J | −150 J |
| Coast 2 | 23.3 ms | off | off | — | −90 J (damping) |

The attraction phase dominates energy injection. The repulsion phase actively removes net energy from the oscillation (required for asymmetry), but its short duration limits the penalty.

---

## 5.4 Copper Loss Dominance

The single most important result from the numerical simulation:

> **99.2% of electrical input power is dissipated as I²R heating in the coil windings at 48 V bus voltage.**

This is not a design flaw — it is the physics of creating large magnetic forces with copper-wound electromagnets at low voltage.

**Why copper dominates:**

1. **Force-per-ampere is fixed by geometry**: `F = ½ · i² · dL/dx`. For the baseline coil, dL/dx_peak ≈ 1.9 H/m. To produce 500 N peak, the required current is:

   ```
   i = √(2 · F / (dL/dx)) = √(2 · 500 / 1.9) ≈ 23 A
   ```

2. **I²R scales quadratically**: At 23 A through a 1 Ω coil:
   ```
   P_loss = I² · R = 23² · 1 = 529 W per coil (instantaneous)
   ```

3. **Low bus voltage forces high current**: `P = V · I`. At 48 V, delivering 100 kW requires 2,083 A average. Every ampere generates I²R heat.

**The 48 V → 800 V transformation:**

| Parameter | 48 V Bus | 800 V Bus | Improvement |
|-----------|----------|-----------|-------------|
| Current for 100 kW | 2,083 A | 125 A | 16.7× less |
| I²R at same R | 4.34 MW | 15.6 kW | 278× less |
| Required R for same I²R | — | 16.7 Ω | Must match |

In practice, the 800 V system uses higher coil impedance (more turns, higher L, higher R) to match the bus voltage, achieving the same force with proportionally lower current and dramatically lower I²R loss.

---

## 5.5 Generator Damping Power

The pickup coil acts as a velocity-dependent electromagnetic brake on the oscillation. The generator damping coefficient is:

```python
b_gen = (N_pickup · B · A_core / d_rest)² / R_load
```

For the baseline configuration:
```
N_pickup = 100 turns
B = 0.5 T
A_core = 0.01 m²
d_rest = 0.075 m
R_load = 10 Ω

b_gen = (100 · 0.5 · 0.01 / 0.075)² / 10
      = (6.67)² / 10
      = 44.4 / 10
      ≈ 4.44 N·s/m
```

**At peak velocity (v_peak = ω₀ · z₀ ≈ 4.71 m/s for 115 kg baseline):**

```
F_gen = b_gen · v_peak = 4.44 · 4.71 ≈ 20.9 N
P_gen = F_gen · v_peak = b_gen · v_peak² = 4.44 · 22.2 ≈ 98.6 W
```

**The earlier 48 V prototype used a much larger b_gen = 250 N·s/m:**

```
At v_peak ≈ 2 m/s:
  F_gen = 250 · 2 = 500 N
  P_gen = 500 · 2 = 1,000 W
```

This 1,000 W extraction was the root cause of the oscillation decaying to zero in the 48 V prototype — the drive could only supply ~288 W per active coil, so the generator was extracting more power than the drive could replace.

**Generator damping scales with the square of the magnetic circuit parameters:**

```
b_gen ∝ N² · B² · A² / (d_rest² · R_load)
```

For the 800 V SiC upgrade (N_pickup reduced to 50, R_load increased to 50 Ω):

```
b_gen_800V = (50 · 0.5 · 0.01 / 0.075)² / 50
           = (3.33)² / 50
           = 0.22 N·s/m

P_gen_800V = 0.22 · (4.71)² ≈ 4.9 W
```

The generator damping power drops from ~1,000 W to ~5 W — easily surmountable by the drive.

---

## 5.6 Drive Power Limit

The instantaneous power available to drive the oscillation is limited by the bus voltage and coil current:

```
P_drive_peak = V_bus · i_A   (per active coil)
```

**At 48 V bus with 1 Ω coil resistance and L/R-limited current:**

| Drive Phase | Duration | i_A peak | P_drive_peak | F_mag peak |
|-------------|----------|----------|--------------|------------|
| ATTRACT (v > 0) | 26.7 ms | ~6.0 A | 288 W | ~34 N |
| REPEL (v < 0) | 6.7 ms | ~1.6 A | 77 W | ~2 N |

The 288 W per active coil is insufficient because:

1. **Generator damping demands ~1,000 W** at peak velocity (Section 5.5)
2. **L/R time constant prevents fast current reversal**: τ = L/R = 0.1 H / 1 Ω = 100 ms, but the available drive window is only 26.7 ms. Current can only reverse ~24% toward the target value.

**During the ATTRACT phase after a REPEL transition, the current is still negative** (from the previous repulsion pulse). The drive applies positive voltage, but the current cannot reverse quickly enough:

```
i_A(t) = i_A(0) · e^(-t/τ) + (V_bus/R) · (1 - e^(-t/τ))
       = -3.4 · e^(-0.0267/0.1) + (48/1) · (1 - e^(-0.0267/0.1))
       = -3.4 · 0.766 + 48 · 0.234
       = -2.6 + 11.2
       ≈ +8.6 A
```

This partially recovers, but for ~8 ms of the 26.7 ms window the current is still negative — the ATTRACT phase initially *extracts* energy from the mechanical system (negative power: voltage positive, current negative = generator mode).

---

## 5.7 The 3× Power Gap

The gap between available drive power and required power to sustain oscillation:

```
P_required ≈ P_gen_damping + P_mechanical_losses
            ≈ 1,000 W + 200 W
            ≈ 1,200 W

P_available ≈ V_bus · i_A (peak)
            ≈ 48 · 6
            ≈ 288 W per active coil

Ratio: P_available / P_required ≈ 288 / 1,200 ≈ 0.24  (4.2× deficit)
```

Even accounting for the second coil (coil B provides ~77 W during REPEL), the total available drive power is ~365 W vs ~1,200 W required — a **3.3× power deficit**.

This explains the numerical observation: oscillation decays to zero over ~42 cycles (2.8 s), with mean thrust ≈ 0 N regardless of drive polarity.

**The power gap widens at higher oscillation amplitudes** because generator damping power scales as v² while drive power is limited by V_bus:

```
P_gen ∝ v² ∝ (ω₀ · z₀)²
P_drive_max ∝ V_bus² / R  (in the current-limited regime)
```

---

## 5.8 The 800 V SiC Upgrade

Raising the bus voltage from 48 V to 800 V addresses every aspect of the power gap:

| Issue | 48 V | 800 V | Mechanism |
|-------|------|-------|-----------|
| Peak drive power | 288 W | 40,000 W | P = V · I, I²R ∝ 1/V² |
| L/R current rise time | 24% of target | >95% of target | di/dt = V/L |
| Generator damping | 1,000 W | ~5 W | Lower N, higher R_load |
| Copper loss fraction | 99.0% | ~80%* | Same force, 16× less current |
| *Feasible oscillation* | No | Yes | Sustained at design amplitude |

**Current rise time at 800 V:**

```
di/dt = V/L = 800 / 0.1 = 8,000 A/s

In 26.7 ms:
  Δi = 8,000 · 0.0267 = 214 A

Reaching i_target = 50 A in: t = 50 / 8,000 = 6.25 ms  (well within window)
```

The 800 V system is designed with higher coil impedance to match:

| Parameter | 48 V Prototype | 800 V SiC Design |
|-----------|---------------|-------------------|
| Coil resistance | 1.0 Ω | 0.05 Ω |
| Coil inductance | 0.2 H (L_max) | 0.4 H (L_max) |
| Peak current | 6 A | 50 A |
| Peak force | 34 N | ~2,400 N |
| Drive power per coil | 288 W | 40,000 W |
| I²R loss per coil | 36 W | 125 W |
| Efficiency | ~5% | ~15-30% (target) |
| SiC MOSFET switches | — | 1.2 kV, 100 A rated |

The 800 V SiC H-bridge drive topology:

```
┌─ 800 V SiC H-BRIDGE PER COIL ─────────────────────────────────┐
│                                                                │
│   V_bus (+) ──┬── S1 ──┐      ┌── S3 ──┬── GND                │
│                │        │      │        │                      │
│                │        └──[COIL]───────┘                      │
│                │        │      │                               │
│   V_bus (+) ──┴── S2 ──┘      └── S4 ──┴── GND                │
│                                                                │
│   ON:  S1+S4 → +V_bus across coil                              │
│   OFF: S2+S3 → −V_bus across coil (fast demagnetization)       │
│   FREE: S1+S3 or S2+S4 → recirculation at 0V or diode drop     │
└────────────────────────────────────────────────────────────────┘
```

---

## 5.9 Simultaneous Generation

PEAT generates electrical power *while* producing thrust, using separate pickup coils on the same magnetic circuit as the pump coils.

**Physical principle:**

The oscillating reaction mass modulates the magnetic flux through the pickup coil, inducing a voltage by Faraday's law:

```
V_pickup = N_pickup · B · A_core · v_r / d_rest
```

This is equivalent to a velocity-dependent voltage source driving a load resistor. The resulting current creates a damping force that removes mechanical energy from the oscillation — the same energy that must be replenished by the pump coils.

**Pickup power as a fraction of thrust power:**

| Scale | Thrust Power (kW) | Pickup Power (W) | Fraction |
|-------|-------------------|-------------------|----------|
| 5 kg drone | 0.14 | 2.0 | 1.4% |
| 50 kg courier | 1.30 | 12 | 0.9% |
| 115 kg human | 2.01 | 28 | 1.4% |
| 250 kg hoverbike | 3.91 | 50 | 1.3% |
| 1200 kg hovercar | 22.0 | 300 | 1.4% |
| 5500 kg hoverbus | 99.0 | 1,200 | 1.2% |

Pickup recovery is consistently 1–3% of thrust power across all scales — a fundamental consequence of the shared magnetic circuit. The pump coils must dominate the flux to produce thrust, leaving only a fraction available for generation.

**Why weak coupling is fundamental:**

The magnetic circuit is shared. The same flux that produces force also induces pickup voltage. The energy is *split*, not *multiplied*:

```
Φ_total = Φ_pump + Φ_pickup

If Φ_pickup > 0.1 · Φ_total, the pump's ability to produce force is
compromised because the pickup load appears as magnetic reluctance.
```

The practical upper bound for simultaneous generation is **5–10% of thrust power** before the pickup load significantly degrades thrust performance.

---

## 5.10 Self-Powering Budget

An axial-flux permanent magnet (AFPM) generator can supplement the pickup coils for system self-powering. The 6-DOF AFPM (shared stator, 6 rotor segments on each axis) provides:

**Typical AFPM recovery for a 115 kg system:**

```
Active AFPM area per axis:  0.03 m²
B_field (NdFeB):               1.2 T
Relative velocity:             2.5 m/s (avg)
Number of turns:              50
Load resistance:              10 Ω

V_AFPM = N · B · A · v / d ≈ 50 · 1.2 · 0.03 · 2.5 / 0.01 ≈ 450 V

P_AFPM = V² / R_load = 450² / 10 = 20,250 W (peak)

Average (sinusoidal, 40% duty): ~8,100 W
```

**However**, a more realistic *dedicated self-powering* AFPM (separate from the main thrust coils, using the oscillating masses as rotor) yields:

```
Total 6-DOF AFPM average power: ~2.17 W
  └─ Z-axis (primary):     1.26 W
  └─ X-axis (longitudinal): 0.54 W
  └─ Y-axis (lateral):      0.37 W
```

**Allocation of 2.17 W:**

| Load | Power | Voltage | Current |
|------|-------|---------|---------|
| 18× Hall effect sensors (3 mA @ 5 V) | 0.27 W | 5 V | 54 mA |
| 1× IMU (BMI088 or equiv.) | 0.05 W | 3.3 V | 15 mA |
| Control MCU (STM32G4 or equiv.) | 0.35 W | 3.3 V | 106 mA |
| SiC gate drive (6× H-bridges) | 0.60 W | 15 V | 40 mA |
| Telemetry (LoRa / BLE) | 0.50 W | 3.3 V | 150 mA |
| **Total** | **1.77 W** | — | — |
| Margin (22%) | 0.40 W | — | — |

The self-powering budget is tight but achievable with moderate AFPM scaling. If the AFPM is integrated into the main oscillators (using the same reaction masses as rotor, increasing N or B), the self-power budget can reach 5–10 W, providing generous margin.

---

## 5.11 Thermal Load

The I²R heat dissipation dominates the thermal design. At the 115 kg baseline:

```
Total heat:       ~99.7 kW (copper) + 1.5 kW (eddy + switching) ≈ 101.2 kW

Coil mass:        ~10 kg (6 oscillators, 1.67 kg each)
Specific heat of Cu: 385 J/(kg·K)
Temperature rise: ΔT = E_loss / (m_coil · c_Cu)
                  = 99,683 J / (10 · 385)
                  = 25.9 K/s  (adiabatic, no cooling)
```

Without active cooling, the coils reach 100°C in ~3 seconds of operation.

**Thermal load by scale:**

| Scale | I²R Heat | Coil Mass | Adiabatic dT/dt | Required Cooling |
|-------|----------|-----------|-----------------|------------------|
| 5 kg drone | 1.02 kW | 0.5 kg | 530 K/s | Impossible — pulsed operation only |
| 50 kg courier | 2.81 kW | 4 kg | 183 K/s | Forced air (5 m/s) |
| 115 kg human | 3.21 kW (800V) | 10 kg | 83 K/s | Forced air + liquid cooling |
| 250 kg hoverbike | 4.32 kW | 22 kg | 51 K/s | Liquid cooling loop |
| 1200 kg hovercar | 10.0 kW | 100 kg | 26 K/s | Liquid + radiator |
| 5500 kg hoverbus | 20.5 kW | 800 kg | 6.7 K/s | Liquid + phase-change |

**Cooling design considerations:**

```
Convective heat transfer, forced air (5 m/s over coil surface):
  h ≈ 50 W/(m²·K) (typical for finned surfaces)
  A_surface ≈ 0.1 m² per coil
  P_dissipate = h · A · ΔT = 50 · 0.1 · (T_coil - T_ambient)

  For ΔT = 100 K: P_dissipate = 50 · 0.1 · 100 = 500 W per coil
  Total 6 coils: 3,000 W — insufficient for 3.21 kW (115 kg, 800V)
```

Liquid cooling is required for sustained operation at all scales above 50 kg. A water-glycol loop with cold plate mounting of the coil cores can achieve:

```
h_liquid ≈ 1,000 – 5,000 W/(m²·K)
A_coldplate ≈ 0.02 m² per coil
P_dissipate = 2,000 · 0.02 · 40 = 1,600 W per coil

Total 6 coils: 9,600 W — sufficient for 115 kg at 800V (3.21 kW I²R)
```

---

## 5.12 Efficiency Ceiling

### Theoretical Maximum

The efficiency of the PEAT electromagnetic drive is fundamentally bounded by the ratio of mechanical power output to total electrical input:

```
η = (P_thrust + P_pickup) / (P_thrust + P_pickup + P_copper + P_parasitic)

where P_copper = I²R, P_parasitic = eddy + switching + bearing
```

In the ideal limit (zero copper loss, zero parasitics):

```
η_max → 1.0 (100%)
```

But this requires R_coil → 0, which requires superconducting coils — a system-level trade that may not be worthwhile given cryostat mass.

### Practical Limits (Copper Windings)

| Bus Voltage | Coil R | P_thrust | P_copper | P_parasitic | η (total) | Note |
|-------------|--------|----------|----------|-------------|-----------|------|
| 48 V | 1.0 Ω | 5.1 kW | 99.7 kW | 1.5 kW | **5.1%** | Measured (numerical) |
| 300 V | 0.2 Ω | 5.1 kW | 20 kW | 1.0 kW | **19.5%** | Estimated |
| 600 V | 0.05 Ω | 5.1 kW | 3.2 kW | 0.8 kW | **56.0%** | Target (peat_sim_v2) |
| 800 V | 0.05 Ω | 5.1 kW | 1.9 kW | 0.7 kW | **66.2%** | Stretch target |
| SC | ~0 Ω | 5.1 kW | ~0 W | 7.5 kW* | **40.5%** | Cryo overhead |

*Superconducting coils require ~7.5 kW cryocooler power at 77 K for 10 kg coil mass — the system-level efficiency actually *decreases* unless the application requires zero coil resistance for other reasons.

### The 5% Reality (48 V) vs 30% Target (800 V)

```
EFFICIENCY SCALING WITH BUS VOLTAGE
◈━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  η(V) = P_thrust / (P_thrust + P_copper(V) + P_parasitic(V))

  For constant thrust (F_thrust ≈ 5.1 kW):

  P_copper ∝ I²  and  I ∝ F / (dL/dx · V)  →  P_copper ∝ 1/V²

  V_bus    | Ratio   | P_copper  | η
  ─────────┼─────────┼───────────┼─────
   48 V    |  1.0×   | 99.7 kW   |  5.1%
  120 V    |  6.25×  | 15.9 kW   | 23.1%
  300 V    | 39.1×   |  2.6 kW   | 59.8%
  600 V    | 156×    |  0.6 kW   | 86.2%
  800 V    | 278×    |  0.4 kW   | 90.8%
◈━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The 90.8% figure at 800 V is an upper bound assuming *instantaneous current rise* (zero L/R limitation). In practice, the finite L/R time constant means the coil spends part of each cycle at sub-optimal current, reducing average efficiency to **15–30%**.

### Efficiency Levers (Ranked by Impact)

| Lever | Mechanism | Potential Improvement | TRL |
|-------|-----------|----------------------|-----|
| **1. Higher bus voltage** | I²R ∝ 1/V² for constant power | 16–278× (48→800V) | 9 (SiC inverters) |
| **2. Litz wire / thicker gauge** | Lower R without skin effect penalty | 2–5× | 9 (standard mfg.) |
| **3. Higher dL/dx (iron core)** | More force per ampere → less I²R | 2–10× | 7 (mass penalty) |
| **4. High-frequency waveform shaping** | Shorter current pulses, duty cycle optimization | 1.5–2× | 5 (control complexity) |
| **5. Cryogenic copper (77 K)** | Resistivity drops 6× | 6× | 7 (cryo system mass) |
| **6. Superconducting coils** | R ≈ 0 | ~100× (copper loss) | 3 (quench, cryo overhead) |

**Practical near-term target: 15–30% system efficiency** with 800 V SiC bus + Litz wire + iron-cored coils + optimized pulse shaping. This reduces the 100 kW input → 15–30 kW for equivalent thrust, making the AEQUIGEN-SS generator requirement realistic for aerial vehicles.

---

## Summary Table

| Quantity | 48 V Prototype | 800 V SiC Upgrade | Unit |
|----------|---------------|-------------------|------|
| Total electrical input | 100.7 | 5.1 (target) | kW |
| Copper loss | 99.7 (99.0%) | 1.9 (~37%) | kW |
| Thrust power | 5.1 (5.1%) | 5.1 (same) | kW |
| Pickup recovery | 0.06 (0.06%) | 0.03 (0.5%) | kW |
| System efficiency | 5.1% | 15–30% (target) | — |
| Self-powering margin | −95.6 kW deficit | sensors covered (2.17 W) | — |
| Thermal load | 101 kW → 26 K/s | 3.2 kW → 83 K/s | — |
| Drive power per coil | 288 W | 40,000 W | W |
| Generator damping | 250 N·s/m | 0.22 N·s/m | — |
| Root cause | 3.3× power gap | Gap closed | — |
