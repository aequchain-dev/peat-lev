"""
    Levitation6D — 6-Axis Steerable Magnetic Levitation Simulation

Full 6-DOF (x, y, z, roll, pitch, yaw) model of a PM-biased electromagnetic
levitation array. Each coil can independently vary polarity and magnitude,
providing calibrated control over all six rigid-body degrees of freedom.

# Architecture
- Planar array of N electromagnets (default: 4 quadrant coils)
- Each coil: PM bias + bidirectional current regulator
- Mixing matrix A: desired [F;T] → individual coil currents
- Six independent PID loops → decoupled axis control

# Model (from framework document §3-4)
    F_z,i(z,i) = F_bias × (z_ref / z_eff)^n + k_i × i
    F_x,i ≈ (k_lat_direct × sign(x) + k_lat_disp × x_offset) × i
    F_y,i ≈ (k_lat_direct × sign(y) + k_lat_disp × y_offset) × i

    Net force/torque on platform:
        [F_x, F_y, F_z, T_x, T_y, T_z]^T = A(i) × i_coils

    Control: PID per DOF → desired [F;T] → A^+ → coil currents

# Usage
    include("scripts/phase2_6dof.jl")
"""
module Levitation6D

using LinearAlgebra
using DifferentialEquations
using Parameters
using Plots
using Printf
using Statistics

export Lev6DParams, Lev6DState, CoilGeometry
export coil_force_6d, total_wrench, actuation_matrix
export pid_control_6d, run_6dof_simulation
export plot_6dof_results, print_6dof_metrics
export step_disturbance_6d, sinusoidal_disturbance_6d

# =============================================================================
# Physical Constants
# =============================================================================

const g₀ = 9.80665  # Standard gravity [m/s²]

# =============================================================================
# Coil Geometry
# =============================================================================

struct CoilGeometry
    x::Float64      # Coil x-position relative to CoG [m]
    y::Float64      # Coil y-position relative to CoG [m]
    F_bias::Float64 # PM bias force at reference gap [N]
end

# =============================================================================
# 6-DOF Parameter Structure
# =============================================================================

@with_kw mutable struct Lev6DParams
    # ── Mechanical ────────────────────────────────────────────────────────
    m::Float64 = 5.0                 # Platform mass [kg]
    J_xx::Float64 = 0.05             # Moment of inertia about x [kg·m²]
    J_yy::Float64 = 0.05             # Moment of inertia about y [kg·m²]
    J_zz::Float64 = 0.08             # Moment of inertia about z [kg·m²]
    
    # ── Target pose ──────────────────────────────────────────────────────
    x_target::Float64 = 0.0          # Target x position [m]
    y_target::Float64 = 0.0          # Target y position [m]
    z_target::Float64 = 0.010        # Target hover gap [m]
    roll_target::Float64 = 0.0       # Target roll angle [rad]
    pitch_target::Float64 = 0.0      # Target pitch angle [rad]
    yaw_target::Float64 = 0.0        # Target yaw angle [rad]
    
    # ── Coil Array ───────────────────────────────────────────────────────
    # Default: 4 quadrant coils at (±150 mm, ±150 mm)
    # This arrangement provides full 6-axis control:
    #   Z: sum of all 4 vertical forces
    #   X: differential lateral forces from E1+E2 vs E3+E4
    #   Y: differential lateral forces from E1+E4 vs E2+E3
    #   Roll: differential Z from E1+E2 vs E3+E4 (y-offset)
    #   Pitch: differential Z from E1+E4 vs E2+E3 (x-offset)
    #   Yaw: differential lateral from opposite corners
    coil_R::Float64 = 0.150          # Coil radial distance from CoG [m]
    n_coils::Int = 4                 # Number of coils (≥3 for 6-axis)
    
    # ── Per-Coil Actuator Parameters ─────────────────────────────────────
    F_bias::Float64 = 14.0           # PM bias force per coil at ref gap[N]
                                     # 4 coils × 14 N = 56 N ≈ mg
    n_exp::Float64 = 2.5             # PM field decay exponent
    k_i::Float64 = 10.0              # Force per ampere [N/A]
    k_lat_disp::Float64 = 5.0        # Displacement-dependent lateral force coeff [N/A/m offset]
                                     # F_lat,disp ∝ displacement × current
    k_lat_direct::Float64 = 0.5      # Direct lateral force per amp [N/A]
                                     # F_lat,direct ∝ sign(coil.pos) × current
                                     # Enables lateral control at zero displacement
    
    # ── Passive PM Centering ───────────────────────────────────────────
    k_center_total::Float64 = 20000.0  # PM lateral centering stiffness [N/m]
                                       # Passive restoring force: F_PM = -k·x
    
    # ── Electrical ───────────────────────────────────────────────────────
    L_coil::Float64 = 0.002          # Coil inductance [H]
    R_wire::Float64 = 0.5            # Coil resistance [Ω]
    I_max::Float64 = 10.0            # Maximum current per coil [A]
    
    # ── Control (6-axis PID gains) ───────────────────────────────────────
    # Order: [x, y, z, roll, pitch, yaw]
    Kp::Vector{Float64} = [10000.0, 10000.0, 10000.0, 200.0, 200.0, 200.0]
    Ki::Vector{Float64} = [500.0, 500.0, 600.0, 50.0, 50.0, 50.0]
    Kd::Vector{Float64} = [400.0, 400.0, 400.0, 30.0, 30.0, 30.0]
    ctrl_rate::Float64 = 5000.0      # Control loop rate [Hz]
    
    # ── AFPM Generator ──────────────────────────────────────────────────
    P_AFPM_nominal::Float64 = 250.0  # AFPM generator nominal output [W]
    η_gen::Float64 = 0.85            # Generator efficiency
    
    # ── Sensor ──────────────────────────────────────────────────────────
    σ_pos::Float64 = 5e-6            # Position sensor noise (std) [m]
    σ_ang::Float64 = 1e-5            # Angle sensor noise (std) [rad]
    σ_vel::Float64 = 0.005           # Velocity sensor noise [m/s]
    σ_ω::Float64 = 0.001             # Angular velocity noise [rad/s]
