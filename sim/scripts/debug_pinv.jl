#!/usr/bin/env julia
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using LinearAlgebra, Levitation6D

params = Lev6DParams(m=5.0, z_target=0.010, F_bias=14.0, n_exp=2.5, k_i=10.0,
    k_lat_disp=5.0, k_lat_direct=0.5, k_center_total=20000.0)
coils = Levitation6D.build_coils(params)

# Actuation matrix at target
A  = actuation_matrix(0.0, 0.0, 0.01, 0.0, 0.0, 0.0, coils, params)
A2 = actuation_matrix(0.0002, 0.0002, 0.00995, 0.001, -0.001, 0.001, coils, params)

println("A rank: $(rank(A))")
println("A cond: $(cond(A))")
println()
println("=== At target (centered) ===")
F_coil = [0.0, 0.0, -6.95, 0.0, 0.0, 0.0]

# 1) pinv — should always work
i_pinv = pinv(A) * F_coil
println("pinv(A)*F = $(round.(i_pinv, digits=4))")
println("  A*i     = $(round.(A*i_pinv, digits=2))")
println("  ||r||   = $(round(norm(A*i_pinv - F_coil), digits=4))")

# 2) QR least-squares step by step
A_plus = pinv(A)
i_from_qr = A_plus * F_coil
println("\nSame result via pinv (should match):")
println("  i = $(round.(i_from_qr, digits=4))")
println("  A*i = $(round.(A*i_from_qr, digits=2))")

println()
println("=== At offset ===")
F_bias = total_wrench(0.0002, 0.0002, 0.00995, 0.001, -0.001, 0.001, zeros(4), coils, params)
F_des  = [0.0, 0.0, 49.05, 0.0, 0.0, 0.0]
F_coil2 = F_des - F_bias

println("F_bias = $(round.(F_bias, digits=1))")
println("F_needed = $(round.(F_coil2, digits=1))")
println()

# Wrong formula
M = A2 * A2' + 1e-6 * I   # stronger regularisation
x = M \ F_coil2
i_wrong = A2' * x
println("WRONG  (A'*(AA'+εI)⁻¹b): i = $(round.(i_wrong, digits=4))")
println("  A*i = $(round.(A2*i_wrong, digits=1))   ||r|| = $(round(norm(A2*i_wrong - F_coil2), digits=2))")

# Correct via pinv
i_corr = pinv(A2) * F_coil2
println("CORRECT (pinv(A)*b):       i = $(round.(i_corr, digits=4))")
println("  A*i = $(round.(A2*i_corr, digits=1))   ||r|| = $(round(norm(A2*i_corr - F_coil2), digits=2))")

# What the PID computes at step 1 (initial state)
println()
println("=== PID output at step 1 (initial state) ===")
z = 0.00995
vz = 0.0
z_target = 0.010
kp, ki, kd = 2000.0, 500.0, 50.0
e_z = z - z_target
e_dot = vz
F_des_z = -kp * e_z - kd * e_dot   # no integral yet
println("  e_z = $(round(e_z*1000, digits=3)) mm, F_des_z = $(round(F_des_z, digits=2)) N")
F_bias_at = total_wrench(0.0002, 0.0002, z, 0.001, -0.001, 0.001, zeros(4), coils, params)
F_coil_z = [0.0, 0.0, F_des_z + 49.05 - F_bias_at[3], 0.0, 0.0, 0.0]
println("  F_bias_z = $(round(F_bias_at[3], digits=1)) N")
println("  F_coil_needed_z = $(round(F_coil_z[3], digits=1)) N")
i_1 = pinv(A2) * F_coil_z
println("  i = $(round.(i_1, digits=4)) A")
println("  A*i = $(round.(A2*i_1, digits=1))")
