#!/usr/bin/env julia
#
# thrust_measure.jl — Full-stroke thrust measurement from ODE
#
# Measures mean thrust per oscillator from the numerical ODE
# under steady-state oscillation using the sigmoid inductance model.
#
# Key questions:
#   1. What mean thrust does each oscillator produce in steady state?
#   2. How does mean thrust compare to the analytical bound?
#   3. Can 6 oscillators hover a 115 kg vehicle?
#   4. What η_repel (drive timing) maximizes mean thrust?
#
# Usage:
#     julia --project=.. scripts/thrust_measure.jl

using PeatSim
using Printf
using Statistics: mean, std

const PI = π

# =============================================================================
# Helpers for formatting (avoid @printf issues with computed strings)
# =============================================================================
sep_line() = println("="^72)
sep_dash() = println("─"^72)

# =============================================================================
# Helpers
# =============================================================================

"""
    zero_crossings(t, x)

Find indices where x crosses zero (ascending). Returns cycle boundaries.
"""
function zero_crossings(t, x)
    crossings = Int[]
    for i in 2:length(x)
        if x[i] >= 0.0 && x[i-1] < 0.0
            push!(crossings, i)
        end
    end
    return crossings
end

"""
    mean_thrust_last_cycles(p, sol, n_cycles=5)

Compute mean thrust over the last n_cycles complete oscillation cycles.
Uses PeatSim's sigmoid inductance model (dual-coil, 4-state).

Returns (mean_thrust, std_thrust, thrust_time_series, cycle_indices)
"""
function mean_thrust_last_cycles(p, sol, n_cycles::Int=5)
    # Compute full thrust time series using PeatSim's model
    # (module state: [i_A, i_B, x, v])
    thrust = PeatSim.compute_thrust(p, sol)
    t = sol.t

    # Find zero crossings in position to identify cycle boundaries
    # (module state: [i_A, i_B, x, v] → position is state 3)
    x = [sol[3, i] for i in 1:length(t)]
    crossings = zero_crossings(t, x)

    if length(crossings) < n_cycles + 1
        @warn "Not enough cycles found ($(length(crossings))) for n_cycles=$n_cycles"
        return (NaN, NaN, thrust, crossings)
    end

    # Use the last n_cycles complete cycles
    start_idx = crossings[end - n_cycles]
    end_idx = crossings[end]

    # Trim to those cycles
    thrust_trim = thrust[start_idx:end_idx]
    t_trim = t[start_idx:end_idx]

    mean_val = mean(thrust_trim)
    std_val = std(thrust_trim)

    return (mean_val, std_val, thrust, (start_idx, end_idx))
end

"""
    compute_duty_cycle_from_ode(p, sol, n_cycles=5)

Compute actual duty cycle and timing from the ODE solution.
"""
function compute_duty_cycle_from_ode(p, sol, n_cycles::Int=5)
    t = sol.t
    # module state: [i_A, i_B, x, v, t_cross]
    v = [sol[4, i] for i in 1:length(t)]        # velocity is state 4
    positions = [sol[3, i] for i in 1:length(t)] # position is state 3
    crossings = zero_crossings(t, positions)
    if length(crossings) < n_cycles + 1
        return (NaN, NaN, NaN)
    end

    start_idx = crossings[end - n_cycles]
    end_idx = crossings[end]

    # For each of the last n_cycles, measure time fractions
    t_cycles = zero_crossings(t[start_idx:end_idx], positions[start_idx:end_idx])
    # Adjust indices back to full array
    global_idxs = [start_idx + ci - 1 for ci in t_cycles]

    # Compute fraction of time when drive is actively powering (not coasting)
    active_time = 0.0
    total_time = 0.0
    for ci in 1:(length(global_idxs)-1)
        i_start = global_idxs[ci]
        i_end = global_idxs[ci+1]
        cycle_t = t[i_end] - t[i_start]
        total_time += cycle_t

        for i in i_start:(i_end-1)
            t_cross = sol[5, i]
            state = PeatSim.get_drive_state(p, t_cross, v[i])
            if state == PeatSim.ATTRACT || state == PeatSim.REPEL
                dt = t[i+1] - t[i]
                active_time += dt
            end
        end
    end

    actual_duty = active_time / total_time
    return (actual_duty, active_time / n_cycles, total_time / n_cycles)
end

# =============================================================================
# Configuration
# =============================================================================

sep_line()
println("  PEAT — Full-Stroke Thrust Measurement")
println("  Sigmoid Inductance Model — Numerical ODE")
sep_line()
println()

