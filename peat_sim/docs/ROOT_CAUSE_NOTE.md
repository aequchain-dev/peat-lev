# PEAT Thrust Simulation — Root Cause Analysis

## Symptom
Simulation shows oscillation decays to zero over ~42 cycles (2.8s). Mean thrust = 0 N regardless of drive polarity.

## Corrected Bug: Drive Polarity Inversion
**Found and fixed**: `get_drive_state` had inverted logic:
- `v > 0` (moving +x) → ATTRACT → `VA = +V_bus` → force toward +x ✓
- `v < 0` (moving -x) → REPEL → `VA = -V_bus` → force toward -x ✓

The old code returned COAST for velocity-zero boundary, ATTRACT when v < 0 (wrong), and REPEL when v > 0 (wrong). **FIXED.**

This fix is correct and active. However, the oscillation still decays because of the deeper root cause below.

## Root Cause: Fundamental Power Insufficiency

### Generator Damping Is Too Large
The `init_params()` function computes a generator damping coefficient:

```
b_gen = 250 N·s/m   (from pickup coil electromagnetic coupling)
```

At peak velocity (v_peak ≈ 2 m/s):
- Damping force: `F_gen = b_gen · v = 250 · 2 = 500 N`
- Power consumed: `P_gen = F_gen · v = 500 · 2 = 1000 W`

This is the power that the drive must supply to sustain oscillation.

### Drive Cannot Supply Enough Power
Bus voltage: 48 V · Coil resistance: 1 Ω · Max inductance: 0.2 H

| Drive Phase | Duration | L/R-limited current | Force per coil | Net force |
|---|---|---|---|---|
| t_repel (6.7 ms) | Too short | i_A_max < 1.6 A | ~2 N | ~3 N |
| t_attract (26.7 ms) | Better but limited | i_A_max < 6.0 A | ~34 N | ~34 N |

At 6 A and dL/dx_peak = 1.9 H/m:
```
F_mag = 0.5 · dL/dx · (i_A² - i_B²) = 0.5 · 1.9 · (36 - 0) = 34 N  (worst-case)
```

But the drive power required to sustain oscillation is ~1000 W, while the available drive power is:
```
P_drive ≈ V_bus · i_A = 48 · 6 = 288 W per active coil
```

Even with perfect efficiency, the drive power is ~3× too low.

### L/R Time Constant Prevents Fast Current Reversal
At the half-cycle transition (t = 0.033 to 0.067 s):
- REPEL phase drives i_A negative (~ -3.4 A at transition)
- ATTRACT phase needs i_A positive (+6 A) to produce force in the correct direction
- L/R time constant at average L (0.1 H): τ = 100 ms
- Available drive window: 26.7 ms
- Current can only reverse ~24% of the way toward the target in the available time

Result: **The ATTRACT phase initially extracts energy from the mechanical system** (negative power: voltage is positive but current is still negative = generator mode). The oscillation is heavily damped.

### Power Balance (Numerical)
From 3.0 s simulation:
| Component | Energy | Power | Fraction |
|---|---|---|---|
| Electrical input | 136.1 J | 45.4 W | 100% |
| Copper (I²R) loss | 135.1 J | 45.0 W | 99.2% |
| Pickup recovery | 48.0 J | 16.0 W | 35.3% |
| Thrust work | -0.2 J | -0.1 W | -0.1% |

99.2% of input power is lost to I²R heating. The drive cannot overcome generator damping.

## Concept Validation
The PEAT dual-coil concept (velocity-referenced closed-loop drive with opposite coils on each side of the mass) is **theoretically sound** but **practically infeasible** with the current parameter set. The generator damping from the pickup coil extracts ~1000 W at peak velocity, while the 48 V bus and 200 mH coil inductance limit drive power to ~288 W.

## Required Parameter Changes (Any One)
| Change | Effect | Target |
|---|---|---|
| Increase bus voltage to 300 V+ | Faster current rise, higher peak current | i_A > 48 A |
| Reduce generator damping to 50 N·s/m | Lower power requirement | P_gen < 300 W |
| Reduce coil inductance to 20 mH | 10× faster current reversal | i_A reversal in < 5 ms |
| Increase stroke to 200 mm | Longer drive window | t_attract > 100 ms |
| All of the above | Feasible design | Sustained oscillation |

## Files
- `src/PeatSim.jl` — OscillatorParams, init_params (sets t_half/t_attract/t_repel/b_gen), get_drive_state (FIXED), drive_voltage, effective_L, solve_oscillator
- `scripts/thrust_measure.jl` — Parameter sweep and thrust measurement
