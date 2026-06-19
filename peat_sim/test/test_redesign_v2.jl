#!/usr/bin/env julia
# Verify: track amplitude progression over full simulation
# Run: julia --project=.. test/test_redesign_v2.jl

using PeatSim
using Statistics

println("=" ^ 72)
println("PEAT-ik8: Amplitude Progression Verification")
println("=" ^ 72)

function amplitude_over_time(x, t, n_cycles, f_osc)
    """Track peak amplitude per cycle over full simulation."""
    t_cycle = 1.0 / f_osc
    n_total = floor(Int, t[end] / t_cycle)
    amplitudes = Float64[]
    times = Float64[]
    for i in 1:n_total
        t_start = (i-1) * t_cycle
        t_end   = i * t_cycle
        idx = findall(ti -> t_start <= ti < t_end, t)
        if length(idx) > 2
            push!(amplitudes, maximum(abs.(x[idx])))
            push!(times, (t_start + t_end) / 2)
        end
    end
    return times, amplitudes
end

# Parameter sets
sets = [
    ("BASELINE", PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=48.0, R_coil=1.0, L_max=0.20, L_base=0.01,
        stroke=0.05, coil_length=0.05,
        N_pickup=100, B_pickup=0.5, A_pickup=0.01, d_rest=0.01, R_load=10.0)),
    ("Set C (150V)", PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=150.0, R_coil=1.0, L_max=0.08, L_base=0.01,
        stroke=0.10, coil_length=0.05,
        N_pickup=100, B_pickup=0.3, A_pickup=0.008, d_rest=0.015, R_load=20.0)),
    ("Set B (300V)", PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=300.0, R_coil=0.8, L_max=0.05, L_base=0.01,
        stroke=0.15, coil_length=0.05,
        N_pickup=100, B_pickup=0.2, A_pickup=0.008, d_rest=0.015, R_load=30.0)),
    ("Set A (600V)", PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=600.0, R_coil=0.5, L_max=0.02, L_base=0.005,
        stroke=0.20, coil_length=0.05,
        N_pickup=100, B_pickup=0.1, A_pickup=0.005, d_rest=0.02, R_load=50.0)),
]

for (label, p) in sets
    println("\n" ^ 2)
    println("─" ^ 72)
    println("▶ $label")
    println("─" ^ 72)
    
    sol = PeatSim.solve_oscillator(p; duration=2.0, reltol=1e-6)
    x = [u[3] for u in sol.u]
    t = sol.t
    
    times, amps = amplitude_over_time(x, t, 30, p.f_osc)
    
    if length(amps) >= 4
        # First few cycles
        amp_start = mean(amps[1:min(3, end)])
        # Last few cycles
        amp_end   = mean(amps[max(1, end-2):end])
        ratio = amp_end / amp_start
        
        println("  Initial amplitude: $(round(amp_start*1000, digits=2)) mm")
        println("  Final amplitude:   $(round(amp_end*1000, digits=2)) mm")
        println("  Growth ratio:      $(round(ratio, digits=3))")
        
        if ratio < 0.8
            println("  ❌ DECAYING — oscillation loses energy (ratio=$ratio)")
        elseif ratio < 1.05
            println("  ✅ SUSTAINED — amplitude stable near $(round(amp_end*1000, digits=1)) mm")
        else
            println("  ⚡ GROWING — amplitude increasing (ratio=$ratio)")
        end
        
        # Print progression
        n_print = min(length(amps), 30)
        step = max(1, n_print ÷ 10)
        println("\n  Amplitude progression (first $n_print cycles):")
        for i in 1:step:n_print
            bar = "█" ^ round(Int, amps[i] * 500)
            println("  cycle $(rpad(string(i), 3)): $(rpad(string(round(amps[i]*1000, digits=1)), 7)) mm  $bar")
        end
    else
        println("  Not enough data")
    end
end

println("\n\nDone.")