end

# =============================================================================
# Build coil geometry from params
# =============================================================================

function build_coils(params::Lev6DParams)::Vector{CoilGeometry}
    R = params.coil_R
    N = params.n_coils
    F_b = params.F_bias
    
    coils = CoilGeometry[]
    
    if N == 4
        # 4 coils at (±R, ±R)
        push!(coils, CoilGeometry( R,  R, F_b))  # E1: front-right
        push!(coils, CoilGeometry(-R,  R, F_b))  # E2: front-left
        push!(coils, CoilGeometry(-R, -R, F_b))  # E3: back-left
        push!(coils, CoilGeometry( R, -R, F_b))  # E4: back-right
    elseif N == 3
        # 3 coils at 120° spacing
        for k in 0:2
            θ = 2π * k / 3
            push!(coils, CoilGeometry(R * cos(θ), R * sin(θ), F_b))
        end
    elseif N == 8
        # 8 coils: outer ring + inner ring
        for k in 0:3
            θ = 2π * k / 4
            push!(coils, CoilGeometry(R * cos(θ), R * sin(θ), F_b))
        end
        for k in 0:3
            θ = 2π * k / 4 + π/4
            push!(coils, CoilGeometry(R * 0.5 * cos(θ), R * 0.5 * sin(θ), F_b))
        end
    else
        error("Unsupported coil count: $N (use 3, 4, or 8)")
    end
    
    return coils
end

# =============================================================================
# 6-DOF State
# =============================================================================

struct Lev6DState
    # Position (CoG in world frame)
    x::Float64
    y::Float64
    z::Float64
    roll::Float64
    pitch::Float64
    yaw::Float64
    
    # Velocities
    vx::Float64
    vy::Float64
    vz::Float64
    ωx::Float64
    ωy::Float64
    ωz::Float64
    
    # Coil currents [n_coils]
    i::Vector{Float64}
    
    # Controller integral error [6]
    e_int::Vector{Float64}
end

# =============================================================================
# 6-DOF Force Model — Single Coil
# =============================================================================

