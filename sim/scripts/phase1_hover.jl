#!/usr/bin/env julia
"""
    Phase 1 — 1-DOF Vertical Levitation Proof of Concept

Validates closed-loop PWM current regulation + PM bias + PID control
for a single-axis levitation system.

Three tests:
1. Steady hover — can it maintain commanded position?
2. Step disturbance — how fast does it recover from a push?
3. Sinusoidal disturbance — can it reject oscillatory forces?
"""

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using LevitationSim
using Plots
using Printf

# =============================================================================
# Default Parameters
# =============================================================================

params = LevParams(
    m           = 5.0,       # 5 kg platform
    z_target    = 0.010,     # 10 mm hover gap
    F_bias      = 50.0,      # PM repulsive bias ≈ mg [N]
    n_exp       = 2.5,       # PM field decay exponent
    k_i         = 10.0,      # Force per ampere [N/A]
    L_coil      = 0.002,     # 2 mH
    R_wire      = 0.5,       # 0.5 Ω
    I_max       = 10.0,      # 10 A max (with k_i=10, gives ±100 N control)
    V_bus       = 100.0,     # 100 V DC bus
    f_pwm       = 20_000.0,  # 20 kHz PWM
    Kp          = 8000.0,    # PID gains
    Ki          = 500.0,
    Kd          = 300.0,
    P_AFPM_nominal = 250.0,  # 250 W nominal AFPM output
    η_gen       = 0.85       # 85% efficient
)

println("╔" ^ 35)
println("  Phase 1 — 1-DOF Levitation Proof of Concept")
println("╚" ^ 35)
println("  Mass:        $(params.m) kg")
println("  Target gap:  $(params.z_target * 1000) mm")
println("  PM bias:     $(params.F_bias) N at ref gap, exponent $(params.n_exp)")
println("  Force/A:     $(params.k_i) N/A (max control: ±$(params.I_max * params.k_i) N)")
println("  Coil:        $(params.L_coil*1000) mH, $(params.R_wire) Ω")
println("  PWM:         $(params.f_pwm/1000) kHz at $(params.V_bus) V")
println("  Generator:   $(params.P_AFPM_nominal) W (η = $(params.η_gen*100)%)")
println()

# =============================================================================
# Test 1: Steady Hover
# =============================================================================

println("─" ^ 60)
println("  TEST 1: Steady Hover (1.0 s)")
println("─" ^ 60)

r1 = run_simulation(params, duration=1.0, verbose=true)
r1[:params] = params

p1 = plot_results(r1, title="Test 1: Steady Hover")
savefig(p1, joinpath(@__DIR__, "..", "output", "phase1_hover.png"))
println("  → Plot saved to output/phase1_hover.png")
println()

# =============================================================================
# Test 2: Step Disturbance Rejection
# =============================================================================

println("─" ^ 60)
println("  TEST 2: Step Disturbance (10 N push at t=0.5 s)")
println("─" ^ 60)

r2 = disturbance_rejection_test(params, amplitude=10.0, duration=2.0)
r2[:params] = params

p2 = plot_results(r2, title="Test 2: Step Disturbance ($(r2[:disturbance])) N at t=0.5s")
savefig(p2, joinpath(@__DIR__, "..", "output", "phase1_disturbance.png"))
println("  → Plot saved to output/phase1_disturbance.png")
println()

# =============================================================================
# Test 3: Sinusoidal Disturbance
# =============================================================================

println("─" ^ 60)
println("  TEST 3: Sinusoidal Disturbance (5 Hz, ±10 N at t=0.5s)")
println("─" ^ 60)

function sin_disturbance(t)
    return t >= 0.5 ? 10.0 * sin(2π * 5.0 * (t - 0.5)) : 0.0
end

r3 = run_simulation(params, duration=3.0, disturbance=sin_disturbance, verbose=true)
r3[:params] = params

p3 = plot_results(r3, title="Test 3: Sinusoidal Disturbance (5 Hz, ±10 N)")
savefig(p3, joinpath(@__DIR__, "..", "output", "phase1_sine_disturbance.png"))
println("  → Plot saved to output/phase1_sine_disturbance.png")
println()

# =============================================================================
# Test 4: Power Budget Sweep
# =============================================================================

println("─" ^ 60)
println("  TEST 4: Power Budget Envelope")
println("─" ^ 60)

sweep_result = power_sweep(params, masses=1.0:2.0:15.0, 
                           z_gaps=[0.005, 0.010, 0.015], duration=0.5)
println()

# =============================================================================
# Summary
# =============================================================================

println("╔" ^ 35)
println("  PHASE 1 COMPLETE")
println("╚" ^ 35)

mets = r1[:metrics]
P_gen = params.P_AFPM_nominal * params.η_gen
println()
println("  Key results:")
@printf("  • Hover accuracy:   %+.2e m (%+.2f μm)\n", mets[:z_error_mean], mets[:z_error_mean]*1e6)
@printf("  • Position RMS err: %.2e m (%.2f μm)\n", mets[:z_error_rms], mets[:z_error_rms]*1e6)
@printf("  • Power consumption: %.1f W\n", mets[:P_elec_mean])
@printf("  • Generator output:  %.1f W\n", P_gen)
@printf("  • Self-powered?:     %s\n", P_gen > mets[:P_elec_mean] ? "YES ✓" : "NO ✗")
println()
println("  Output files:")
println("  • output/phase1_hover.png")
println("  • output/phase1_disturbance.png")
println("  • output/phase1_sine_disturbance.png")
