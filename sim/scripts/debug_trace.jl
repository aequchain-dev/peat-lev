#!/usr/bin/env julia
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using Printf, Levitation6D

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

N = params.n_coils
coils = Levitation6D.build_coils(params)

# Initial state
x0, y0, z0 = 0.0002, 0.0002, params.z_target * 0.995
roll0, pitch0, yaw0 = 0.001, -0.001, 0.001
u0 = [x0, y0, z0, roll0, pitch0, yaw0,
      0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
      zeros(N)...]

dt = 1/params.ctrl_rate

# Manual integration for first 10 steps
diag = Levitation6D.DiagData6D(N)
ctrl_rate = params.ctrl_rate

u = copy(u0)

for step in 1:10
    t = step * dt
    ctrl_c = diag
    
    # ── Run PID ──
    Nc = N
    x, y, z, roll, pitch, yaw = u[1:6]
    vx, vy, vz, ωx, ωy, ωz = u[7:12]
    
    dt_ = t - ctrl_c.last_t
    if dt_ <= 0
        dt_ = 1/ctrl_rate
    end
    ctrl_c.last_t = t
    
    i_desired, e_int_new, F_desired, F_bias_wrench, A_mat =
        Levitation6D.pid_control_6d(x, y, z, roll, pitch, yaw,
                                     vx, vy, vz, ωx, ωy, ωz,
                                     ctrl_c.e_int, coils, params, dt_)
    
    copy!(ctrl_c.e_int, e_int_new)
    copy!(ctrl_c.i_desired, i_desired)
    
    # ── Step dynamics with Euler (for debugging) ──
    currents = u[13:12+N]
    τ_i = 0.0002
    
    wrench = Levitation6D.total_wrench(x, y, z, roll, pitch, yaw, currents, coils, params)
    Fx, Fy, Fz, Tx, Ty, Tz = wrench
    
    @printf("Step %2d  t=%.4f  z=%.6f  Fz_pm=%.2f  Fz_coil_total=%.2f  i_des=[%.3f %.3f %.3f %.3f]  i_act=[%.3f %.3f %.3f %.3f]  e_int_z=%.6f\n",
            step, t, z,
            F_bias_wrench[3],
            sum(params.k_i * currents),
            i_desired[1], i_desired[2], i_desired[3], i_desired[4],
            currents[1], currents[2], currents[3], currents[4],
            ctrl_c.e_int[3])
    
    # Forward Euler for current dynamics
    di_dt = zeros(N)
    for j in 1:N
        di_dt[j] = (i_desired[j] - currents[j]) / τ_i
        di_dt[j] = clamp(di_dt[j], -1e6, 1e6)
    end
    
    # Rigid body accelerations  
    dvx_dt = Fx / params.m
    dvy_dt = Fy / params.m
    dvz_dt = (Fz - params.m * 9.81) / params.m
    dωx_dt = Tx / params.J_xx
    dωy_dt = Ty / params.J_yy
    dωz_dt = Tz / params.J_zz
    
    # Euler update
    u[1] += u[7] * dt         # x += vx*dt
    u[2] += u[8] * dt         # y += vy*dt
    u[3] += u[9] * dt         # z += vz*dt
    u[4] += u[10] * dt        # roll
    u[5] += u[11] * dt        # pitch
    u[6] += u[12] * dt        # yaw
    u[7] += dvx_dt * dt       # vx
    u[8] += dvy_dt * dt       # vy
    u[9] += dvz_dt * dt       # vz
    u[10] += dωx_dt * dt      # ωx
    u[11] += dωy_dt * dt      # ωy
    u[12] += dωz_dt * dt      # ωz
    u[13:12+N] += di_dt * dt  # currents
    
    # Clamp currents
    for j in 1:N
        u[12+j] = clamp(u[12+j], -params.I_max, params.I_max)
    end
    
    v = u[9]
    @printf("         vz=%.4f  accel_z=%.2f\n", v, dvz_dt)
end

println("\nState after 10 steps:")
println("  z = $(u[3]) m")
println("  vz = $(u[9]) m/s")
println("  currents = $(round.(u[13:12+4], digits=4)) A")