"""
    coil_force_6d(x, y, z, roll, pitch, yaw, i_coil, coil, params)

Compute the 6-axis force/torque contribution from a single coil.

Returns: (F_x, F_y, F_z, T_x, T_y, T_z) — the contribution of this one coil
to the net platform wrench.

Physical model:
- Vertical force: F_z = F_bias(z_eff)^n + k_i × i_coil
    where z_eff = z + pitch×x_c - roll×y_c (effective gap at coil)
    
- Lateral force: F_x, F_y from coil offset + tilt
    F_x = (k_lat_direct × sign(x) + k_lat_disp × (x + pitch×z)) × i_coil
    F_y = (k_lat_direct × sign(y) + k_lat_disp × (y + roll×z)) × i_coil

- Torque = r × F (cross product of coil position and force)

Bidirectional control: i_coil can be positive (adds repulsion) or
negative (adds attraction), allowing full polarity control.
"""
function coil_force_6d(x::Float64, y::Float64, z::Float64,
                       roll::Float64, pitch::Float64, yaw::Float64,
                       i_coil::Float64, coil::CoilGeometry, params::Lev6DParams)
    
    # Effective gap at coil position (small-angle approx for tilt)
    z_eff = z + pitch * coil.x - roll * coil.y
    z_eff = max(z_eff, 0.001)  # Protect against contact
    
    # ── Vertical force (PM bias + coil modulation) ──────────────────────
    ζ = z_eff / params.z_target
    F_bias_z = coil.F_bias / (max(ζ, 0.01)^params.n_exp)
    F_z = F_bias_z + params.k_i * i_coil
    
    # ── Lateral forces (from CoG displacement and tilt) ─────────────────
    # Effective lateral offset of PM relative to coil center
    # (platform displacement + tilt-induced offset)
    x_disp = x + pitch * z       # x-displacement at coil height
    y_disp = y + roll * z        # y-displacement at coil height
    
    # Lateral force has two components:
    #   1. Direct: F ∝ sign(coil.pos) × current  — active control at zero displacement
    #   2. Displacement-dependent: F ∝ disp × current  — passive gradient effect
    coil_x = coil.x
    coil_y = coil.y
    F_x = params.k_lat_direct * sign(coil_x) * i_coil +
          params.k_lat_disp * x_disp * i_coil
    F_y = params.k_lat_direct * sign(coil_y) * i_coil +
          params.k_lat_disp * y_disp * i_coil
    
    # ── Torque contribution ─────────────────────────────────────────────
    # τ = r × F  where r is coil position relative to CoG
    T_x = coil.y * F_z - 0.0 * F_y     # roll  (about x-axis)
    T_y = -coil.x * F_z + 0.0 * F_x    # pitch (about y-axis)
    T_z = -coil.x * F_y + coil.y * F_x # yaw   (about z-axis)
    
    return (F_x, F_y, F_z, T_x, T_y, T_z)
end

# =============================================================================
# Net Wrench — Sum over all coils
# =============================================================================

"""
    total_wrench(x, y, z, roll, pitch, yaw, currents, coils, params)

Sum all coil contributions to get net 6-axis force/torque on platform.
Includes passive PM lateral centering: F_PM = -k_center_total × [x, y, 0, 0, 0, 0].

Returns: [Fx, Fy, Fz, Tx, Ty, Tz]
"""
function total_wrench(x::Float64, y::Float64, z::Float64,
                      roll::Float64, pitch::Float64, yaw::Float64,
                      currents::Vector{Float64}, coils::Vector{CoilGeometry},
                      params::Lev6DParams)
    
    Fx = 0.0; Fy = 0.0; Fz = 0.0
    Tx = 0.0; Ty = 0.0; Tz = 0.0
    
    for (idx, coil) in enumerate(coils)
        ic = currents[idx]
        f = coil_force_6d(x, y, z, roll, pitch, yaw, ic, coil, params)
        Fx += f[1]; Fy += f[2]; Fz += f[3]
        Tx += f[4]; Ty += f[5]; Tz += f[6]
    end
    
    # ── Passive PM centering (restoring force proportional to lateral disp) ─
    # This acts on the platform directly, NOT through the actuation matrix
    # (controller sees F_bias_wrench = total_wrench(... , currents=0.0)
    #  and subtracts it from demand → PM centering is already accounted for)
    Fx += -params.k_center_total * x
    Fy += -params.k_center_total * y
    
    return [Fx, Fy, Fz, Tx, Ty, Tz]
end

# =============================================================================
# Actuation Matrix — Linearized A = dWrench/dI
# =============================================================================

"""
    actuation_matrix(x, y, z, roll, pitch, yaw, coils, params) → A (6×N)

Compute the actuation matrix A where:
    Δ[Fx, Fy, Fz, Tx, Ty, Tz] = A × Δ[currents]

A_ij = derivative of wrench component i w.r.t. coil j current.
This is the Jacobian that maps current changes to force/torque changes.

For the extended model (F_z = k_i × i, F_x = [k_lat_direct·sign(x) + k_lat_disp·x_disp] × i, etc.):
    Each column j = ∂F/∂i_j = [k_lat_direct·sign(x) + k_lat_disp·x_disp,
                               k_lat_direct·sign(y) + k_lat_disp·y_disp,
                               k_i,
                               coil.y × k_i,
                               -coil.x × k_i,
                               -coil.x·(k_lat_direct·sign(y) + k_lat_disp·y_disp)
                                + coil.y·(k_lat_direct·sign(x) + k_lat_disp·x_disp)]
"""
function actuation_matrix(x::Float64, y::Float64, z::Float64,
                          roll::Float64, pitch::Float64, yaw::Float64,
                          coils::Vector{CoilGeometry}, params::Lev6DParams)
    
    N = length(coils)
    A = zeros(6, N)
    
    x_disp = x + pitch * z
    y_disp = y + roll * z
    
    for (j, coil) in enumerate(coils)
        # Lateral force derivatives now include direct term (at zero disp)
        k_lat_direct_x = params.k_lat_direct * sign(coil.x)
        k_lat_direct_y = params.k_lat_direct * sign(coil.y)
        
        A[1, j] = k_lat_direct_x + params.k_lat_disp * x_disp  # dFx/di_j
        A[2, j] = k_lat_direct_y + params.k_lat_disp * y_disp  # dFy/di_j
        A[3, j] = params.k_i                                     # dFz/di_j
        A[4, j] = coil.y * params.k_i                            # dTx/di_j
        A[5, j] = -coil.x * params.k_i                           # dTy/di_j
        A[6, j] = (-coil.x * (k_lat_direct_y + params.k_lat_disp * y_disp) +
                    coil.y * (k_lat_direct_x + params.k_lat_disp * x_disp))  # dTz/di_j
    end
    
    return A
