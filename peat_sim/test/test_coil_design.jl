#!/usr/bin/env julia
# PEAT-6o1: Coil geometry design sweep
# Find winding geometry achieving R_coil ≈ 0.5Ω, L_max ≈ 20mH
# Run: julia --project=.. test/test_coil_design.jl

using PeatSim
using Printf

println("=" ^ 72)
println("PEAT-6o1: Coil Geometry Design Sweep")
println("Target: R_coil ≈ 0.5Ω, L_max ≈ 20mH, L_base ≈ 0.5mH")
println("=" ^ 72)

# Sweep parameters
turns_range   = 50:5:150
radius_range  = [0.03, 0.04, 0.05, 0.06, 0.075, 0.10]
wire_range    = [1.0, 1.5, 2.0, 2.5, 3.0]  # mm diameter
winding_len   = 0.05   # fixed: axial length [m]
winding_build = 0.015  # fixed: radial build [m]
μ_eff         = 40.0   # iron slug effective permeability
fill_factor   = 0.55   # copper packing

println("Sweep: $(length(turns_range)) turns × $(length(radius_range)) radii × $(length(wire_range)) wire sizes")
println()

results = []

for radius in radius_range
    for n_turns in turns_range
        for wire_diam in wire_range
            geom = CoilDesign(
                n_turns=n_turns,
                wire_diameter_mm=wire_diam,
                mean_radius_m=radius,
                winding_length_m=winding_len,
                winding_build_m=winding_build,
                μ_slug_effective=μ_eff,
                fill_factor=fill_factor
            )
            cp = PeatSim.coil_params(geom)
            
            # Check if it fits our target
            if 0.3 <= cp.R_coil <= 1.0 && 0.010 <= cp.L_max <= 0.050
                push!(results, (
                    n=n_turns, r=radius, w=wire_diam, 
                    R=cp.R_coil, L_base=cp.L_base, L_max=cp.L_max))
            end
        end
    end
end

# Sort by proximity to target (0.5Ω, 20mH)
sort!(results, by=r -> abs(r.R - 0.5) + abs(r.L_max - 0.02))

println("Top 15 candidates (sorted by proximity to R=0.5Ω, L_max=20mH):")
println("-" ^ 72)
println("  #  turns  radius  wire_d  R_coil   L_base   L_max    R/L_ratio")
println("  " ^ 72)
for (i, r) in enumerate(results[1:min(15, end)])
    τ_slug = (r.L_base + r.L_max) / 2.0 / r.R
    @printf("  %2d  %3d    %4dmm   %3.1fmm  %5.3fΩ  %5.1fmH  %5.1fmH   τ=%.0fms\n",
        i, r.n, round(Int, r.r*1000), r.w, r.R, r.L_base*1000, r.L_max*1000, τ_slug*1000)
end

println()
println("─" ^ 72)
println("BEST CANDIDATES")
println("─" ^ 72)

# Select and present the best design point
best = results[1]
@printf("  Geometry:  N=%d turns, mean_radius=%.0fmm, wire=%.1fmm\n",
    best.n, best.r*1000, best.w)
@printf("  Electrical: R_coil=%.3fΩ, L_base=%.1fmH, L_max=%.1fmH\n",
    best.R, best.L_base*1000, best.L_max*1000)

# Full simulation with this coil
println("\nRunning full ODE with optimized coil + SiC bus...")
geom = CoilDesign(
    n_turns=best.n, wire_diameter_mm=best.w,
    mean_radius_m=best.r, winding_length_m=winding_len,
    winding_build_m=winding_build, μ_slug_effective=μ_eff,
    fill_factor=fill_factor
)

# Test at several bus voltages
for V in [150, 300, 600, 800]
    # Low damping params (redesigned pickup, small)
    p = PeatSim.init_params(
        coil_geom=geom,
        M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=Float64(V),
        stroke=0.20, coil_length=0.05,
        N_pickup=20, B_pickup=0.1, A_pickup=0.003, d_rest=0.02, R_load=100.0
    )
    
    sol = PeatSim.solve_oscillator(p; duration=1.0, reltol=1e-6)
    x = [u[3] for u in sol.u]
    t = sol.t
    
    # Final amplitude
    idx_last = findall(ti -> ti >= t[end] - 0.1, t)
    amp = maximum(abs.(x[idx_last])) * 1000  # mm
    init_amp = maximum(abs.(x[1:100])) * 1000  # mm
    
    # Power balance
    bal = PeatSim.compute_power_balance(p, sol)
    
    @printf("  %3dV: amp=%.0fmm (init=%.0fmm), η=%.1f%%, P_pump=%.1fkW, P_thrust=%.1fW\n",
        V, amp, init_amp, bal.efficiency*100, bal.E_pump/t[end]/1000, abs(bal.E_thrust)/t[end])
end

# ── Efficiency analysis at multiple operating points ──────────────────────────
println("\n" ^ 2)
println("─" ^ 72)
println("EFFICIENCY ANALYSIS — 600V bus, various load resistances")
println("─" ^ 72)

for R_load in [10, 50, 100, 200, 500]
    p = PeatSim.init_params(
        coil_geom=geom,
        M_total=115.0, f_osc=15.0, η_repel=0.20,
        V_bus=600.0,
        stroke=0.20, coil_length=winding_len,
        N_pickup=20, B_pickup=0.1, A_pickup=0.003, d_rest=0.02, R_load=Float64(R_load)
    )
    
    sol = PeatSim.solve_oscillator(p; duration=1.0, reltol=1e-6)
    x = [u[3] for u in sol.u]
    idx_last = findall(ti -> ti >= t[end] - 0.1, t)
    amp = maximum(abs.(x[idx_last])) * 1000
    bal = PeatSim.compute_power_balance(p, sol)
    
    @printf("  R_load=%4dΩ: amp=%.0fmm, b_gen=%.1f N·s/m, η=%.2f%%, thrust=%.0fW\n",
        R_load, amp, p.b_gen, bal.efficiency*100, abs(bal.E_thrust)/t[end])
end

println("\nDone.")
