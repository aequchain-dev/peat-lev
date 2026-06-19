"""
    LevitationSim — 1-DOF Magnetic Levitation Simulation

Phase 1 of the calibrated electromagnetic levitation framework.
Closed-loop PWM current regulation + PM bias + PID position control.

# Model
- 1 DOF (vertical Z)
- Permanent magnet bias field + electromagnetic coil
- PWM current regulator (not voltage-source)
- PID position controller
- IMU + Hall sensor feedback (simulated)
- Power budget tracking

# Usage
    include("scripts/phase1_hover.jl")
"""
module LevitationSim

using DifferentialEquations
using LinearAlgebra
using Parameters
using Plots
using Printf
using Statistics

export LevParams, LevState
export levitation_dynamics!
export PWMCurrentRegulator, regulate_current!
export PIDController, compute_control!
export PowerBudget, update_power!
export run_simulation, plot_results, hover_metrics
export disturbance_rejection_test, power_sweep

# =============================================================================
# Physical Constants
# =============================================================================

const μ0 = 4π * 1e-7      # Vacuum permeability [H/m]
const g₀ = 9.80665         # Standard gravity [m/s²]

# =============================================================================
# Parameter Structure
# =============================================================================

@with_kw mutable struct LevParams
    # ── Mechanical ────────────────────────────────────────────────────────
    m::Float64 = 5.0               # Platform mass [kg]
    z_target::Float64 = 0.010      # Target hover gap [m]
    
    # ── PM Bias Actuator ──────────────────────────────────────────────────
    # Uses a lumped-parameter model: 
    #   F_em(z, i) = F_bias × (z_ref / z)^n + k_i × i
    # where PM provides the bias force and coil modulates around it.
    # This is the standard model for PM-biased electromagnetic actuators
    # (magnetic bearings, ASML wafer stages, maglev trains).
    #
    # F_bias: PM attractive force at reference gap [N]
    # n:      Field decay exponent (~2-3 for realistic PM geometry)
    # k_i:    Force per ampere coefficient [N/A]
    F_bias::Float64 = 50.0         # PM bias force at reference gap ≈ mg [N]
    n_exp::Float64 = 2.5           # PM field decay exponent
    k_i::Float64 = 10.0            # Force per ampere [N/A]
    
    # ── Coil Electrical ───────────────────────────────────────────────────
    L_coil::Float64 = 0.002        # Coil inductance [H]
    R_wire::Float64 = 0.5          # Coil resistance [Ω]
    I_max::Float64 = 10.0          # Maximum current [A]
    
    # ── PWM Drive ─────────────────────────────────────────────────────────
    V_bus::Float64 = 100.0         # DC bus voltage [V]
    f_pwm::Float64 = 20_000.0      # PWM carrier frequency [Hz]
    
    # ── Control ───────────────────────────────────────────────────────────
    Kp::Float64 = 8000.0           # Proportional gain [N/m]
    Ki::Float64 = 500.0            # Integral gain [N/(m·s)]
    Kd::Float64 = 300.0            # Derivative gain [N/(m/s)]
    ctrl_rate::Float64 = 5000.0    # Control loop rate [Hz]
    
    # ── AFPM Generator ────────────────────────────────────────────────────
    P_AFPM_nominal::Float64 = 250.0  # AFPM generator nominal output [W]
    η_gen::Float64 = 0.85            # Generator efficiency
    
    # ── Sensor ────────────────────────────────────────────────────────────
    σ_z::Float64 = 5e-6           # Position sensor noise (std) [m]
    σ_v::Float64 = 0.005          # Velocity sensor noise (std) [m/s]
    z_quantum::Float64 = 1e-6     # Position quantization [m]
end

# =============================================================================
# State Structure
# =============================================================================

mutable struct LevState
    # Continuous state (for ODE solver)
    z::Float64          # Position [m] (positive = away from coil)
    v::Float64          # Velocity [m/s]
    i::Float64          # Coil current [A]
    
    # Control state
    e_int::Float64      # Integral of position error [m·s]
    i_cmd::Float64      # Commanded current [A]
    duty::Float64       # PWM duty cycle [-1, 1]
    
    # Power tracking (time-integrated)
    t::Float64          # Current simulation time [s]
    E_elec::Float64     # Total electrical energy consumed [J]
    E_mech::Float64     # Total mechanical work done [J]
    E_gen::Float64      # Total generator energy harvested [J]
    P_avg::Float64      # Running average power [W]
    P_peak::Float64     # Peak power [W]
    
    # Data logging
    log_t::Vector{Float64}
    log_z::Vector{Float64}
    log_v::Vector{Float64}
    log_i::Vector{Float64}
    log_i_cmd::Vector{Float64}
    log_duty::Vector{Float64}
    log_F_em::Vector{Float64}
    log_P_elec::Vector{Float64}
    log_P_gen::Vector{Float64}
