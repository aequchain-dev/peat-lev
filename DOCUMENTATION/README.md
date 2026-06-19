# PEAT Documentation Suite

**Version 1.1 — OPTIBEST CERTIFIED**

The complete academic and engineering documentation for the Pure Electromagnetic Asymmetric Thrust framework.

---

## Chapter Index

| # | Chapter | Description |
|---|---------|-------------|
| **01** | [Foundations & Premise](./CHAPTER_01_FOUNDATIONS/README.md) | What PEAT is, what it isn't, design philosophy, terminology, document conventions |
| **02** | [Core Physics](./CHAPTER_02_CORE_PHYSICS/README.md) | Electromagnetic theory, inductance modulation, force equations, parametric resonance |
| **03** | [System Architecture](./CHAPTER_03_SYSTEM_ARCHITECTURE/README.md) | Topology, subsystems, power bus, control hierarchy, sensor suite |
| **04** | [Oscillator Design](./CHAPTER_04_OSCILLATOR_DESIGN/README.md) | Coil parameters, drive waveform, L/R time constant, parametric pump, PLL |
| **05** | [Energy Balance & Power](./CHAPTER_05_ENERGY_BALANCE/README.md) | Power flow, generator damping, I²R losses, 800V SiC upgrade path |
| **06** | [Control & Calibration](./CHAPTER_06_CONTROL_CALIBRATION/README.md) | PID control, mixing matrix, Kalman PLL, gain scheduling, current regulation |
| **07** | [6-DOF Levitation](./CHAPTER_07_6DOF_LEVITATION/README.md) | Rigid body dynamics, lateral divergence fix, certification, scaling |
| **08** | [Use-Case Scaling](./CHAPTER_08_USE_CASE_SCALING/README.md) | Scaling laws, parameter tables, drone through hoverbus analysis |
| **09** | [Simulation Suite](./CHAPTER_09_SIMULATION_SUITE/README.md) | All three simulation codebases: usage, architecture, interpretation |
| **10** | [Verification & Validation](./CHAPTER_10_VERIFICATION_VALIDATION/README.md) | Test results, certification, cross-validation, known gaps |
| **11** | [Compliance, Licensing & Regulation](./CHAPTER_11_COMPLIANCE_LICENSING/README.md) | CC0 licensing, safety framework, regulatory landscape, EFE Filter |
| **12** | [Roadmap & Next Steps](./CHAPTER_12_ROADMAP/README.md) | Phase plans, hardware prototyping, scaling pathway |
| **13** | [Complete Reference](./CHAPTER_13_COMPLETE_REFERENCE/README.md) | Parameter tables, formula reference, file index, glossary |

---

## How to Read This Documentation

### For newcomers
Start with Chapter 1 (Foundations & Premise) to understand what PEAT is and why it matters. Then Chapter 2 (Core Physics) for the theory. Skim Chapter 3 for the big picture.

### For engineers
Chapter 4 (Oscillator Design) and Chapter 5 (Energy Balance) are essential for understanding the design constraints. Chapter 6 (Control) and Chapter 7 (6-DOF Levitation) for the control systems.

### For researchers
Chapter 2 (Core Physics) provides the theoretical foundation. Chapter 10 (Verification) and Chapter 5 (Energy Balance) document the current findings and open questions. Chapter 12 (Roadmap) shows future research directions.

### For contributors
Read Chapter 1, then go to the simulation suite (Chapter 9) and the verification results (Chapter 10). The code in `peat_sim/`, `sim/`, and `simulation/` is the primary reference.

### For investors / management
Chapter 1, Chapter 3 (architecture overview), Chapter 8 (scaling), and Chapter 12 (roadmap) give the business and technical overview.

---

## Relationship to Framework Documents

| Documentation Chapter | Related Framework Document |
|----------------------|---------------------------|
| All chapters | [PEAT_MASTER.md](../PEAT_MASTER.md) — Master framework v1.1 |
| Ch 03, 06, 07 | [FRAMEWORK/levitation_framework.md](../FRAMEWORK/levitation_framework.md) — Levitation spec v1.1 |
| Ch 09 | [SIMULATION/README.md](../SIMULATION/README.md) — Simulation suite index |

---

## Document Status

All chapters are at **Version 1.1, OPTIBEST REVIEWED**, current as of 2026-06-19.

The documentation is a living artifact — as the framework evolves through hardware prototyping and validation, chapters will be updated to reflect new findings.
