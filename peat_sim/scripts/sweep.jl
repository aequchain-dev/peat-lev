#!/usr/bin/env julia
#
# sweep.jl — PEAT parameter sweep runner
#
# Runs the analytical parameter sweeps and reports feasible
# configurations across mass classes, frequencies, and ratios.
#
# Usage:
#     julia --project=.. scripts/sweep.jl                          # Full sweep
#     julia --project=.. scripts/sweep.jl --fast                   # Quick subset
#     julia --project=.. scripts/sweep.jl --threads                 # Multi-threaded

using PeatSim

fast_sweep = "--fast" in ARGS
use_threads = "--threads" in ARGS

println("="^72)
println("  PEAT — Parametric Electro-Active Thruster")
println("  Parameter Sweep")
println("="^72)
println()

if fast_sweep
    println("Mode: Fast (subset)")
    masses = [115.0, 1200.0, 5000.0]
    etas = collect(0.05:0.05:0.30)
    freqs = [7.5, 10.0, 15.0, 25.0]
    ratios = [0.03, 0.05, 0.10, 0.15]
else
    println("Mode: Full sweep")
    masses = [5.0, 50.0, 115.0, 250.0, 1200.0, 5000.0]
    etas = collect(0.05:0.025:0.50)
    freqs = vcat(collect(7.5:2.5:25.0), [35.0, 47.5])
    ratios = collect(0.01:0.003:0.175)
end

println("Mass classes:     $(masses)")
println("η (repel):        $(length(etas)) values ($(first(etas))–$(last(etas)))")
println("Frequencies:      $(length(freqs)) values ($(first(freqs))–$(last(freqs)) Hz)")
println("Mass ratios:      $(length(ratios)) values ($(first(ratios))–$(last(ratios)))")

total = length(masses) * length(etas) * length(freqs) * length(ratios)
println("Total configs:    $total")
println()

# Run sweep
println("Running sweep...")
t_start = time()

if use_threads
    results = PeatSim.run_sweep_parallel(masses, etas, freqs, ratios)
else
    results = PeatSim.run_sweep(masses, etas, freqs, ratios)
end

t_elapsed = time() - t_start
println("  Completed in $(round(t_elapsed, digits=3)) s ($(round(total/t_elapsed, digits=0)) configs/s)")
println()

# Summarize
PeatSim.summarize_results(results)
println()

# Best overall
feasible = filter(r -> r.feasible, results)
if !isempty(feasible)
    best = argmax(r -> r.margin, feasible)
    println("Overall best configuration:")
    println("  Mass: $(best.config.M_total) kg  η: $(best.config.η)  f: $(best.config.f) Hz  ratio: $(best.config.m_ratio)")
    println("  Margin: $(round(best.margin, digits=1))%  F_thrust: $(round(best.F_thrust, digits=1)) N  P_net: $(round(best.P_net, digits=1)) W")
end

println()
println("="^72)
println("  Sweep complete.")
println("="^72)
