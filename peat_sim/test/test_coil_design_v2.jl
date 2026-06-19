#!/usr/bin/env julia
# PEAT-6o1: Coil geometry design — exploratory sweep
# Run: julia --project=.. test/test_coil_design_v2.jl

using PeatSim
using Printf

println("=" ^ 72)
println("PEAT-6o1: Coil Geometry — Exploratory Sweep")
println("=" ^ 72)

# Fixed parameters
μ_eff = 40.0
fill  = 0.55
wlen  = 0.05     # winding length [m]
wbuild = 0.015   # winding build [m]

# Wide sweep: find ANY geometry that gets near our targets
for radius in [0.03, 0.05, 0.075, 0.10]
    println("\n── Mean radius = $(Int(radius*1000))mm ──")
    for n_turns in [20, 30, 50, 75, 100, 150, 200, 300, 500]
        geom = CoilDesign(n_turns=n_turns, wire_diameter_mm=2.0,
            mean_radius_m=radius, winding_length_m=wlen,
            winding_build_m=wbuild, μ_slug_effective=μ_eff, fill_factor=fill)
        cp = PeatSim.coil_params(geom)
        if cp.L_max < 0.1 && cp.R_coil <= 5.0
            @printf("  N=%-3d  R=%.4fΩ  L_base=%.4fH  L_max=%.4fH  L_air=%.4fH\n",
                n_turns, cp.R_coil, cp.L_base, cp.L_max, cp.L_base)
        end
    end
end

# Now try with larger μ_slug_effective to boost L_max
println("\n" ^ 2)
println("── Trying μ_eff variation (N=150, r=50mm, wire=2.0mm) ──")
for μ in [10, 20, 40, 80, 100]
    geom = CoilDesign(n_turns=150, wire_diameter_mm=2.0,
        mean_radius_m=0.05, winding_length_m=wlen,
        winding_build_m=wbuild, μ_slug_effective=μ, fill_factor=fill)
    cp = PeatSim.coil_params(geom)
    @printf("  μ_eff=%-3d  R=%.4fΩ  L_base=%.4fH  L_max=%.4fH\n",
        μ, cp.R_coil, cp.L_base, cp.L_max)
end

# Maybe we need a larger coil
println("\n" ^ 2)
println("── Larger coils (r=100mm, wire=2.0mm, μ=40) ──")
for n_turns in [50, 100, 200, 300, 500]
    geom = CoilDesign(n_turns=n_turns, wire_diameter_mm=2.0,
        mean_radius_m=0.10, winding_length_m=wlen,
        winding_build_m=wbuild, μ_slug_effective=40, fill_factor=fill)
    cp = PeatSim.coil_params(geom)
    @printf("  N=%-4d  R=%.4fΩ  L_base=%.4fH  L_max=%.4fH\n",
        n_turns, cp.R_coil, cp.L_base, cp.L_max)
end

# And smaller coils
println("\n" ^ 2)
println("── Small coils (r=20mm, wire=1.5mm, μ=40) ──")
for n_turns in [20, 30, 50, 75, 100]
    geom = CoilDesign(n_turns=n_turns, wire_diameter_mm=1.5,
        mean_radius_m=0.02, winding_length_m=wlen,
        winding_build_m=wbuild, μ_slug_effective=40, fill_factor=fill)
    cp = PeatSim.coil_params(geom)
    @printf("  N=%-3d  R=%.4fΩ  L_base=%.6fH  L_max=%.6fH\n",
        n_turns, cp.R_coil, cp.L_base, cp.L_max)
end

println("\nDone.")