end

# =============================================================================
# 6-Axis PID Controller with Mixing Matrix
# =============================================================================

"""
    pid_control_6d(state, params, coils, e_int, dt)

Compute desired coil currents from 6-axis position error.

Steps:
1. Compute error in each DOF
2. PID control law → desired net wrench (Fx, Fy, Fz, Tx, Ty, Tz)
3. Compute PM bias wrench at current position
4. Required coil wrench = desired - PM bias
5. Solve A × i = F_coil using pseudoinverse → coil currents
"""
function pid_control_6d(x::Float64, y::Float64, z::Float64,
                        roll::Float64, pitch::Float64, yaw::Float64,
                        vx::Float64, vy::Float64, vz::Float64,
                        ωx::Float64, ωy::Float64, ωz::Float64,
                        e_int::Vector{Float64},
                        coils::Vector{CoilGeometry},
                        params::Lev6DParams,
                        dt::Float64)
    
    # Target pose
    targets = [params.x_target, params.y_target, params.z_target,
               params.roll_target, params.pitch_target, params.yaw_target]
    
    # Current pose
    pose = [x, y, z, roll, pitch, yaw]
    vel = [vx, vy, vz, ωx, ωy, ωz]
    
    # ── 1. Compute errors ───────────────────────────────────────────────
    errors = targets .- pose
    
    # Normalize angular errors to [-π, π]
    for i in 4:6  # roll, pitch, yaw
        errors[i] = mod(errors[i] + π, 2π) - π
    end
    
    # ── 2. PID control law → desired wrench ─────────────────────────────
    # Anti-windup on integral
    max_int = zeros(6)
    max_int[1:3] .= 0.5 * params.m * g₀ ./ (params.Ki[1:3] .+ 1e-10)
    max_int[4:6] .= 0.3 ./ (params.Ki[4:6] .+ 1e-10)  # Nm / (Nm/(rad·s))
    
    F_desired = zeros(6)
    for i in 1:6
        # Update integral with anti-windup
        e_int[i] += errors[i] * dt
        e_int[i] = clamp(e_int[i], -max_int[i], max_int[i])
        
        # PID
        F_desired[i] = params.Kp[i] * errors[i] +
                       params.Ki[i] * e_int[i] -
                       params.Kd[i] * vel[i]
    end
    
    # Gravity compensation (z-axis: need to offset gravity)
    F_desired[3] += params.m * g₀
    
    # ── 3. Compute PM bias wrench at current position ───────────────────
    # The PM bias provides a position-dependent baseline force
    # We need the coil contribution only:
    #   F_bias_wrench = total_wrench(currents=0) — force from PMs alone
    zero_currents = zeros(length(coils))
    F_bias_wrench = total_wrench(x, y, z, roll, pitch, yaw,
                                  zero_currents, coils, params)
    
    # Required coil wrench = desired - PM bias
    F_coil_desired = F_desired - F_bias_wrench
    
    # ── 4. Mixing matrix → coil currents ────────────────────────────────
    A = actuation_matrix(x, y, z, roll, pitch, yaw, coils, params)
    
    # Solve A × i = F_coil_desired
    # For N=4 coils, 6×4 system: use Moore–Penrose pseudoinverse (SVD)
    # A is rank-3 at center (Fx/Fy/Tz rows vanish with zero lateral offset)
    # so (A*A') is singular and the normal-equation formula fails.
    # pinv(A) handles rank deficiency gracefully via SVD thresholding.
    try
        i_desired = pinv(A) * F_coil_desired
        
        # Clamp currents to ±I_max
        for j in eachindex(i_desired)
            i_desired[j] = clamp(i_desired[j], -params.I_max, params.I_max)
        end
        
        return i_desired, e_int, F_desired, F_bias_wrench, A
    catch
        @warn "pinv() failed — using damped LS fallback (A'A + λI)⁻¹A'F"
        i_desired = (A' * A + 1e-4 * I) \ (A' * F_coil_desired)
    end