# Default config for 115 kg vehicle
config = PeatSim.init_params(
    M_total=115.0,
    η_repel=0.20,
    f_osc=15.0,
    m_ratio=0.15,
    m_osc=17.25,
    V_bus=48.0,
    stroke=0.05,
    L_base=0.01,
    L_max=0.20,
    coil_length=0.05,
    R_coil=1.0,
    b_gen=0.0  # No generator damping for pure thrust measurement
)

@printf("Configuration:\n")
@printf("  Vehicle mass:        %5.1f kg\n", config.M_total)
@printf("  Vehicle weight:      %5.1f N (gravity: %.2f m/s²)\n",
        config.M_total * 9.80665, 9.80665)
@printf("  Oscillators:         6\n")
@printf("  Per oscillator:\n")
@printf("    Reaction mass:     %5.3f kg (%.1f%% ratio)\n",
        config.m_osc, config.m_ratio * 100)
@printf("    Frequency:         %5.1f Hz\n", config.f_osc)
@printf("    Stroke:            %5.1f mm\n", config.stroke * 1000)
@printf("    Bus voltage:       %5.0f V\n", config.V_bus)
@printf("    Coil resistance:   %5.3f Ω\n", config.R_coil)
@printf("    L_base:            %5.4f H\n", config.L_base)
@printf("    L_max:             %5.4f H\n", config.L_max)
@printf("    dL/dx_peak:        %5.2f H/m (at x=0)\n", config.dL_dx_peak)
@printf("    Coil length:       %5.1f mm\n", config.coil_length * 1000)
@printf("    η_repel:           %5.2f\n", config.η_repel)
@printf("\n")

# =============================================================================
# Analytical Bound
# =============================================================================

I_drive = config.V_bus / config.R_coil  # 48 A
duty = (config.t_attract + config.t_repel) / config.t_half  # 1.0 (no coast by default)
F_analytical = 0.5 * config.dL_dx_peak * I_drive^2 * duty
F_analytical_6 = F_analytical * 6
weight = config.M_total * 9.80665

@printf("Analytical Bound:\n")
@printf("  Peak current (V/R):  %5.1f A\n", I_drive)
@printf("  Duty cycle:          %5.3f\n", duty)
@printf("  F_avg per osc:       %5.0f N\n", F_analytical)
@printf("  F_total (6 osc):     %5.0f N\n", F_analytical_6)
@printf("  Vehicle weight:      %5.0f N\n", weight)
@printf("  TWR:                 %5.1f:1\n", F_analytical_6 / weight)
@printf("\n")
@printf("  NOTE: This is a lossless upper bound. L/R dynamics,\n")
@printf("  sigmoid dL/dx variation, and finite response time\n")
@printf("  will reduce mean thrust. The ODE measures the real value.\n")
@printf("\n")

# =============================================================================
# ODE Simulation — Long Enough for Steady State
# =============================================================================

duration = 3.0  # 3 seconds = 45 cycles at 15 Hz
@printf("Solving ODE for %.1f s (%.0f cycles at %.1f Hz)...\n",
        duration, duration * config.f_osc, config.f_osc)
@printf("  Solver: AutoTsit5(Rodas5P), reltol=1e-6, dtmax=1e-4\n")
@printf("\n")

flush(stdout)
t_start = time()
sol = PeatSim.solve_oscillator(config; duration=duration)
t_elapsed = time() - t_start

n_steps = length(sol.t)
n_cycles_total = duration * config.f_osc
@printf("  Solved in %.3f s (%d steps, %.0f steps/s)\n",
        t_elapsed, n_steps, n_steps / t_elapsed)
@printf("  Cycles simulated:    %.0f\n", n_cycles_total)
@printf("\n")

# =============================================================================
# Mean Thrust Measurement (last N cycles of steady state)
# =============================================================================

# Use last 10 cycles for measurement (transients should be gone by then)
n_measure_cycles = min(10, Int(floor(n_cycles_total * 0.3)))

@printf("Thrust Measurement:\n")
@printf("  Using last %d cycles of steady-state oscillation\n", n_measure_cycles)

mean_F, std_F, thrust_full, (c_start, c_end) = mean_thrust_last_cycles(config, sol, n_measure_cycles)

