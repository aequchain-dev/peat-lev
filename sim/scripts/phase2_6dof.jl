#!/usr/bin/env julia
"""
    Phase 2 — 6-DOF Magnetic Levitation Simulation

Full 6-axis (x, y, z, roll, pitch, yaw) steerable maglev with:
  - 4-coil planar array (quadrant arrangement at ±150 mm)
  - PM bias + bidirectional current control
  - 6-axis PID via mixing matrix pseudoinverse
  - AFPM generator self-powering verification
  - Scalability validation (N=3, N=4, N=8)

Testing suite:
  1. Steady hover — full 6-DOF stabilization
  2. Step disturbance on each axis — disturbance rejection
  3. Sinusoidal disturbance on each axis — tracking
  4. Scalability — N=3 and N=8 coil configurations
  5. Power analysis — self-powering verification
"""

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using Levitation6D
using Plots
using Printf
using Statistics

# =============================================================================
# Default 6-DOF Parameters
# =============================================================================

params = Lev6DParams(
    m          = 5.0,       # 5 kg platform
    z_target   = 0.010,     # 10 mm hover gap

    # Coil array
    coil_R     = 0.150,     # 150 mm from CoG
    n_coils    = 4,         # 4 quadrant coils

    # Actuator
    F_bias     = 14.0,      # PM bias per coil @ ref gap [N] (4×14=56 N ≈ mg)
    n_exp      = 2.5,       # PM field decay exponent
    k_i        = 10.0,      # Force per ampere [N/A]
    k_lat_disp      = 5.0,  # Displacement-dependent lateral coeff [N/A/m offset]
    k_lat_direct    = 0.5,  # Direct lateral force at zero offset [N/A]
    k_center_total  = 20000.0,  # PM lateral centering stiffness [N/m]

    # Electrical
    L_coil     = 0.002,     # 2 mH
    R_wire     = 0.5,       # 0.5 Ω
    I_max      = 10.0,      # ±10 A per coil

    # PID gains (x, y, z, roll, pitch, yaw)
    Kp         = [5000.0, 5000.0, 10000.0, 200.0, 200.0, 100.0],
    Ki         = [200.0, 200.0, 600.0, 50.0, 50.0, 20.0],
    Kd         = [200.0, 200.0, 400.0, 30.0, 30.0, 15.0],

    # Generator
    P_AFPM_nominal = 250.0,
    η_gen      = 0.85
)

axis_names_6 = ["X", "Y", "Z", "Roll", "Pitch", "Yaw"]
axis_units   = ["mm", "mm", "mm", "mrad", "mrad", "mrad"]
scale_6      = [1e3, 1e3, 1e3, 1e3, 1e3, 1e3]

println("╔" ^ 40)
println("   Phase 2 — 6-DOF Magnetic Levitation")
println("   Multi-coil planar array + PM bias + PID + mixing matrix")
println("╚" ^ 40)
println()
println("  Platform mass:     $(params.m) kg")
println("  Target gap:        $(params.z_target*1000) mm")
println("  Coil array:        $(params.n_coils) coils at ±$(params.coil_R*1000) mm")
println("  PM bias per coil:  $(params.F_bias) N (total: $(params.F_bias*4) N = $(params.F_bias*4/(params.m*9.81))×mg)")
println("  Control authority:  ±$(params.I_max * params.k_i) N/coil")
println("  Generator:          $(params.P_AFPM_nominal) W (η=$(params.η_gen*100)%)")
println()

# =============================================================================
# TEST 1: Steady Hover — full 6-DOF
# =============================================================================

println("─" ^ 65)
println("  TEST 1: Steady 6-DOF Hover (2.0 s)")
println("─" ^ 65)

r_hover = run_6dof_simulation(params, duration=2.0, verbose=false)
r_hover[:params] = params
m = r_hover[:metrics]

println("  Results:")
@printf("    Settling time (Z):     %.4f s\n", m[:settling_time])
println("    Axis errors (RMS):")
for i in 1:6
    @printf("      %-10s  %8.2e  (%.2f %s)\n",
            axis_names_6[i], m[:errors_rms][i],
            m[:errors_rms][i] * scale_6[i], axis_units[i])
end
@printf("    Power (avg):           %.2f W\n", m[:P_mean])
@printf("    Generator output:      %.1f W\n", m[:P_gen])
@printf("    Self-powered?:         %s\n", m[:self_powered] ? "YES ✓" : "NO ✗")
println()

# Plot
p_hover = plot_6dof_results(r_hover, title="Test 1: Steady 6-DOF Hover")
savefig(p_hover, joinpath(@__DIR__, "..", "output", "phase2_hover.png"))
println("  → Plot saved to output/phase2_hover.png")
println()

# =============================================================================
# TEST 2: Step Disturbance — each axis
# =============================================================================

println("─" ^ 65)
println("  TEST 2: Step Disturbance (10 N, 0.5 Nm — 2.0 s)")
println("─" ^ 65)

step_amplitudes = [10.0, 10.0, 10.0, 0.5, 0.5, 0.5]  # N for xyz, Nm for rpy
step_results = []