end

# =============================================================================
# 6-DOF Dynamics
# =============================================================================

"""
    dynamics_6d!(du, u, p, t)

Compute derivatives for the 6-DOF levitation system.

State vector u (12 + N):
  [1]  x       [m]     x-position of CoG
  [2]  y       [m]     y-position of CoG
  [3]  z       [m]     z-position (gap)
  [4]  roll    [rad]   roll angle (about x)
  [5]  pitch   [rad]   pitch angle (about y)
  [6]  yaw     [rad]   yaw angle (about z)
  [7]  vx      [m/s]   x-velocity
  [8]  vy      [m/s]   y-velocity
  [9]  vz      [m/s]   z-velocity
  [10] ωx      [rad/s] angular velocity about x
  [11] ωy      [rad/s] angular velocity about y
  [12] ωz      [rad/s] angular velocity about z
  [13..12+N]  i       [A]     coil currents

PID integral errors stored in ctrl.e_int (not in ODE state — modifying
u inside dynamics_6d! would corrupt the ODE solver's error estimation).
"""
function dynamics_6d!(du, u, p, t)
    params = p[1]::Lev6DParams
    coils = p[2]::Vector{CoilGeometry}
    ctrl = p[3]  # mutable container for diagnostic data
    dist_fx = p[4]  # disturbance force functions or zeros
    dist_fy = p[5]
    dist_fz = p[6]
    dist_tx = p[7]
    dist_ty = p[8]
    dist_tz = p[9]
    
    N = params.n_coils
    
    # Extract state
    x, y, z, roll, pitch, yaw = u[1:6]
    vx, vy, vz, ωx, ωy, ωz = u[7:12]
    currents = u[13:12+N]
    
    # NOTE: Control update happens in the PeriodicCallback (ctrl_rate).
    # Here we only read ctrl.i_desired for the current dynamics.
    i_desired = ctrl.i_desired
    
    # ── Current dynamics (first-order lag) ──────────────────────────────
    τ_i = 0.0002  # 5 kHz current loop bandwidth
    di_dt = zeros(N)
    for j in 1:N
        di_dt[j] = (i_desired[j] - currents[j]) / τ_i
        di_dt[j] = clamp(di_dt[j], -1e6, 1e6)
    end
    
    # ── Net wrench ──────────────────────────────────────────────────────
    wrench = total_wrench(x, y, z, roll, pitch, yaw, currents, coils, params)
    Fx, Fy, Fz, Tx, Ty, Tz = wrench
    
    # ── Rigid body dynamics ────────────────────────────────────────────
    # Translational: F = m × a
    dvx_dt = (Fx + dist_fx(t)) / params.m
    dvy_dt = (Fy + dist_fy(t)) / params.m
    dvz_dt = (Fz - params.m * g₀ + dist_fz(t)) / params.m
    
    # Rotational: τ = J × α (simplified — no gyroscopic for small angles)
    J = [params.J_xx, params.J_yy, params.J_zz]
    dωx_dt = (Tx + dist_tx(t)) / J[1]
    dωy_dt = (Ty + dist_ty(t)) / J[2]
    dωz_dt = (Tz + dist_tz(t)) / J[3]
    
    # Kinematics
    dx_dt = vx
    dy_dt = vy
    dz_dt = vz
    droll_dt = ωx
    dpitch_dt = ωy
    dyaw_dt = ωz
    
    # ── Store derivatives ───────────────────────────────────────────────
    du[1:6] = [dx_dt, dy_dt, dz_dt, droll_dt, dpitch_dt, dyaw_dt]
    du[7:12] = [dvx_dt, dvy_dt, dvz_dt, dωx_dt, dωy_dt, dωz_dt]
    du[13:12+N] = di_dt
    
    # ── Store diagnostics ───────────────────────────────────────────────
    ctrl.wrench .= wrench
    
    return nothing
end

# =============================================================================
# Control & Diagnostics Callback
# =============================================================================
# Diagnostic Container
# =============================================================================

mutable struct DiagData6D
    i_desired::Vector{Float64}
    F_desired::Vector{Float64}
    F_bias_wrench::Vector{Float64}
    wrench::Vector{Float64}
    A_mat::Vector{Float64}  # Flattened 6×N
    
    # PID integral errors (NOT in ODE state — set du=0 corrupts error est)
    e_int::Vector{Float64}   # 6 integral error accumulators
    last_t::Float64          # last timestamp for actual dt
    
    # Logging
    log_t::Vector{Float64}
    log_pose::Matrix{Float64}    # 6 × n_samples
    log_vel::Matrix{Float64}     # 6 × n_samples
    log_currents::Matrix{Float64}
    log_F_desired::Matrix{Float64}
    log_wrench::Matrix{Float64}
    log_power::Vector{Float64}