if isfinite(mean_F)
    # Time range of the measured window
    t_meas_start = sol.t[c_start]
    t_meas_end = sol.t[c_end]

    @printf("  Measurement window:  %.3f s to %.3f s (%.3f s)\n",
            t_meas_start, t_meas_end, t_meas_end - t_meas_start)
    @printf("\n")
    @printf("  Mean thrust/osc:     %8.1f N ± %.1f N\n", mean_F, std_F)
    @printf("  Total (6 osc):       %8.0f N\n", mean_F * 6)
    @printf("  Vehicle weight:      %8.0f N\n", weight)
    @printf("  TWR:                 %8.1f:1\n", mean_F * 6 / weight)
    @printf("\n")

    # Comparison with analytical bound
    if F_analytical > 0
        pct_of_analytical = mean_F / F_analytical * 100
        @printf("  vs Analytical bound: %.1f%% of lossless bound\n", pct_of_analytical)
    end
    @printf("\n")

    # Hover assessment
    if mean_F * 6 >= weight
        margin = (mean_F * 6 - weight) / weight * 100
        @printf("  ✓ HOVER FEASIBLE (margin: %.1f%%)\n", margin)
    else
        pct_hover = mean_F * 6 / weight * 100
        @printf("  ✗ HOVER NOT FEASIBLE (%.1f%% of required thrust)\n", pct_hover)
        @printf("    Need %.0f N, have %.0f N. Shortfall: %.0f N\n",
                weight, mean_F * 6, weight - mean_F * 6)
        @printf("    Required oscillators: %.1f\n", weight / mean_F)
    end
    @printf("\n")
else
    @printf("  ✗ Could not measure — insufficient cycles\n\n")
end

# =============================================================================
# Detailed Cycle Analysis
# =============================================================================

@printf("Cycle Analysis (last 3 cycles):\n")

# Get the last 3 complete cycle boundaries
x_all = [sol[3, i] for i in 1:length(sol.t)]
crossings = zero_crossings(sol.t, x_all)
n_lookback = min(3, length(crossings) - 1)

for ci in (length(crossings)-n_lookback):(length(crossings)-1)
    i1 = crossings[ci]
    i2 = crossings[ci+1]
    t1 = sol.t[i1]; t2 = sol.t[i2]

    # Max/min in this cycle (module state: [i_A, i_B, x, v])
    x_cycle = [sol[3, i] for i in i1:i2]     # position is state 3
    v_cycle = [sol[4, i] for i in i1:i2]     # velocity is state 4
    iA_cycle = [sol[1, i] for i in i1:i2]    # coil A current is state 1
    iB_cycle = [sol[2, i] for i in i1:i2]    # coil B current is state 2
    thrust_cycle = thrust_full[i1:i2]

    # Mean thrust over this cycle
    dt_vals = diff(sol.t[i1:i2])
    thrust_integral = sum(thrust_cycle[1:end-1] .* dt_vals)
    cycle_time = t2 - t1
    cycle_mean = cycle_time > 0 ? thrust_integral / cycle_time : 0.0

    @printf("  Cycle %.0f:  t=[%.3f, %.3f]  T=%.4fs  peak_x=%.1fmm  peak_v=%.1fm/s  peak_iA=%.1fA  peak_iB=%.1fA  F_mean=%.1fN\n",
            ci, t1, t2, cycle_time,
            maximum(abs.(x_cycle)) * 1000,
            maximum(abs.(v_cycle)),
            maximum(abs.(iA_cycle)),
            maximum(abs.(iB_cycle)),
            cycle_mean)
end
@printf("\n")

# =============================================================================
# Time-Domain Summary
# =============================================================================

@printf("Time-Domain Summary:\n")
@printf("  Position range:      [%.1f, %.1f] mm\n",
        minimum([sol[3, i] * 1000 for i in 1:length(sol.t)]),
        maximum([sol[3, i] * 1000 for i in 1:length(sol.t)]))
@printf("  Velocity range:      [%.1f, %.1f] m/s\n",
        minimum([sol[4, i] for i in 1:length(sol.t)]),
        maximum([sol[4, i] for i in 1:length(sol.t)]))
@printf("  Coil A current:      [%.1f, %.1f] A\n",
        minimum([sol[1, i] for i in 1:length(sol.t)]),
        maximum([sol[1, i] for i in 1:length(sol.t)]))
@printf("  Coil B current:      [%.1f, %.1f] A\n",
        minimum([sol[2, i] for i in 1:length(sol.t)]),
        maximum([sol[2, i] for i in 1:length(sol.t)]))
@printf("\n")

# =============================================================================
# Power Balance
# =============================================================================

@printf("Power Balance (%.3f s):\n", duration)
balance = PeatSim.compute_power_balance(config, sol)

@printf("  Electrical input:     %10.1f J (%8.1f W)\n",
        balance.E_pump, balance.P_pump)
