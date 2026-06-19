#!/usr/bin/env julia
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using Levitation6D

params = Lev6DParams(
    m          = 5.0,
    z_target   = 0.010,
    coil_R     = 0.150,
    n_coils    = 4,
    F_bias     = 14.0,
    n_exp      = 2.5,
    k_i        = 10.0,
    k_lat_disp      = 5.0,
    k_lat_direct    = 0.5,
    k_center_total  = 20000.0,
    L_coil     = 0.002,
    R_wire     = 0.5,
    I_max      = 10.0,
    Kp         = [5000.0, 5000.0, 10000.0, 200.0, 200.0, 100.0],
    Ki         = [200.0, 200.0, 600.0, 50.0, 50.0, 20.0],
    Kd         = [200.0, 200.0, 400.0, 30.0, 30.0, 15.0],
    P_AFPM_nominal = 250.0,
    η_gen      = 0.85
)

coils = Levitation6D.build_coils(params)
println("Number of coils: $(length(coils))")
for (i,c) in enumerate(coils)
    println("  Coil $i: pos=[$(c.pos)], normal=[$(c.normal)], PM_dir=[$(c.pm_dir)]")
end

# === AT TARGET ===
println("\n" * "="^60)
println("=== AT TARGET (z=10mm, centered) ===")
println("="^60)
center_currents = zeros(4)
wrench_bias = total_wrench(0, 0, 0.01, 0, 0, 0, center_currents, coils, params)
println("PM bias Fz = $(wrench_bias[3]) N (mg=$(params.m*9.81) N)")

A = actuation_matrix(0, 0, 0.01, 0, 0, 0, coils, params)
println("\nActuation matrix A (6×4):")
for i in 1:6
    println("  [$(@sprintf("%8.1f %8.1f %8.1f %8.1f", A[i,:]...))]")
end

# PID at target — should give near-zero correction
e_int = zeros(6)
dt = 0.001
println("\n=== PID at target (zero error) ===")
i_des, e_int_new, F_des, F_bias_w, A_mat = pid_control_6d(0,0,0.01, 0,0,0, 0,0,0, 0,0,0, e_int, coils, params, dt)
println("i_desired = $(round.(i_des, digits=3)) A")
println("F_desired = $(round.(F_des, digits=3)) N")
println("F_bias_w  = $(round.(F_bias_w, digits=3)) N")
println("PID should output near-zero. i_des near zero or very small.")

# === OFF-TARGET (0.5 mm below) ===
println("\n" * "="^60)
println("=== OFF-TARGET (z=9.5mm — 0.5 mm below) ===")
println("="^60)
z_off = 0.0095
wrench_off = total_wrench(0, 0, z_off, 0, 0, 0, center_currents, coils, params)
println("PM bias Fz at z=$(z_off*1000)mm = $(wrench_off[3]) N")
println("Missing force: $(params.m*9.81 - wrench_off[3]) N")

i_des2, _, F_des2, F_bias_w2, _ = pid_control_6d(0,0,z_off, 0,0,0, 0,0,0, 0,0,0, e_int, coils, params, dt)
println("i_desired = $(round.(i_des2, digits=3)) A")
println("F_desired = $(round.(F_des2, digits=3)) N")
println("F_bias_w  = $(round.(F_bias_w2, digits=3)) N")
println("Missing force from PID: F_desired[3] - (-mg) = $(F_des2[3] + params.m*9.81) N")
println("F_bias_w[3] = $(F_bias_w2[3]) N")
println("F_coil_needed = F_desired - F_bias_w = $(round.(F_des2 - F_bias_w2, digits=3)) N")
println("This is what A+ should allocate")

# Test vertical check: pid_control_6d when using z_target
# The PID target in pid_control_6d is params.z_target from the params struct
# Let me check what z_target the function actually uses
println("\nparams.z_target = $(params.z_target)")

# One more — check what PID outputs with large error
println("\n" * "="^60)
println("=== PID with large error ===")
# 5 mm below target
i_des3, _, F_des3, F_bias_w3, _ = pid_control_6d(0,0,0.005, 0,0,0, 0,0,0, 0,0,0, e_int, coils, params, dt)
println("z_error = $(params.z_target - 0.005) = 0.005 m")
println("i_desired = $(round.(i_des3, digits=3)) A")
println("F_desired[3] = $(F_des3[3]) N (PID wants this vertical force)")
println("F_bias_w[3]  = $(F_bias_w3[3]) N (current PM force)")
println("F_coil_needed[3] = $(F_des3[3] - F_bias_w3[3]) N")
println("P-control term: Kp_z * error = $(params.Kp[3] * (params.z_target - 0.005)) N")