end

function DiagData6D(n_coils::Int)
    return DiagData6D(
        zeros(n_coils), zeros(6), zeros(6), zeros(6), zeros(6 * n_coils),
        zeros(6), 0.0,
        Float64[], zeros(6,0), zeros(6,0), zeros(n_coils,0),
        zeros(6,0), zeros(6,0), Float64[]
    )
end

# =============================================================================
# Control & Diagnostics Callback
# =============================================================================

"""
    control_and_log_callback(diag, params, n_coils)

Creates a DiscreteCallback that:
1. Runs the 6-axis PID controller at every ODE step (5 kHz)
2. Logs data for analysis

The ODE step rate matches the control rate (both 5 kHz), so every step
triggers a control update. The controller runs BEFORE the logging to ensure
i_desired is updated for the next step.
"""
function control_and_log_callback(diag::DiagData6D, params::Lev6DParams, n_coils::Int)
    condition = (u, t, integrator) -> true
    
    affect! = function(integrator)
        u = integrator.u
        t = integrator.t
        p = integrator.p
        N = n_coils
        
        # ── 1. Control update ──────────────────────────────────────────
        params_c = p[1]::Lev6DParams
        coils_c = p[2]::Vector{CoilGeometry}
        ctrl_c = p[3]  # = diag
        
        x, y, z, roll, pitch, yaw = u[1:6]
        vx, vy, vz, ωx, ωy, ωz = u[7:12]
        
        dt = t - ctrl_c.last_t
        if dt <= 0.0
            dt = 1.0 / params_c.ctrl_rate
        end
        ctrl_c.last_t = t
        
        i_desired, e_int_new, F_desired, F_bias_wrench, A_mat =
            pid_control_6d(x, y, z, roll, pitch, yaw,
                           vx, vy, vz, ωx, ωy, ωz,
                           ctrl_c.e_int, coils_c, params_c, dt)
        
        copy!(ctrl_c.e_int, e_int_new)
        copy!(ctrl_c.i_desired, i_desired)
        copy!(ctrl_c.F_desired, F_desired)
        copy!(ctrl_c.F_bias_wrench, F_bias_wrench)
        flat_A = vec(A_mat)
        copy!(ctrl_c.A_mat, flat_A)
        
        # ── 2. Log data ────────────────────────────────────────────────
        currents = u[13:12+N]
        P_copper = sum(currents.^2) * params_c.R_wire
        P_total = P_copper + 2.0
        
        push!(ctrl_c.log_t, t)
        ctrl_c.log_pose = hcat(ctrl_c.log_pose, u[1:6])
        ctrl_c.log_vel = hcat(ctrl_c.log_vel, u[7:12])
        ctrl_c.log_currents = hcat(ctrl_c.log_currents, currents)
        ctrl_c.log_F_desired = hcat(ctrl_c.log_F_desired, ctrl_c.F_desired)
        ctrl_c.log_wrench = hcat(ctrl_c.log_wrench, ctrl_c.wrench)
        push!(ctrl_c.log_power, P_total)
    end
    
    return DiscreteCallback(condition, affect!, save_positions=(false, false))
end

# =============================================================================
# Simulation Runner
# =============================================================================