@printf("  Copper (I²R) loss:    %10.1f J (%8.1f W)  [%.1f%%]\n",
        balance.E_copper, balance.P_copper,
        100 * balance.E_copper / max(balance.E_pump, 1e-6))
@printf("  Thrust work:          %10.1f J (%8.1f W)  [%.1f%%]\n",
        balance.E_thrust, balance.P_thrust,
        100 * balance.E_thrust / max(balance.E_pump, 1e-6))
@printf("  Pickup recovery:      %10.1f J (%8.1f W)  [%.1f%%]\n",
        balance.E_pickup, balance.P_pickup,
        100 * balance.E_pickup / max(balance.E_pump, 1e-6))
@printf("  Efficiency:           %5.1f%%\n", balance.efficiency)
@printf("  Energy closure:       %5.3f%%\n", balance.closure_pct)
@printf("\n")

# =============================================================================
# η_repel Sweep — Find Optimal Drive Timing
# =============================================================================

sep_line()
println("  η_repel Sweep — Finding Optimal Drive Timing")
sep_line()
println()

eta_values = collect(0.05:0.025:0.50)
@printf("Sweeping η_repel from %.2f to %.2f (%d values)\n",
        first(eta_values), last(eta_values), length(eta_values))

results_eta = []
t_start_sweep = time()

for (i, η) in enumerate(eta_values)
    p = PeatSim.init_params(
        M_total=115.0,
        η_repel=η,
        f_osc=15.0,
        m_ratio=0.15,
        m_osc=17.25,
        V_bus=48.0,
        stroke=0.05,
        L_base=0.01,
        L_max=0.20,
        coil_length=0.05,
        R_coil=1.0,
        b_gen=0.0
    )

    # Analytical thrust for comparison
    F_anal = PeatSim.analytical_thrust(p)

    # Shorter ODE for sweeps — 1.5 s should be enough for steady state
    sol_sweep = PeatSim.solve_oscillator(p; duration=2.0)
    mean_F, std_F, _, _ = mean_thrust_last_cycles(p, sol_sweep, 8)

    push!(results_eta, (
        η=η,
        F_analytical=F_anal,
        F_ode_mean=mean_F,
        F_ode_std=std_F,
        ratio=mean_F / max(F_anal, 1e-12),
        F_total_6=mean_F * 6,
        hover_possible=mean_F * 6 >= 115 * 9.80665,
        margin=mean_F * 6 > 0 ? (mean_F * 6 - 115 * 9.80665) / (115 * 9.80665) * 100 : -100,
        n_steps=length(sol_sweep.t)
    ))

    if i % 5 == 0 || i == length(eta_values)
        elapsed = time() - t_start_sweep
        @printf("  [%2d/%2d] η=%.3f → F_ode=%.1f N  (%.1f s elapsed)\n",
                i, length(eta_values), η, mean_F, elapsed)
        flush(stdout)
    end
end

t_sweep = time() - t_start_sweep
@printf("  Sweep completed in %.3f s\n\n", t_sweep)

# Print sweep table
@printf("\n%-8s %-12s %-12s %-10s %-10s %-10s\n",
        "η", "F_anal[N]", "F_ode[N]", "Ratio[%]", "F_total[N]", "Hover?")
@printf("%-8s %-12s %-12s %-10s %-10s %-10s\n",
        "─"^6, "─"^10, "─"^10, "─"^8, "─"^8, "─"^8)

best_η = nothing
best_F = -Inf
best_margin = -Inf

for r in results_eta
    hover_str = r.hover_possible ? "✓" : "✗"
    @printf("%-8.3f %-12.1f %-12.1f %-10.1f %-10.0f %-10s\n",
            r.η, r.F_analytical, r.F_ode_mean,
            r.ratio * 100, r.F_total_6, hover_str)

    if r.F_ode_mean > best_F
        global best_F = r.F_ode_mean
        global best_η = r.η
        global best_margin = r.margin
    end
    if r.margin > best_margin
        global best_margin = r.margin
    end
end

@printf("\n")
@printf("Optimal η_repel:       %.3f (mean thrust = %.1f N/osc)\n", best_η, best_F)
@printf("Best hover margin:     %.1f%%\n", best_margin)

# Find first η where hover becomes feasible
feasible_etas = [r for r in results_eta if r.hover_possible]
if !isempty(feasible_etas)
    first_feasible = minimum([r.η for r in feasible_etas])
    @printf("Hover feasible at:     η ≥ %.3f\n", first_feasible)
else
    @printf("Hover NOT feasible at any η (0.05–0.50) with these parameters\n")
end

println()
sep_line()
println("  Measurement complete.")
sep_line()
println()
