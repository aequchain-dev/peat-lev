# PEAT Simulation Suite

This directory provides a unified navigation index for all three simulation codebases.
**No files have been moved or deleted** — the original directories remain in place
at the repository root with their full contents.

---

## Simulation Tracks

```
SIMULATION/
├── README.md            ← This file (navigation index)
│
├── peat_sim/            ───→ ../../peat_sim/    [Julia — Primary Single-Oscillator ODE]
│   ├── src/PeatSim.jl        2,404-line coupled ODE with adaptive timing
│   ├── scripts/              5 analysis scripts
│   ├── test/                 71 tests (all passing)
│   ├── SUMMARY.md            Feasibility sweep results
│   └── docs/ROOT_CAUSE_NOTE.md  Power insufficiency analysis
│
├── sim/                 ───→ ../../sim/          [Julia — Calibrated Levitation Framework]
│   ├── src/LevitationSim.jl  1-DOF PM-biased hover (Phase 1)
│   ├── src/Levitation6D.jl   6-DOF with lateral divergence fix (Phase 2)
│   ├── scripts/              Phase 1 & 2 run scripts
│   └── docs/                 Certification documentation
│
└── simulation/          ───→ ../../simulation/   [Python — Analytical Sweeps]
    ├── peat_sim_v2.py        Analytical model v2 (calibrated losses)
    ├── peat_sim.py           Original analytical model
    ├── calibration_controller.py  Kalman PLL + gain scheduling
    └── verify_peat.py        Cross-check verification
```

---

## Track Comparison

| Aspect | **peat_sim/** (Julia) | **sim/** (Julia) | **simulation/** (Python) |
|--------|----------------------|------------------|--------------------------|
| **Purpose** | Single-oscillator feasibility | Full levitation framework | Analytical sweeps |
| **DOF** | 1 (oscillator pair) | 6 (full rigid body) | 1 → 6 (model) |
| **Drive** | Asymmetric push-pull | PWM current + PM bias | Analytical parametric |
| **Control** | Velocity-referenced | PID per axis | PLL + gain schedule |
| **Generator** | Pickup coil (b_gen) | AFPM model | Analytical power balance |
| **Tests** | 71 (all pass) | — | — |
| **Status** | Active development | Certified (Phase 2) | Calibration reference |

---

## Quick Start by Track

```bash
# Track A — Single-oscillator feasibility sweep
cd peat_sim && julia --project=. scripts/sweep.jl

# Track B — 6-DOF levitation demo
cd sim && julia --project=. -e 'include("scripts/phase2_6dof.jl")'

# Track C — Analytical verification
cd simulation && python3 verify_peat.py
```

---

## Key Findings

| Finding | Track | Status |
|---------|-------|--------|
| 48V single-oscillator not self-sustaining | peat_sim | Confirmed (ΔE = -2.3 J/cycle best) |
| 800V SiC required for sustained oscillation | peat_sim | Recommended upgrade |
| 6-DOF lateral divergence fixed | sim | Certified (0.52 mm RMS) |
| Self-powering viable at 6-DOF | sim | 2.17 W average |
| Analytical model cross-validated | simulation | 3 scales verified |