"""
    run_6dof_simulation(params; duration=1.0, disturbances=nothing, verbose=true)

Run 6-DOF levitation simulation.

# Disturbances
Tuple of 6 functions (fx, fy, fz, tx, ty, tz) or nothing for zero.
"""
function run_6dof_simulation(params::Lev6DParams;
                             duration::Float64=1.0,
                             disturbances::Union{Nothing,Tuple}=nothing,
                             verbose::Bool=true)
    
    N = params.n_coils
    coils = build_coils(params)
    
    # Initial state: small offsets to excite transients
    x0 = 0.0002      # 0.2 mm x-offset
    y0 = 0.0002      # 0.2 mm y-offset
    z0 = params.z_target * 0.995  # 0.5% below target
    roll0 = 0.001    # 1 mrad roll
    pitch0 = -0.001  # -1 mrad pitch
    yaw0 = 0.001     # 1 mrad yaw
    
    vx0, vy0, vz0 = 0.0, 0.0, 0.0
    ωx0, ωy0, ωz0 = 0.0, 0.0, 0.0
    
    currents0 = zeros(N)
    
    # Full state vector (e_int stored in ctrl, not in ODE state)
    u0 = [x0, y0, z0, roll0, pitch0, yaw0,
          vx0, vy0, vz0, ωx0, ωy0, ωz0,
          currents0...]
    
    # Disturbance functions (default: zero)
    default_zero(t) = 0.0
    dfx = disturbances !== nothing ? disturbances[1] : default_zero
    dfy = disturbances !== nothing ? disturbances[2] : default_zero
    dfz = disturbances !== nothing ? disturbances[3] : default_zero
    dtx = disturbances !== nothing ? disturbances[4] : default_zero
    dty = disturbances !== nothing ? disturbances[5] : default_zero
    dtz = disturbances !== nothing ? disturbances[6] : default_zero
    
    # Diagnostic container
    diag = DiagData6D(N)
    
    # Parameters for ODE
    p = [params, coils, diag, dfx, dfy, dfz, dtx, dty, dtz]
    
    tspan = (0.0, duration)
    
    # Combined control + logging callback (fires at every ODE step = 5 kHz)
    # The step rate matches the control rate, so every step triggers a
    # PID update followed by data logging.
    cb = control_and_log_callback(diag, params, N)
    
    # Solve using fixed-step Tsit5 at control rate (5 kHz)
    # The controller runs in the DiscreteCallback (control_and_log_callback),
    # not in the ODE function. The dynamics_6d! function only computes
    # physical derivatives. This avoids the timing corruption that plagued
    # the adaptive integration approach.
    dt_fixed = 1.0 / params.ctrl_rate
    prob = ODEProblem(dynamics_6d!, u0, tspan, p)
    sol = solve(prob,
                Tsit5(),
                dt=dt_fixed,
                adaptive=false,
                callback=cb,
                save_start=false,
                save_end=false,
                save_everystep=false,
                maxiters=Int(1e8))
    
    # Compute metrics
    metrics = compute_metrics_6d(diag, params, duration)
    
    result = Dict(
        :diag => diag,
        :params => params,
        :coils => coils,
        :sol => sol,
        :metrics => metrics
    )
    
    if verbose
        print_6dof_metrics(metrics, params)
    end
    
    return result
end

# =============================================================================
# Metrics
# =============================================================================