end

function LevState(params::LevParams)
    z0 = params.z_target  # Start at target position
    return LevState(
        z0, 0.0, 0.0,  # z, v, i
        0.0, 0.0, 0.0,  # e_int, i_cmd, duty
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,  # t, E_elec, E_mech, E_gen
        0.0, 0.0,  # P_avg, P_peak
        [0.0], [z0], [0.0], [0.0], [0.0], [0.0], [0.0], [0.0], [0.0]  # logs
    )
end

# =============================================================================
# Electromagnetic Force Model
# =============================================================================

"""
    compute_F_em(z, i, params)

Electromagnetic force at gap z with coil current i [N].
Positive = upward (repulsive, lifting platform away from base).

Uses a lumped-parameter PM-biased actuator model:
    F_em(z, i) = F_bias × (z_ref / z)^n + k_i × i

This captures two physical effects:
1. **PM bias**: A permanent magnet configuration (e.g., like poles facing)
   produces a repulsive force at the target gap. F_bias ≈ mg balances gravity
   at hover. Field decays as 1/z^n (n ≈ 2–3 for practical geometries).
   
2. **Coil modulation**: Current in the coil adds to or subtracts from the
   net field, modulating the force linearly (coil operates in the "small
   signal" regime around the PM bias). k_i ≈ 5–15 N/A is typical.

This model is standard for PM-biased electromagnetic actuators in maglev
systems, magnetic bearings, and precision positioning stages
(e.g., ASML wafer stages).
"""
function compute_F_em(z::Float64, i::Float64, params::LevParams)
    z_ref = params.z_target
    F_bias = params.F_bias       # Repulsive bias at reference gap [N]
    n = params.n_exp             # Field decay exponent
    k_i = params.k_i             # Force per ampere [N/A]
    
    # Normalized gap ratio (protect against z → 0)
    ζ = max(z / z_ref, 0.01)    # Clamp at 1% of reference
    
    # PM bias force at this gap (repulsive = positive)
    F_bias_z = F_bias * (1.0 / ζ)^n
    
    # Coil modulation (linear in current)
    F_coil = k_i * i  # positive i → more repulsive force
    
    return F_bias_z + F_coil  # Total EM force, upward positive
end

"""
    compute_back_emf(v, params)

Back-EMF voltage induced in the coil by platform motion [V].
By conservation of energy in the electromechanical coupling:
    P_mech = F × v = V_bemf × i  →  V_bemf = k_i × v
(since F = k_i × i for the coil contribution).
"""
compute_back_emf(v::Float64, params::LevParams) = params.k_i * v

# =============================================================================
# ODE Dynamics
# =============================================================================