for axis in 1:6
    amp = step_amplitudes[axis]
    @printf("  Axis %d (%s): %.1f %s step\n",
            axis, axis_names_6[axis], amp,
            axis <= 3 ? "N" : "Nm")
    
    r = step_disturbance_6d(params, amplitude=amp, t_step=0.5,
                            duration=2.0, axis=axis)
    r[:params] = params
    push!(step_results, r)
    
    m = r[:metrics]
    @printf("    Peak error: %.2e (%.2f %s)\n",
            m[:errors_rms][axis], m[:errors_rms][axis] * scale_6[axis], axis_units[axis])
    @printf("    Self-powered?: %s\n\n", m[:self_powered] ? "YES ✓" : "NO ✗")
    
    p = plot_6dof_results(r, title="Test 2: Step on $(axis_names_6[axis])")
    savefig(p, joinpath(@__DIR__, "..", "output",
            "phase2_step_axis$(axis)_$(axis_names_6[axis]).png"))
end

# =============================================================================
# TEST 3: Sinusoidal Disturbance — each axis
# =============================================================================

println("─" ^ 65)
println("  TEST 3: Sinusoidal Disturbance (5 Hz — 3.0 s)")
println("─" ^ 65)

sin_amplitudes = [5.0, 5.0, 5.0, 0.3, 0.3, 0.3]
sin_results = []

for axis in 1:6
    amp = sin_amplitudes[axis]
    @printf("  Axis %d (%s): %.1f %s at 5 Hz\n",
            axis, axis_names_6[axis], amp,
            axis <= 3 ? "N" : "Nm")
    
    r = sinusoidal_disturbance_6d(params, amplitude=amp, freq=5.0,
                                  duration=3.0, axis=axis)
    r[:params] = params
    push!(sin_results, r)
    
    m = r[:metrics]
    @printf("    RMS error:  %.2e (%.2f %s)\n",
            m[:errors_rms][axis], m[:errors_rms][axis] * scale_6[axis], axis_units[axis])
    @printf("    Self-powered?: %s\n\n", m[:self_powered] ? "YES ✓" : "NO ✗")
    
    p = plot_6dof_results(r, title="Test 3: Sine on $(axis_names_6[axis]) (5 Hz)")
    savefig(p, joinpath(@__DIR__, "..", "output",
            "phase2_sine_axis$(axis)_$(axis_names_6[axis]).png"))
end

# =============================================================================
# TEST 4: Decoupling Analysis
# =============================================================================

println("─" ^ 65)
println("  TEST 4: Decoupling Analysis")
println("─" ^ 65)

println("  Covariance-based coupling metric (0 = perfect decoupling, 1 = full coupling):")
for i in 1:6
    @printf("    %-12s  %.4f\n", axis_names_6[i], m[:decoupling][i])
end
println()

# =============================================================================
# TEST 5: Scalability — N=3 and N=8 coil configurations
# =============================================================================

println("─" ^ 65)
println("  TEST 5: Scalability")
println("─" ^ 65)

for N in [3, 8]
    @printf("  Testing N=%d coil configuration...\n", N)
    params_N = deepcopy(params)
    params_N.n_coils = N
    
    # Adjust PM bias: keep same total PM force (~56 N)
    params_N.F_bias = 56.0 / N
    
    r_N = run_6dof_simulation(params_N, duration=1.0, verbose=false)
    r_N[:params] = params_N
    m_N = r_N[:metrics]
    
    @printf("    Settling time: %.4f s\n", m_N[:settling_time])
    @printf("    Z-axis RMS error: %.2f μm\n", m_N[:errors_rms][3] * 1e6)
    @printf("    Power (avg): %.2f W\n", m_N[:P_mean])
    @printf("    Self-powered?: %s\n\n", m_N[:self_powered] ? "YES ✓" : "NO ✗")
    
    p_N = plot_6dof_results(r_N, title="Test 5: N=$(N) Coil Configuration")
    savefig(p_N, joinpath(@__DIR__, "..", "output",
            "phase2_N$(N)_coils.png"))
end

# =============================================================================
# TEST 6: Power Budget Analysis
# =============================================================================

println("─" ^ 65)
println("  TEST 6: Power Budget Analysis")
println("─" ^ 65)

@printf("  Generator (AFPM):          %.1f W nominal\n", params.P_AFPM_nominal)
@printf("  Generator (net):           %.1f W after η=%.0f%%\n",
        params.P_AFPM_nominal * params.η_gen, params.η_gen * 100)
@printf("  Coil resistance:           %.1f Ω per coil\n", params.R_wire)
@printf("  Max copper loss (4 coils): %.1f W (all at I_max)\n",
        4 * params.I_max^2 * params.R_wire)
@printf("  Typical hover consumption: %.2f W\n", m[:P_mean])
@printf("  Headroom:                  %.1f%%\n",
        (params.P_AFPM_nominal * params.η_gen / m[:P_mean] - 1) * 100)
println()

# =============================================================================
# Summary
# =============================================================================

println("╔" ^ 40)
println("  PHASE 2 COMPLETE")
println("╚" ^ 40)
println()
println("  Output files in output/:")
println("  • phase2_hover.png — steady 6-DOF hover")
println("  • phase2_step_axis{1..6}_{axis}.png — step disturbance per axis")
println("  • phase2_sine_axis{1..6}_{axis}.png — sine disturbance per axis")
println("  • phase2_N{3,8}_coils.png — scalability tests")
println()
println("  Key metrics from steady hover:")
for i in 1:6
    @printf("    %-12s  RMS error: %.2f %s\n",
            axis_names_6[i], m[:errors_rms][i] * scale_6[i], axis_units[i])
end
@printf("  Power consumption: %.2f W (self-powered: %s)\n",
        m[:P_mean], m[:self_powered] ? "YES ✓" : "NO ✗")
