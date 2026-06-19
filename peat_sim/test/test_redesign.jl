#!/usr/bin/env julia
# Test redesigned parameter set for sustained oscillation (PEAT-ik8)
# Run: julia --project=.. test/test_redesign.jl

using PeatSim
using DifferentialEquations
using Statistics

println("=" ^ 72)
println("PEAT-ik8: Redesigned Parameter Sweep — Sustained Oscillation Test")
println("=" ^ 72)

# ── Baseline (known to fail) ──────────────────────────────────────────────────
p_baseline = PeatSim.init_params(
    M_total=115.0, f_osc=15.0, η_repel=0.20,
    V_bus=48.0, R_coil=1.0, L_max=0.20, L_base=0.01,
    stroke=0.05, coil_length=0.05,
    N_pickup=100, B_pickup=0.5, A_pickup=0.01, d_rest=0.01, R_load=10.0
)

# ── Redesigned candidate sets ─────────────────────────────────────────────────
# Set A: aggressive redesign — full SiC 600V, low-L coil, reduced damping
p_A = PeatSim.init_params(
    M_total=115.0, f_osc=15.0, η_repel=0.20,
    V_bus=600.0, R_coil=0.5, L_max=0.020, L_base=0.005,
    stroke=0.20, coil_length=0.05,
    N_pickup=100,  B_pickup=0.1, A_pickup=0.005, d_rest=0.02, R_load=50.0
)

# Set B: moderate — 300V bus, moderate coil improvement
p_B = PeatSim.init_params(
    M_total=115.0, f_osc=15.0, η_repel=0.20,
    V_bus=300.0, R_coil=0.8, L_max=0.050, L_base=0.010,
    stroke=0.15, coil_length=0.05,
    N_pickup=100, B_pickup=0.2, A_pickup=0.008, d_rest=0.015, R_load=30.0
)

# Set C: conservative — 150V bus, incremental improvements
p_C = PeatSim.init_params(
    M_total=115.0, f_osc=15.0, η_repel=0.20,
    V_bus=150.0, R_coil=1.0, L_max=0.080, L_base=0.010,
    stroke=0.10, coil_length=0.05,
    N_pickup=100, B_pickup=0.3, A_pickup=0.008, d_rest=0.015, R_load=20.0
)

# Set D: 800V — full SiC spec (same config as A but 800V)
p_D = PeatSim.init_params(
    M_total=115.0, f_osc=15.0, η_repel=0.20,
    V_bus=800.0, R_coil=0.5, L_max=0.020, L_base=0.005,
    stroke=0.20, coil_length=0.05,
    N_pickup=100, B_pickup=0.1, A_pickup=0.005, d_rest=0.02, R_load=50.0
)

paramsets = [
    ("BASELINE (48V, 200mH, 1Ω, 50mm)", p_baseline),
    ("Set C: 150V, 80mH, 1Ω, 100mm",    p_C),
    ("Set B: 300V, 50mH, 0.8Ω, 150mm",  p_B),
    ("Set A: 600V, 20mH, 0.5Ω, 200mm",  p_A),
    ("Set D: 800V, 20mH, 0.5Ω, 200mm",  p_D),
]

function analyze_oscillation(sol, p, label)
    # Extract states
    i_A = [u[1] for u in sol.u]
    i_B = [u[2] for u in sol.u]
    x   = [u[3] for u in sol.u]
    v   = [u[4] for u in sol.u]
    t   = sol.t

    # Find last cycles (last 25% of time)
    t_start = t[end] * 0.75
    idx_last = findall(ti -> ti >= t_start, t)
    if length(idx_last) < 10
        return (decaying=true, final_amplitude=0.0, avg_abs_x=0.0, avg_abs_v=0.0, max_x=0.0)
    end
    x_last = x[idx_last]
    v_last = v[idx_last]

    # Peak-to-peak amplitude in last segment
    avg_abs_x = mean(abs.(x_last))
    max_x = maximum(abs.(x_last))
    avg_abs_v = mean(abs.(v_last))

    # Energy analysis — last 3 cycles
    if length(t) > 500
        idx3 = findall(ti -> ti >= t[end] - 3.0 / p.f_osc, t)
        x3 = x[idx3]
        # Check if amplitude is decaying in last 3 cycles
        n_third = length(idx3) ÷ 3
        if n_third >= 2
            amp_1 = maximum(abs.(x3[1:n_third]))
            amp_3 = maximum(abs.(x3[end-n_third+1:end]))
            decaying = amp_3 < amp_1 * 0.95  # 5% decay threshold
        else
            decaying = true
        end
    else
        decaying = true
    end

    return (decaying=decaying, final_amplitude=max_x, avg_abs_x=avg_abs_x,
            avg_abs_v=avg_abs_v, max_x=max_x)
end

results = []

for (label, p) in paramsets
    println("\n" ^ 2)
    println("─" ^ 72)
    println("▶ $label")
    println("─" ^ 72)

    # Print key params
    τ = (p.L_base + p.L_max) / 2.0 / p.R_coil
    τ_half = p.t_half
    θ = τ_half / τ
    println("  τ (L/R)    = $(round(τ*1000, digits=1)) ms")
    println("  t_half     = $(round(τ_half*1000, digits=1)) ms")
    println("  τ/τ_half   = $(round(θ, digits=2))  (need > ~0.5)")
    println("  dL/dx_peak = $(round(p.dL_dx_peak, digits=3)) H/m")
    println("  b_gen      = $(round(p.b_gen, digits=1)) N·s/m")
    println("  I_ss       = $(round(p.V_bus / p.R_coil, digits=0)) A")
    println("  stroke     = $(round(p.stroke*1000, digits=0)) mm")
    println("  x₀         = $(round(p.x₀*1000, digits=1)) mm")

    # Analytical thrust prediction
    F_thrust = PeatSim.analytical_thrust(p)
    println("  F_thrust(analytical) = $(round(F_thrust, digits=0)) N")

    # Numerical ODE
    sol = PeatSim.solve_oscillator(p; duration=2.0, reltol=1e-6)
    n_steps = length(sol.t)
    retcode = sol.retcode
    println("  ODE steps  = $n_steps")
    println("  retcode    = $retcode")

    r = analyze_oscillation(sol, p, label)
    push!(results, (label=label, result=r, sol=sol, params=p))

    if r.decaying
        println("  ❌ DECAYING  — final |x|_avg = $(round(r.avg_abs_x*1000, digits=2)) mm, max |x| = $(round(r.max_x*1000, digits=2)) mm")
    else
        println("  ✅ SUSTAINED — final |x|_avg = $(round(r.avg_abs_x*1000, digits=2)) mm, max |x| = $(round(r.max_x*1000, digits=2)) mm")
    end
end

println("\n" ^ 2)
println("=" ^ 72)
println("SUMMARY")
println("=" ^ 72)

for (label, r, _, _) in results
    status = r.decaying ? "❌ DECAY" : "✅ SUSTAIN"
    println("  $status  $label")
    println("         amplitude=$(round(r.max_x*1000, digits=1))mm |x|_avg=$(round(r.avg_abs_x*1000, digits=1))mm |v|_avg=$(round(r.avg_abs_v, digits=2))m/s")
end

# Save data for plotting
println("\nSweep complete. Results printed above.")