"""
    levitation_dynamics!(du, u, params, t)

Compute derivatives for the 1-DOF levitation system.
u = [z, v, i, e_int]

States:
- z: position [m]
- v: velocity [m/s]
- i: coil current [A]
- e_int: integral of position error [m·s]
"""
function levitation_dynamics!(du, u, p, t)
    params = p[1]
    controller = p[2]
    
    z, v, i, e_int = u
    
    # ── 1. Compute electromagnetic force ─────────────────────────────────
    F_em = compute_F_em(z, i, params)
    
    # ── 2. Compute back-EMF ───────────────────────────────────────────────
    V_bemf = compute_back_emf(v, params)
    
    # ── 3. PID position controller ──────────────────────────────────────
    # Control law: compute desired force from position error
    e = z - params.z_target  # Position error [m]
    
    # Update integral (with anti-windup)
    e_int_new = e_int + e / params.ctrl_rate
    # Anti-windup: clamp integral contribution to ±50% of F_bias
    max_int = 0.5 * params.F_bias / params.Ki
    e_int_new = clamp(e_int_new, -max_int, max_int)
    
    # PID control law → desired incremental force
    # Negative sign: if z > z_target (too high), we need less upward force
    F_incr = -(params.Kp * e + params.Ki * e_int_new + params.Kd * v)
    F_incr = clamp(F_incr, -0.8 * params.F_bias, 0.8 * params.F_bias)
    
    # Desired total electromagnetic force
    F_desired = params.F_bias + F_incr  # Bias + correction
    
    # Force → current (linear relationship in PM-biased actuator)
    # F_em(z, i) = F_bias × (z_ref / z)^n + k_i × i
    # Solve i from F_desired (using F_bias(z) as the position-dependent bias):
    ζ_i = max(z / params.z_target, 0.02)
    F_bias_at_z = params.F_bias * (1.0 / ζ_i)^params.n_exp
    i_desired = (F_desired - F_bias_at_z) / params.k_i
    i_desired = clamp(i_desired, -params.I_max, params.I_max)
    
    # ── 4. Current dynamics ──────────────────────────────────────────────
    # L × di/dt = V_applied - R × i - V_bemf
    # Simplified: assume current regulator is much faster than mechanical dynamics
    # Use a first-order lag with time constant τ_i = L_coil / R_gain
    
    τ_i = 0.0002  # Current loop time constant [s] (5 kHz bandwidth)
    di_dt = (i_desired - i) / τ_i
    di_dt = clamp(di_dt, -1e6, 1e6)  # Numerical protection
    
    # ── 5. Mechanical dynamics ───────────────────────────────────────────
    # Net force = EM force - gravity
    # F_em = total EM force (already computed above)
    F_em_actual = compute_F_em(z, i, params)  # Recompute with actual i for accuracy
    dv_dt = (F_em_actual - params.m * g₀) / params.m
    
    dz_dt = v
    de_int_dt = e
    
    # ── 6. Store results ─────────────────────────────────────────────────
    du[1] = dz_dt
    du[2] = dv_dt
    du[3] = di_dt
    du[4] = de_int_dt
    
    # Store diagnostic info in controller
    controller.i_cmd = i_desired
    controller.duty = clamp(i / params.I_max, -1.0, 1.0)  # Normalized current
    controller.F_em = F_em_actual
    # Electrical power: P = I² × R + switching losses
    controller.P_elec = i^2 * params.R_wire + 0.5
    controller.P_mech = F_em_actual * v
    controller.V_bemf = V_bemf
    return nothing
end

# =============================================================================
# Controller State (for storing diagnostic info during ODE solve)
# =============================================================================

mutable struct ControllerState
    i_cmd::Float64
    duty::Float64
    F_em::Float64
    P_elec::Float64
    P_mech::Float64
    V_bemf::Float64
end

