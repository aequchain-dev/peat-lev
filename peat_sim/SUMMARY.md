# PeatSim — Self-Sustaining Single-Oscillator Feasibility Study

## Goal
Find self-sustaining single-oscillator parameter regimes via ODE simulation sweep.

## Constraints & Preferences
- 6×6×6 = 216 combinations of Vbus, Lmax, Rload; all other parameters fixed (m_osc=115/6, Rcoil=1, B_pickup=0.5, η=0.2, f=15Hz)
- Simulation runs 6 cycles with AutoTsit5(Rodas5P) solver

## Progress
### Done
- Debugged and fixed `B=B` → `B_pickup=B` keyword bug in `init_params` calls (two locations)
- Fixed drive state machine timer bug: `mod(t, 2*p.t_half)` → `mod(t, p.t_half)`
- Updated velocity-based control logic, documentation, and all tests
- Ran 216-case sweep with corrected timer: **best ΔE = -2.3 J/cycle** (was -5.3), but **still zero feasible regimes out of 150 completed simulations** (66 ODE failures)
- Discovered **bug in `compute_power_balance()`** (line 417): calls `get_drive_state(p, t[i], x)` — passes *position* instead of *velocity*, making the power-balance reconstruction wrong. Does not affect sweep ΔE (which uses mechanical energy at turning points).
- **Implemented adaptive drive timing** via 5-state ODE with a `ContinuousCallback` that resets a phase variable `u[5] = t_cross` at every actual velocity zero-crossing, replacing the fixed `mod(t, t_half)` clock
- Fixed `compute_power_balance` to pass `v` and use `sol[5, i]` for `t_cross`
- Updated `thrust_measure.jl` to use callback-tracked `t_cross` from `sol[5, i]`
- Cleaned up unused `t_mod` variable from `drive_voltage`
- All 41 tests pass

### In Progress
- (none — adaptive timing implementation complete)

### Blocked
- (none)

## Key Decisions
- **Keep velocity-referenced control** (v>0 → ATTRACT, v≤0 → REPEL) — position-referenced was rejected because it applies wrong force direction during the downstroke below center
- **Replace fixed timer with adaptive phase tracking** — `mod(t, t_half)` assumes the oscillation follows the design frequency exactly, but the drive changes the effective dynamics; a callback-reset phase variable tracks the *actual* oscillation for correct drive window alignment
- **ContinuousCallback approach**: add `u[5] = t_cross` (time since last v=0 crossing, `du[5]/dt = 1.0`), with a `ContinuousCallback` that detects `v = u[4] = 0` and resets `u[5] = 0`

## Next Steps
- Re-run the feasibility sweep with adaptive timing to see if ΔE improves
- If still negative ΔE, investigate: coil time constant τ = L/R (200ms) vs half-cycle (33ms), higher η_repel, lower frequency, or geometry changes

## Critical Context
- Timer-based drive (`mod(t, t_half)`) fundamental issue: the ODE's actual velocity zero-crossings drift relative to the fixed clock because the drive changes the oscillation period. The drive windows fire at suboptimal phases, wasting energy.
- Best ΔE improved from -5.3 → -2.3 J/cycle after fixing the full-cycle-timer bug (upstroke now gets ATTRACT drive), but still not positive
- Initial mechanical energy = 53.2 J; all feasible sweeps lose net energy per cycle
- 66 of 216 simulations failed (ODE solve issues), 0 of 150 completed ones were feasible
- Coil time constant τ = L_max / R_coil = 200ms, much longer than the half-cycle (33ms) — current can only change ~15% before voltage reverses, fundamentally limiting energy injection

## Relevant Files
- `src/PeatSim.jl:211` — `get_drive_state()` — now receives `t_cross` directly (no `mod(t, t_half)`)
- `src/PeatSim.jl:283-303` — `coupled_oscillator!()` — expanded to 5-state with `u[5] = t_cross`
- `src/PeatSim.jl:417` — `compute_power_balance()` — fixed: now passes `v` and uses `sol[5, i]`
- `src/PeatSim.jl:483-497` — `solve_oscillator()` — uses callback and 5-state u₀
- `test/runtests.jl` — 41 tests pass
- `scripts/thrust_measure.jl:119` — uses `sol[5, i]` for t_cross