function compute_metrics_6d(diag::DiagData6D, params::Lev6DParams, duration::Float64)
    N = length(diag.log_t)
    
    if N < 10
        return Dict(:error => "Insufficient data")
    end
    
    # Steady-state (last 20%)
    ss_start = max(1, round(Int, 0.8 * N))
    idxs = ss_start:N
    
    pose_ss = diag.log_pose[:, idxs]
    vel_ss = diag.log_vel[:, idxs]
    currents_ss = diag.log_currents[:, idxs]
    power_ss = diag.log_power[idxs]
    wrench_ss = diag.log_wrench[:, idxs]
    
    # Target pose
    targets = [params.x_target, params.y_target, params.z_target,
               params.roll_target, params.pitch_target, params.yaw_target]
    
    # Per-axis errors (RMS)
    errors_rms = zeros(6)
    for i in 1:6
        errors_rms[i] = sqrt(mean((pose_ss[i, :] .- targets[i]).^2))
    end
    
    # Decoupling: how much does X command disturb Y?
    # For now: correlation of pose deviations
    cov_matrix = cov(pose_ss')
    decoupling = zeros(6)
    for i in 1:6
        # Off-diagonal coupling: mean of |cov(i,j)/cov(i,i)| for j≠i
        off_diag = 0.0
        count = 0
        for j in 1:6
            if j != i && abs(cov_matrix[i,i]) > 1e-15
                off_diag += abs(cov_matrix[i,j] / sqrt(abs(cov_matrix[i,i] * cov_matrix[j,j])))
                count += 1
            end
        end
        decoupling[i] = count > 0 ? off_diag / count : 0.0
    end
    
    # Power
    P_mean = mean(power_ss)
    P_peak = maximum(power_ss)
    P_gen = params.P_AFPM_nominal * params.η_gen
    
    # Settling time (z-axis as primary)
    z_error = abs.(diag.log_pose[3, :] .- params.z_target)
    z_thresh = 0.02 * params.z_target
    settling_idx = findlast(z_error .> z_thresh)
    settling_time = settling_idx === nothing ? 0.0 :
                    (settling_idx < length(diag.log_t) ? diag.log_t[settling_idx+1] :
                     diag.log_t[end])
    
    return Dict(
        :errors_rms => errors_rms,
        :decoupling => decoupling,
        :P_mean => P_mean,
        :P_peak => P_peak,
        :P_gen => P_gen,
        :self_powered => P_gen > P_mean,
        :settling_time => settling_time,
        :cov_matrix => cov_matrix,
        :N_samples => N
    )
end

function print_6dof_metrics(metrics::Dict, params::Lev6DParams)
    println("─"^70)
    println("  6-DOF Levitation — Metrics")
    println("─"^70)
    
    axis_names = ["X (m)", "Y (m)", "Z (m)", "Roll (rad)", "Pitch (rad)", "Yaw (rad)"]
    
    @printf("  Settling time (Z):   %.4f s\n", metrics[:settling_time])
    println()
    println("  Axis errors (RMS):")
    for i in 1:6
        @printf("    %-15s  %8.2e  (%.2f μm/μrad)\n",
                axis_names[i], metrics[:errors_rms][i],
                metrics[:errors_rms][i] * (i <= 3 ? 1e6 : 1e6))
    end
    
    println()
    println("  Axis decoupling (lower = better):")
    for i in 1:6
        @printf("    %-15s  %.3f  (0 = perfect)\n",
                axis_names[i], metrics[:decoupling][i])
    end
    
    println()
    @printf("  Power (avg):        %.2f W\n", metrics[:P_mean])
    @printf("  Power (peak):       %.2f W\n", metrics[:P_peak])
    @printf("  Generator output:   %.1f W\n", metrics[:P_gen])
    if metrics[:self_powered]
        println("  ✓ SELF-POWERED: Generator meets demand")
    else
        println("  ✗ NOT self-powered")
    end
    println("─"^70)
end

# =============================================================================
# Disturbance Test Helpers
# =============================================================================

"""
    step_disturbance_6d(params; amplitude=10.0, t_step=0.5, duration=2.0, axis=3)

Apply step disturbance on specified axis (1-6).
"""
function step_disturbance_6d(params::Lev6DParams;
                              amplitude::Float64=10.0,
                              t_step::Float64=0.5,
                              duration::Float64=2.0,
                              axis::Int=3)  # default: z-axis
    
    dists = [let a=axis, amp=amplitude, ts=t_step
                 t -> t >= ts ? (a == i ? amp : 0.0) : 0.0
             end for i in 1:6]
    
    return run_6dof_simulation(params, duration=duration,
                                disturbances=tuple(dists...), verbose=true)
end

"""
    sinusoidal_disturbance_6d(params; amplitude=5.0, freq=5.0, duration=3.0, axis=3)

Apply sinusoidal disturbance on specified axis.
"""
function sinusoidal_disturbance_6d(params::Lev6DParams;
                                    amplitude::Float64=5.0,
                                    freq::Float64=5.0,
                                    duration::Float64=3.0,
                                    axis::Int=3)
    dists = [let a=axis, amp=amplitude, f=freq
                 t -> t >= 0.5 ? amp * sin(2π * f * (t - 0.5)) *
                                (a == i ? 1.0 : 0.0) : 0.0
             end for i in 1:6]
    
    return run_6dof_simulation(params, duration=duration,
                                disturbances=tuple(dists...), verbose=true)
end

# =============================================================================
# Plotting
# =============================================================================

function plot_6dof_results(result::Dict; title="6-DOF Levitation")
    diag = result[:diag]
    params = result[:params]
    
    t = diag.log_t
    pose = diag.log_pose
    currents = diag.log_currents
    
    axis_labels = ["X (m)", "Y (m)", "Z (m)",
                   "Roll (rad)", "Pitch (rad)", "Yaw (rad)"]
    targets = [params.x_target, params.y_target, params.z_target,
               params.roll_target, params.pitch_target, params.yaw_target]
    
    # Convert to mm/mrad for display
    scale = [1e3, 1e3, 1e3, 1e3, 1e3, 1e3]
    unit = ["mm", "mm", "mm", "mrad", "mrad", "mrad"]
    
    # Position plots (3×2 grid)
    plts = []
    for i in 1:6
        p = plot(t, pose[i, :] .* scale[i],
                 xlabel="Time (s)", ylabel=unit[i],
                 title=axis_labels[i], legend=false, lw=1.5)
        hline!([targets[i] * scale[i]], ls=:dash, lw=1, color=:red, label="Target")
        push!(plts, p)
    end
    
    # Current plot
    p_cur = plot(xlabel="Time (s)", ylabel="Current (A)",
                 title="Coil Currents", lw=1.5)
    for j in 1:params.n_coils
        plot!(t, currents[j, :], label="Coil $j")
    end
    push!(plts, p_cur)
    
    # Power plot
    p_pwr = plot(t, diag.log_power,
                 xlabel="Time (s)", ylabel="Power (W)",
                 title="Total Power Consumption", legend=false, lw=1.5)
    P_gen = params.P_AFPM_nominal * params.η_gen
    hline!([P_gen], ls=:dash, lw=1.5, color=:green, label="Gen output")
    push!(plts, p_pwr)
    
    # Arrange in 4×2 grid
    plot(plts..., layout=(4, 2), size=(1400, 1000), plot_title=title)
end

end # module