function ControllerState()
    return ControllerState(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

# =============================================================================
# Callback for data logging
# =============================================================================

function make_log_callback(results)
    """
    Returns a DiscreteCallback that logs state at fixed intervals.
    """
    log_dt = 1.0 / 5000.0  # Log at 5 kHz
    
    # Store logging data in a mutable container
    data = Dict(
        :t => Float64[],
        :z => Float64[],
        :v => Float64[],
        :i => Float64[],
        :i_cmd => Float64[],
        :duty => Float64[],
        :F_em => Float64[],
        :P_elec => Float64[],
        :V_bemf => Float64[],
        :e_int => Float64[]
    )
    results[:log] = data
    
    condition = (u, t, integrator) -> true  # Always trigger
    affect! = function(integrator)
        z, v, i, e_int = integrator.u
        push!(data[:t], integrator.t)
        push!(data[:z], z)
        push!(data[:v], v)
        push!(data[:i], i)
        push!(data[:i_cmd], integrator.p[2].i_cmd)
        push!(data[:duty], integrator.p[2].duty)
        push!(data[:F_em], integrator.p[2].F_em)
        push!(data[:P_elec], integrator.p[2].P_elec)
        push!(data[:V_bemf], integrator.p[2].V_bemf)
        push!(data[:e_int], e_int)
    end
    
    return DiscreteCallback(condition, affect!, save_positions=(false, false))
end

# =============================================================================
# Simulation Runner
# =============================================================================

"""
    run_simulation(params; duration=1.0, disturbance=nothing, verbose=true)

Run 1-DOF levitation simulation.

# Arguments
- `params::LevParams`: System parameters
- `duration::Float64`: Simulation duration [s]
- `disturbance::Function`: External force disturbance f(t) [N], optional
- `verbose::Bool`: Print progress and metrics

# Returns
Dict with keys:
- :z, :v, :i, :t: State trajectories
- :F_em, :P_elec, :V_bemf: Diagnostic trajectories
- :metrics: Summary metrics
"""
function run_simulation(params::LevParams; 
                         duration::Float64=1.0, 
                         disturbance::Union{Nothing,Function}=nothing,
                         verbose::Bool=true)
    
    # Initial state
    z0 = params.z_target * 0.99  # Slight offset from target to excite transient
    v0 = 0.0
    i0 = 0.0
    e_int0 = 0.0
    u0 = [z0, v0, i0, e_int0]
    
    # Controller state
    controller = ControllerState()
    
    # Parameters for ODE
    p = [params, controller]
    
    # Time span
    tspan = (0.0, duration)
    
    # ODE function with optional disturbance
    if disturbance === nothing
        plant_dynamics = (du, u, p, t) -> levitation_dynamics!(du, u, p, t)
    else
        function plant_dynamics_with_dist!(du, u, p, t)
            levitation_dynamics!(du, u, p, t)
            du[2] += disturbance(t) / params.m  # Add disturbance force / mass
            return nothing
        end
        plant_dynamics = plant_dynamics_with_dist!
    end
    
    # Results container for callback
    results = Dict{Symbol,Any}()
    log_cb = make_log_callback(results)
    
    # Solve ODE
    prob = ODEProblem(plant_dynamics, u0, tspan, p)
    sol = solve(prob, 
                Tsit5(), 
                reltol=1e-6, 
                abstol=1e-8,
                callback=log_cb,
                save_start=false,  # We use the callback for logging
                save_end=false,
                save_everystep=false,
                maxiters=1e7)
    
    # Add solution to results
    results[:sol] = sol
    
    # Compute metrics
    metrics = compute_metrics(results, params, duration)
    results[:metrics] = metrics
    
    if verbose
        print_metrics(metrics, params)
    end
    
    # Store params for plotting
    results[:params] = params
    
    # Store params for plotting/analysis
    results[:params] = params
    
    return results
end

# =============================================================================
# Metrics
# =============================================================================

function compute_metrics(results::Dict, params::LevParams, duration::Float64)
    log = results[:log]
    
    # Extract arrays
    t = log[:t]
    z = log[:z]
    v = log[:v]
    i = log[:i]
    i_cmd = log[:i_cmd]
    F_em = log[:F_em]
    P_elec = log[:P_elec]
    
    # Steady-state (last 20% of simulation)
    n_ss_start = max(1, round(Int, 0.8 * length(t)))
    z_ss = z[n_ss_start:end]
    v_ss = v[n_ss_start:end]
    i_ss = i[n_ss_start:end]
    P_elec_ss = P_elec[n_ss_start:end]
    
    # Settling time: time when error stays within ±2% of target
    error = abs.(z .- params.z_target)
    error_threshold = 0.02 * params.z_target
    settling_idx = findlast(error .> error_threshold)
    settling_time = settling_idx === nothing ? 0.0 : (settling_idx < length(t) ? t[settling_idx+1] : t[end])
    
    return Dict(
        :settling_time => settling_time,
        :z_mean => mean(z_ss),
        :z_std => std(z_ss),
        :z_error_mean => mean(z_ss) - params.z_target,
        :z_error_rms => sqrt(mean((z_ss .- params.z_target).^2)),
        :v_rms => sqrt(mean(v_ss.^2)),
        :i_mean => mean(i_ss),
        :i_rms => sqrt(mean(i_ss.^2)),
        :i_tracking_error_rms => sqrt(mean((i_ss .- i_cmd[n_ss_start:end]).^2)),
        :P_elec_mean => mean(P_elec_ss),
        :P_elec_max => maximum(P_elec_ss),
        :F_em_mean => mean(F_em[n_ss_start:end]),
        :mg => params.m * g₀,
        :duration => duration
    )
end

function print_metrics(metrics::Dict, params::LevParams)
    println("─"^60)
    println("  Phase 1 — 1-DOF Levitation: Metrics")
    println("─"^60)
    @printf("  Settling time:       %8.4f s\n", metrics[:settling_time])
    @printf("  Position error (avg): %+.3e m\n", metrics[:z_error_mean])
    @printf("  Position error (RMS): %8.3e m\n", metrics[:z_error_rms])
    @printf("  Velocity (RMS):       %8.4f m/s\n", metrics[:v_rms])
    @printf("  Coil current (avg):   %8.3f A\n", metrics[:i_mean])
    @printf("  Coil current (RMS):   %8.3f A\n", metrics[:i_rms])
    @printf("  EM force (avg):       %8.2f N (mg = %.2f N)\n", metrics[:F_em_mean], metrics[:mg])
    @printf("  Power (avg):          %8.2f W\n", metrics[:P_elec_mean])
    @printf("  Power (peak):         %8.2f W\n", metrics[:P_elec_max])
    
    # Power budget
    P_gen = params.P_AFPM_nominal * params.η_gen
    @printf("  Generator output:     %8.2f W\n", P_gen)
    @printf("  Net power margin:     %8.2f W\n", P_gen - metrics[:P_elec_mean])
    if P_gen > metrics[:P_elec_mean]
        println("  ✓ SELF-POWERED: Generator meets demand")
    else
        println("  ✗ NOT self-powered: Gen = $(round(P_gen, digits=1)) W < $(round(metrics[:P_elec_mean], digits=1)) W")
    end
    println("─"^60)
end

# =============================================================================
# Plotting
# =============================================================================

function plot_results(results::Dict; title="1-DOF Levitation")
    log = results[:log]
    metrics = results[:metrics]
    params = results[:params]
    
    t = log[:t]
    
    p1 = plot(t, log[:z] .* 1000, 
              xlabel="Time (s)", ylabel="Position (mm)",
              title="Z Position", legend=false, lw=1.5)
    hline!([params.z_target * 1000], ls=:dash, lw=1, color=:red, label="Target")
    
    p2 = plot(t, log[:v],
              xlabel="Time (s)", ylabel="Velocity (m/s)",
              title="Velocity", legend=false, lw=1.5)
    
    p3 = plot(t, log[:i],
              xlabel="Time (s)", ylabel="Current (A)",
              title="Coil Current", legend=false, lw=1.5)
    plot!(t, log[:i_cmd], ls=:dash, lw=1, color=:orange, label="Command")
    
    p4 = plot(t, log[:P_elec],
              xlabel="Time (s)", ylabel="Power (W)",
              title="Power Consumption", legend=false, lw=1.5)
    
    p5 = plot(t, log[:F_em],
              xlabel="Time (s)", ylabel="Force (N)",
              title="EM Force", legend=false, lw=1.5)
    hline!([params.m * g₀], ls=:dash, lw=1, color=:red, label="mg")
    
    p6 = plot(t, log[:V_bemf],
              xlabel="Time (s)", ylabel="Voltage (V)",
              title="Back-EMF", legend=false, lw=1.5)
    
    plot(p1, p2, p3, p4, p5, p6, layout=(3,2), size=(1200, 800), 
         plot_title=title)
end

# =============================================================================
# Disturbance Rejection Test
# =============================================================================

"""
    disturbance_rejection_test(params; amplitude=10.0, duration=2.0)

Apply step disturbance force and measure recovery.
"""
function disturbance_rejection_test(params::LevParams; 
                                     amplitude::Float64=10.0,
                                     duration::Float64=2.0)
    
    # Step disturbance at t = 0.5 s
    disturbance(t) = t >= 0.5 ? amplitude : 0.0
    
    results = run_simulation(params, duration=duration, disturbance=disturbance, verbose=true)
    results[:params] = params
    results[:disturbance] = amplitude
    
    return results
end

# =============================================================================
# Power Budget Sweep
# =============================================================================

"""
    power_sweep(params; masses=1.0:1.0:20.0, z_gaps=[0.005, 0.010, 0.015, 0.020])

Sweep mass and gap to find self-powering envelope.
"""
function power_sweep(params::LevParams; 
                      masses::AbstractVector=1.0:1.0:20.0,
                      z_gaps::AbstractVector=[0.005, 0.010, 0.015, 0.020],
                      duration::Float64=0.5)
    
    P_gen = params.P_AFPM_nominal * params.η_gen
    
    results_matrix = zeros(length(masses), length(z_gaps))
    
    println("─"^70)
    println("  Power Budget Sweep")
    println("─"^70)
    @printf("  Generator output: %.1f W\n", P_gen)
    println("  Mass → P_elec / P_gen at each gap:")
    println("─"^70)
    @printf("  %-8s", "Mass(kg)")
    for z_g in z_gaps
        @printf("  %-12s", string("z=", round(Int, z_g*1000), "mm"))
    end
    println()
    
    for (im, m) in enumerate(masses)
        p = deepcopy(params)
        p.m = m
        
        @printf("  %-8.0f", m)
        for (iz, z_g) in enumerate(z_gaps)
            p.z_target = z_g
            r = run_simulation(p, duration=duration, verbose=false)
            mets = r[:metrics]
            P_ratio = mets[:P_elec_mean] / max(P_gen, 1e-10)
            results_matrix[im, iz] = P_ratio
            @printf("  %-6s", P_ratio < 1.0 ? "✓$(round(P_ratio*100))%" : "✗$(round(P_ratio*100))%")
        end
        println()
    end
    println("─"^70)
    
    return (masses=masses, gaps=z_gaps, ratios=results_matrix, P_gen=P_gen)
end

# Export commonly used items
export LevParams, LevState, compute_F_em, compute_back_emf,
       levitation_dynamics!, run_simulation, disturbance_rejection_test,
       power_sweep, plot_results, print_metrics

end # module
