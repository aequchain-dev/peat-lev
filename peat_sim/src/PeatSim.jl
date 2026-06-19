"""
    PeatSim — Parametric Electro-Active Thruster Simulation

Julia implementation of the PEAT (Parametric Electro-Active Thruster)
coupled ODE model for electromagnetic oscillation-based levitation.

Extends the Python `peat_sim.py` analytical model with a performant
compiled ODE solver for large-scale parameter sweeps.

# Models
- `CoupledOscillator`: Single-axis electromagnetic oscillator pair
- `SixAxisSystem`: Full 6-oscillator 6-DOF system (translation + attitude)

# Usage
    using PeatSim
    params = OscillatorParams()  # default parameters
    sol = solve_oscillator(params; duration=1.0)
    plot_results(sol, params)
"""
module PeatSim

using DifferentialEquations
using LinearAlgebra
using Printf
using Parameters
using Statistics

export OscillatorParams, SixAxisParams, CoilDesign, CoilGeometry, make_coil
export solve_oscillator, solve_six_axis, six_axis_ode!
export analytical_sweep, compute_thrust, compute_power_balance, compute_six_axis_power
export plot_results, plot_sweep, plot_energy_balance
export run_demo, run_sweep, run_verification
export mechanical_energy, find_zero_crossings, energy_at_turning_points
export CycleFeasibilityResult, cycle_feasibility
export ODESweepConfig, ODESweepResult, run_ode_sweep
export coil_params, coil_geometry_sweep, GeometrySweepConfig, GeometrySweepResult
export summarize_geometry, plot_geometry_regimes
export compute_τ_t_half_ratio
export SixAxisState, SixAxisResult, six_axis_feasibility

# =============================================================================
# Physical Constants
# =============================================================================

const μ0 = 4π * 1e-7       # Vacuum permeability [H/m]
const g₀ = 9.80665          # Standard gravity [m/s²]

# =============================================================================
# Parameter Structures
# =============================================================================

"""
    OscillatorParams

Parameters for a single-axis electromagnetic oscillator pair.
"""
@with_kw mutable struct OscillatorParams
    # Mass configuration
    M_total::Float64 = 115.0       # Total vehicle mass [kg]
    m_osc::Float64 = 17.25         # Reaction mass per oscillator [kg]
    m_ratio::Float64 = 0.15        # m_osc / M_total

    # Mechanical parameters
    f_osc::Float64 = 15.0          # Oscillation frequency [Hz]
    ω_osc::Float64 = 2π * f_osc    # Angular frequency [rad/s]
    stroke::Float64 = 0.05         # Full stroke [m]
    amplitude::Float64 = 0.5 * stroke  # Half-stroke amplitude [m]
    k_spring::Float64 = m_osc * (ω_osc)^2  # Magnetic spring stiffness [N/m]

    # Electrical parameters
    R_coil::Float64 = 1.0          # Coil resistance [Ω]
    L_base::Float64 = 0.01         # Air-core (minimum) inductance [H]
    L_max::Float64 = 0.20          # Slug-centered (maximum) inductance [H]
    V_bus::Float64 = 48.0          # Bus voltage [V]

    # Inductance model — sigmoid L(x) = L_base + ΔL · (1 + tanh(x/δ_L))/2
    # δ_L ≈ coil length; ΔL = L_max − L_base; peak dL/dx = ΔL/(2·δ_L) at x = 0
    coil_length::Float64 = 0.05    # Physical coil length [m]; sets sigmoid width
    δ_L::Float64 = 0.05            # Sigmoid characteristic length [m]
    ΔL::Float64 = 0.0              # Total inductance variation [H]; set by init_params!
    dL_dx_peak::Float64 = 0.0      # Peak dL/dx at slug-edge [H/m]; set by init_params!
    # For analytical bound: same formula as linear model using peak dL/dx

    # Nonlinear inductance model — saturation
    # Effective permeability drops at high current: μ_eff(I) = μ_eff₀/(1 + I/I_sat)
    I_sat::Float64 = Inf           # Saturation current [A]; Inf = disabled

    # Drive parameters
    η_repel::Float64 = 0.20        # Repel fraction of cycle [0-1]
    t_attract::Float64 = 0.0       # Attract duration [s] (set by init_params!)
    t_repel::Float64 = 0.0         # Repel duration [s] (set by init_params!)
    t_coast::Float64 = 0.0         # Coast duration [s] (set by init_params!)
    t_half::Float64 = 0.0          # Half-period [s] (set by init_params!)

    # Initial conditions — mass starts at top of stroke (x₀ = amplitude, v₀ = 0)
    # This aligns the initial phase with the drive timing:
    #   • Half-cycle 1 (0 → t_half): mass near coil A → REPEL (V = -V_bus)
    #   • Half-cycle 2 (t_half → 2t_half): mass near coil B → ATTRACT (V = +V_bus)
    x₀::Float64 = 0.025            # Initial position [m] (top of stroke, near coil A)
    v₀::Float64 = 0.0              # Initial velocity [m/s]
    i₀::Float64 = 0.0              # Initial coil current [A]

    # Pickup coil parameters
    N_pickup::Int = 100            # Pickup coil turns
    A_pickup::Float64 = 0.01       # Pickup coil area [m²]
    B_pickup::Float64 = 0.5        # Magnetic field at pickup [T]
    d_rest::Float64 = 0.01         # Rest gap [m]
    R_load::Float64 = 10.0         # Load resistance [Ω]
    b_gen::Float64 = 0.0           # Generator damping coefficient
end

"""
    SixAxisParams

Parameters for the full 6-oscillator 6-DOF system.
"""
@with_kw mutable struct SixAxisParams
    # Base oscillator parameters
    osc_params::OscillatorParams = OscillatorParams()

    # Geometry — oscillators arranged in hexagon around center
    R_hex::Float64 = 0.5           # Hexagon radius [m]
    θ_offset::Float64 = 0.0        # Rotation offset [rad]

    # Initial conditions
    pos₀::Vector{Float64} = [0.0, 0.0, 0.0]     # Initial CoM position
    vel₀::Vector{Float64} = [0.0, 0.0, 0.0]     # Initial CoM velocity
    quat₀::Vector{Float64} = [1.0, 0.0, 0.0, 0.0]  # Initial orientation [w,x,y,z]
    ω_body₀::Vector{Float64} = [0.0, 0.0, 0.0]  # Initial angular velocity

    # Control: amplitude setpoints per oscillator [m]
    amp_setpoints::Vector{Float64} = fill(0.5 * 0.05, 6)
    # Control: phase offsets per oscillator [rad]
    phase_offsets::Vector{Float64} = zeros(6)
end

# =============================================================================
# Coil Geometry Model
# =============================================================================

"""
    CoilDesign

Physical geometry parameters for a single electromagnetic drive coil.
Converts winding geometry → R_coil, L_base, L_max via `coil_params()`.

The inductance variation (dL/dx) comes from a ferromagnetic reaction mass
moving through the coil. The effective permeability parameter
`μ_slug_effective` captures the combined effect of:
  • Slug material permeability (μ_r)
  • Demagnetization factor (geometry-dependent: L/D ratio)
  • Magnetic coupling fill factor

For a steel/iron slug with L/D ≈ 3–5, μ_slug_effective ≈ 10–40.
For an air-core (no reaction mass), μ_slug_effective = 1.0.
"""
@with_kw struct CoilDesign
    # Winding parameters
    n_turns::Int               = 100        # Number of turns per coil
    wire_diameter_mm::Float64  = 1.0        # Copper wire diameter [mm]
    mean_radius_m::Float64     = 0.05       # Mean coil radius [m]
    winding_length_m::Float64  = 0.05       # Axial length of winding [m]
    winding_build_m::Float64   = 0.015      # Radial build of winding [m]

    # Magnetic coupling — reaction mass characteristics
    μ_slug_effective::Float64  = 40.0       # Effective μ when slug is centered
    # (accounts for material μ_r × demagnetization × geometric fill)

    # Copper packing
    fill_factor::Float64       = 0.55       # Copper area / winding area ratio
end

"""
    coil_params(geom::CoilDesign; double_coil::Bool=true)

Convert winding geometry to electrical parameters [Ω, H].

# Returns
- `R_coil`: DC resistance per coil [Ω]
- `L_base`: Minimum inductance (slug far away) [H]
- `L_max`:  Maximum inductance (slug centered) [H]
- `R_total`: Effective drive resistance [Ω]; = 2×R_coil for push-pull

The R_total is 2× R_coil because the push-pull pair always has one
active coil in the circuit. For the analytical power model, this is
the effective resistance seen by the bus.
"""
function coil_params(geom::CoilDesign; double_coil::Bool=true)
    ρ_Cu = 1.68e-8  # Copper resistivity [Ω·m]

    # --- Per-turn wire cross-section ---
    r_wire = geom.wire_diameter_mm / 2000.0   # [m]
    A_wire = π * r_wire^2                     # Single-wire area [m²]

    # --- Effective wire area accounting for packing ---
    # Total winding cross-sectional area
    A_winding_total = geom.winding_length_m * geom.winding_build_m

    # Number of turns that fit at 100% packing (check for consistency)
    # We use the actual n_turns from the struct but verify fill_factor
    A_turns_total = geom.n_turns * A_wire
    max_possible_fill = A_turns_total / A_winding_total
    if max_possible_fill > geom.fill_factor
        # The wire wouldn't fit — adjust fill_factor to actual
        effective_fill = max_possible_fill
    else
        effective_fill = geom.fill_factor
    end

    # Effective copper area per turn
    A_eff_per_turn = effective_fill * A_winding_total / geom.n_turns

    # --- DC resistance ---
    total_wire_length = geom.n_turns * 2π * geom.mean_radius_m    # [m]
    R_coil = ρ_Cu * total_wire_length / A_eff_per_turn            # [Ω]

    # --- Inductance ---
    # Short solenoid approximation with Nagaoka correction
    A_coil = π * geom.mean_radius_m^2                              # [m²]
    k_Naga = 1.0 / (1.0 + 0.9 * (geom.mean_radius_m / geom.winding_length_m))
    # Nagaoka's coefficient: ~1 for ℓ >> a, ~0.5 for ℓ ≈ a

    L_air = μ0 * geom.n_turns^2 * k_Naga * A_coil / geom.winding_length_m  # [H]

    # Inductance when slug is far away (small residual coupling)
    L_base = L_air

    # Inductance when slug is centered (enhanced by effective permeability)
    L_max = L_air * geom.μ_slug_effective

    # Effective drive resistance (push-pull pair)
    R_total = double_coil ? 2.0 * R_coil : R_coil

    return (R_coil=R_coil, L_base=L_base, L_max=L_max, R_total=R_total)
end

"""
    coil_l_dldx(L_base, L_max, δ_coil)

Return sigmoid-model `(ΔL, dL_dx_peak)` from inductance bounds and
the coil's characteristic sigmoid width (typically `coil_length`).
"""
function coil_l_dldx(L_base::Float64, L_max::Float64, δ_coil::Float64)
    ΔL = L_max - L_base
    dL_dx_peak = ΔL / (2.0 * δ_coil)
    return (ΔL=ΔL, dL_dx_peak=dL_dx_peak)
end

# =============================================================================
# Initialization Helpers
# =============================================================================

"""
    init_params(; coil_geom=nothing, kwargs...)

Create OscillatorParams with computed timing fields. If a `CoilDesign`
is provided (`coil_geom=some_geometry`), the electrical parameters
R_coil, L_base, L_max are derived from the winding geometry,
overriding any direct R/L values in kwargs.
"""
function init_params(; coil_geom=nothing, kwargs...)
    # If geometry provided, derive electrical params first and merge
    if coil_geom !== nothing
        cp = coil_params(coil_geom)
        # Merge geometry-derived params, allowing explicit kwargs to override
        geom_kwargs = (
            R_coil=cp.R_coil,   # Per-coil resistance [Ω]
            L_base=cp.L_base,
            L_max=cp.L_max,
        )
        p = OscillatorParams(; geom_kwargs..., kwargs...)
    else
        p = OscillatorParams(; kwargs...)
    end

    # Drive timing
    p.t_half = 1.0 / (2 * p.f_osc)
    p.t_attract = p.t_half * (1 - p.η_repel)
    p.t_repel = p.t_half * p.η_repel
    p.t_coast = p.t_half - p.t_attract - p.t_repel  # Should be ~0 in practice

    # Inductance model derived quantities
    p.ΔL = p.L_max - p.L_base
    p.δ_L = p.coil_length
    p.dL_dx_peak = p.ΔL / (2.0 * p.δ_L)

    # Generator damping coefficient
    p.b_gen = (p.N_pickup * p.B_pickup * p.A_pickup / p.d_rest)^2 / p.R_load

    return p
end

# =============================================================================
# Drive State Machine
# =============================================================================

"""
    DriveState

State machine for coil drive waveform.
"""
@enum DriveState begin
    ATTRACT = 1     # Pull reaction mass toward coil (positive current)
    COAST_A = 2     # Coast after attract
    REPEL = 3       # Push reaction mass away (negative current)
    COAST_B = 4     # Coast after repel
end

"""
    drive_voltage(p, t, state, x, v)

Compute the applied voltage based on drive state.
"""
function drive_voltage(p::OscillatorParams, t, state::DriveState,
                       x, v)
    if state == ATTRACT
        # Pull mass toward coil: positive voltage
        return p.V_bus
    elseif state == REPEL
        # Push mass away: negative voltage
        return -p.V_bus
    else
        # Coast: zero voltage
        return 0.0
    end
end

"""
    get_drive_state(p, t, v)

Determine which drive state we're in based on velocity.

Velocity-referenced positive-feedback drive:
- Moving toward +x (v > 0): apply ATTRACT → pull toward +x → ACCELERATES mass
  (= injects energy). Active for t_attract seconds (default 26.7 ms), then coast.
- Moving toward -x (v < 0): apply REPEL → push toward -x → ACCELERATES mass
  (= injects energy). Active for t_repel seconds (default 6.7 ms), then coast.

Each state applies voltage to create positive feedback (force × velocity > 0),
pumping energy into the oscillation. The `t_half` timer resets the start
of the active window at every half-cycle boundary, ensuring both the
downward and upward strokes receive their respective drive pulses.
"""
function get_drive_state(p::OscillatorParams, t_cross, v)
    if v > 0.0
        # Moving toward +x → accelerate with ATTRACT (positive voltage)
        if t_cross < p.t_attract
            return ATTRACT
        else
            return COAST_A
        end
    else
        # Moving toward -x → accelerate with REPEL (negative voltage)
        if t_cross < p.t_repel
            return REPEL
        else
            return COAST_B
        end
    end
end

# =============================================================================
# Inductance Model
# =============================================================================

"""
    effective_L(p, x)

Compute inductance and gradient for both coils using the sigmoid model.

Model: L_A(x) = L_base + ΔL · (1 + tanh(x/δ_L))/2
       L_B(x) = L_base + ΔL · (1 + tanh(-x/δ_L))/2

The sigmoid is naturally bounded: L_base ≤ L ≤ L_max for all x.
No clamping needed — this is physically correct for a ferromagnetic
slug passing through a coil.

Returns (L_A, L_B, dL_A_dx, dL_B_dx).
"""
function effective_L(p, x)
    # Sigmoid factor s = tanh(x/δ_L) ∈ [-1, 1]
    s = tanh(x / p.δ_L)
    # sech²(x/δ_L) = 1 - tanh²(x/δ_L)
    sech2 = 1 - s * s

    L_A = p.L_base + 0.5 * p.ΔL * (1 + s)
    L_B = p.L_base + 0.5 * p.ΔL * (1 - s)

    # dL/dx = ΔL/(2·δ_L) · sech²(x/δ_L)  [for coil A]
    # dL_B/dx = -ΔL/(2·δ_L) · sech²(x/δ_L)  [negative of coil A]
    dL_A_dx = p.dL_dx_peak * sech2
    dL_B_dx = -p.dL_dx_peak * sech2

    return (L_A, L_B, dL_A_dx, dL_B_dx)
end

# =============================================================================
# ODE System — Single Oscillator Pair (4-state)
# =============================================================================

"""
    coupled_oscillator!(du, u, p, t)

Coupled ODE for one electromagnetic oscillator pair.

States:
    u[1] = i_A     — coil A current [A]
    u[2] = i_B     — coil B current [A]
    u[3] = x       — reaction mass position [m] (relative to center)
    u[4] = v       — reaction mass velocity [m/s]
    u[5] = t_cross — time since last velocity zero-crossing [s]

Note: The t_cross state is reset to 0 by a ContinuousCallback at every
velocity zero-crossing (v = 0), ensuring the drive timing tracks the
actual oscillation phase rather than a fixed timer.

Note: `p` here is the OscillatorParams, wrapped in a SciML `@unpack` pattern.
"""
function coupled_oscillator!(du, u, p::OscillatorParams, t)
    i_A, i_B, x, v, t_cross = u

    # Drive state uses t_cross (time since last v=0 crossing) for phase tracking
    state = get_drive_state(p, t_cross, v)

    # Selective single-coil drive with zero-crossing current brake:
    #
    # Solenoid force is always attractive — F ∝ i²·|dL/dx|.  The L/R time
    # constant (≈0.1 s) exceeds the half-period (≈0.033 s), so the "off"
    # coil's residual current opposes the desired motion.
    #
    # Active braking (V_off = −V_bus for the full window) fails because it
    # drives |i| back up in the opposite direction after zero-crossing.
    #
    # Fix: apply reverse voltage ONLY while i_off > 0 (forcing it toward
    # zero), then switch to V_off = 0 once i_off ≤ 0 to prevent rebuild.
    #
    #   ATTRACT (v > 0):  V_A = +V_bus            (pull toward +x)
    #                      V_B = −V_bus if i_B>0   (brake coil B → 0)
    #                      V_B =  0     if i_B≤0   (hold at zero)
    #   REPEL   (v < 0):  V_A = −V_bus if i_A>0   (brake coil A → 0)
    #                      V_A =  0     if i_A≤0   (hold at zero)
    #                      V_B = +V_bus            (pull toward −x)
    #   Coast:             both off
    if state == ATTRACT
        V_A =  p.V_bus
        V_B =  i_B > 0.0 ? -p.V_bus : 0.0   # brake B only while i_B > 0
    elseif state == REPEL
        V_A =  i_A > 0.0 ? -p.V_bus : 0.0   # brake A only while i_A > 0
        V_B =  p.V_bus
    else
        V_A =  0.0
        V_B =  0.0
    end

    # Sigmoid inductance model — naturally bounded, no clamping needed
    L_A, L_B, dL_A_dx, dL_B_dx = effective_L(p, x)

    # dL/dt = dL/dx · v
    dL_A_dt = dL_A_dx * v
    dL_B_dt = dL_B_dx * v

    # Electrical dynamics: V = i·R + L·di/dt + i·dL/dt
    # => di/dt = (V - i·R - i·dL/dt) / L
    du[1] = (V_A - i_A * p.R_coil - i_A * dL_A_dt) / L_A
    du[2] = (V_B - i_B * p.R_coil - i_B * dL_B_dt) / L_B

    # Magnetic force: F = (1/2) · i² · dL/dx
    # Coil A (dL/dx > 0) pulls toward +x, coil B (dL/dx < 0) pulls toward -x.
    # Net force is the vector sum: F_net = F_A + F_B = 0.5·(i_A²·dL_A/dx + i_B²·dL_B/dx)
    F_A = 0.5 * i_A^2 * dL_A_dx
    F_B = 0.5 * i_B^2 * dL_B_dx
    F_net = F_A + F_B  # Net magnetic force on reaction mass (+ toward coil A)

    # Pickup coil force (generator-as-damper): F_gen = -b_gen · v
    F_gen = -p.b_gen * v

    # Restoring force: F_restore = -k_spring · x
    F_restore = -p.k_spring * x

    # Net mechanical force
    F_total = F_net + F_gen + F_restore

    # Mechanical dynamics
    du[3] = v                              # dx/dt = v
    du[4] = F_total / p.m_osc               # dv/dt = F/m

    # Phase tracking: t_cross advances at clock speed; reset to 0 by callback
    du[5] = 1.0

    return nothing
end

# ContinuousCallback: reset t_cross at every velocity zero-crossing
function _v_crossing_condition(u, t, integrator)
    u[4]  # detect v = 0
end
function _reset_t_cross!(integrator)
    integrator.u[5] = 0.0
end
const v_crossing_callback = ContinuousCallback(
    _v_crossing_condition, _reset_t_cross!;
    rootfind=true, save_positions=(true, true)
)

"""
    ODE function wrapper for DifferentialEquations.jl
    
    DifferentialEquations.jl calls f(du, u, p, t) where p is the
    full parameters object. We dispatch on OscillatorParams.
"""
function (p::OscillatorParams)(du, u, args...)
    if length(args) == 1
        # Direct call: f(du, u, p, t)
        t = args[1]
        coupled_oscillator!(du, u, p, Float64(t))
    else
        error("Unexpected call signature")
    end
end

# =============================================================================
# Thrust Computation
# =============================================================================

"""
    compute_thrust(p, sol)

Extract thrust from ODE solution. Uses the same sigmoid inductance
model as the ODE — naturally bounded, no clamping needed.
Thrust is the reaction force on the vehicle: -(F_A + F_B).
"""
function compute_thrust(p::OscillatorParams, sol)
    n = length(sol.t)
    thrust = zeros(n)

    for i in 1:n
        i_A = sol[1, i]
        i_B = sol[2, i]
        x = sol[3, i]

        # Use same sigmoid model as ODE
        _, _, dL_A_dx, dL_B_dx = effective_L(p, x)

        F_A = 0.5 * i_A^2 * dL_A_dx
        F_B = 0.5 * i_B^2 * dL_B_dx
        thrust[i] = -(F_A + F_B)
    end

    return thrust
end

"""
    compute_power_balance(p, sol)

Compute energy balance from ODE solution — sigmoid inductance model,
magnetic field energy tracked for full closure.

Energy pathways:
  P_pump    — Electrical power into coils (sum V·I)
  P_copper  — I²R losses
  P_thrust  — Mechanical work on vehicle (absorbed power)
  P_pickup  — Recovered via pickup coils
  efficiency — (P_thrust + P_pickup) / P_pump × 100

Closure verification:
  ΔE_store = ΔE_mag + E_kinetic_f + E_spring_f
  E_residual = E_pump - E_copper - E_thrust - E_pickup - ΔE_store
  closure_pct = |E_residual / E_pump| × 100

  A closure > 1% indicates systematic error in the power balance.
  Expected sources: numerical integration error, unmodeled loss.
"""
function compute_power_balance(p::OscillatorParams, sol)
    n = length(sol.t)
    t = sol.t
    dt_vals = diff(t)

    # Accumulators
    E_pump = 0.0
    E_copper = 0.0
    E_thrust = 0.0
    E_pickup = 0.0

    # Initial magnetic field energy ½L·i²
    L_A_0, L_B_0, _, _ = effective_L(p, sol[3, 1])
    E_mag_prev = 0.5 * (L_A_0 * sol[1, 1]^2 + L_B_0 * sol[2, 1]^2)

    for i in 1:(n-1)
        i_A = sol[1, i]; i_B = sol[2, i]
        x = sol[3, i]; v = sol[4, i]
        t_cross = sol[5, i]
        dt = dt_vals[i]

        # Drive voltages — must match the ODE's coupled_oscillator! logic
        state = get_drive_state(p, t_cross, v)
        if state == ATTRACT
            V_A =  p.V_bus
            V_B =  i_B > 0.0 ? -p.V_bus : 0.0
        elseif state == REPEL
            V_A =  i_A > 0.0 ? -p.V_bus : 0.0
            V_B =  p.V_bus
        else
            V_A =  0.0
            V_B =  0.0
        end

        # Electrical energy: ∫ V·I dt
        E_pump += (V_A * i_A + V_B * i_B) * dt

        # Copper loss: ∫ I²R dt
        E_copper += (i_A^2 + i_B^2) * p.R_coil * dt

        # Thrust work: sigmoid model, matching ODE
        _, _, dL_A_dx, dL_B_dx = effective_L(p, x)
        F_A = 0.5 * i_A^2 * dL_A_dx
        F_B = 0.5 * i_B^2 * dL_B_dx
        F_thrust = -(F_A + F_B)
        E_thrust += F_thrust * v * dt

        # Pickup energy: ∫ b_gen · v² dt
        E_pickup += p.b_gen * v^2 * dt
    end

    # Initial stored energies (for Δ calculation)
    E_kin_0 = 0.5 * p.m_osc * p.v₀^2
    E_spring_0 = 0.5 * p.k_spring * p.x₀^2

    # Final state stored energies
    i_A_f, i_B_f, x_f, v_f = sol[1, end], sol[2, end], sol[3, end], sol[4, end]
    L_A_f, L_B_f, _, _ = effective_L(p, x_f)
    E_mag_f = 0.5 * (L_A_f * i_A_f^2 + L_B_f * i_B_f^2)
    E_kinetic_f = 0.5 * p.m_osc * v_f^2
    E_spring_f = 0.5 * p.k_spring * x_f^2

    # Change in stored energy (Δ = final − initial)
    ΔE_mag = E_mag_f - E_mag_prev
    ΔE_kin = E_kinetic_f - E_kin_0
    ΔE_spring = E_spring_f - E_spring_0
    ΔE_store = ΔE_mag + ΔE_kin + ΔE_spring
    E_residual = E_pump - E_copper - E_thrust - E_pickup - ΔE_store

    duration = t[end] - t[1]
    P_pump = E_pump / duration
    P_copper = E_copper / duration
    P_thrust = E_thrust / duration
    P_pickup = E_pickup / duration
    efficiency = P_pump > 0 ? (P_thrust + P_pickup) / P_pump * 100 : 0.0
    closure_pct = abs(E_pump) > 1e-12 ? abs(E_residual) / abs(E_pump) * 100 : 0.0

    return (
        E_pump=E_pump, E_copper=E_copper, E_thrust=E_thrust, E_pickup=E_pickup,
        P_pump=P_pump, P_copper=P_copper, P_thrust=P_thrust, P_pickup=P_pickup,
        efficiency=efficiency, duration=duration,
        E_mag_initial=E_mag_prev, E_mag_final=E_mag_f,
        E_kinetic_final=E_kinetic_f, E_spring_final=E_spring_f,
        ΔE_store=ΔE_store, E_residual=E_residual, closure_pct=closure_pct
    )
end

# =============================================================================
# Solver Interface
# =============================================================================

"""
    solve_oscillator(p; duration=1.0, dt_max=1e-4, reltol=1e-6, saveat=0.0)

Solve the coupled oscillator ODE for the given parameters.
"""
function solve_oscillator(p::OscillatorParams; duration::Float64=1.0,
                          dtmax::Float64=1e-4, reltol::Float64=1e-6,
                          saveat=Float64[], adaptive::Bool=true)
    u₀ = [p.i₀, p.i₀, p.x₀, p.v₀, 0.0]
    tspan = (0.0, duration)

    # Use AutoTsit5(Rodas5P()) for stiff/non-stiff auto-switching
    prob = ODEProblem(coupled_oscillator!, u₀, tspan, p)

    sol = solve(prob, AutoTsit5(Rodas5P());
                reltol=reltol, abstol=reltol,
                dtmax=dtmax, saveat=saveat,
                adaptive=adaptive, maxiters=1_000_000,
                callback=v_crossing_callback)

    return sol
end

"""
    solve_oscillator_stiff(p; kwargs...)

Use a dedicated stiff solver (Rodas5P) for very stiff systems.
"""
function solve_oscillator_stiff(p::OscillatorParams; duration::Float64=1.0,
                                 dtmax::Float64=1e-4, reltol::Float64=1e-8)
    u₀ = [p.i₀, p.i₀, p.x₀, p.v₀, 0.0]
    tspan = (0.0, duration)

    prob = ODEProblem(coupled_oscillator!, u₀, tspan, p)
    sol = solve(prob, Rodas5P(); reltol=reltol, abstol=abstol,
                dtmax=dtmax, maxiters=1_000_000,
                callback=v_crossing_callback)

    return sol
end

# =============================================================================
# Analytical Model (for fast sweeps)
# =============================================================================

"""
    _lr_rms_factor(θ) -> Float64

RMS current factor for exponential rise from zero through an LR circuit:

    i(t) = I_ss · (1 − exp(−t/τ)),    θ = t/τ

The factor ⟨i²⟩/I_ss² is the exact time-average of i(t)² over the
interval [0, t]:

    ⟨i²⟩ / I_ss² = 1 + 2·(τ/t)·(exp(−t/τ)−1) − (τ/(2t))·(exp(−2t/τ)−1)

For θ → 0 (pulse much shorter than τ): factor → 0 (current barely rises).
For θ → ∞ (pulse much longer than τ): factor → 1 (reaches steady state).
"""
function _lr_rms_factor(θ::Float64)::Float64
    if θ <= 1e-12
        return 0.0
    end
    e1 = exp(-θ)
    e2 = exp(-2θ)
    inv = 1.0 / θ
    return max(0.0, 1.0 + 2.0 * inv * (e1 - 1.0) - 0.5 * inv * (e2 - 1.0))
end

"""
    saturated_dldx_peak(p, I_peak)

Reduce peak dL/dx and L_max due to current-dependent permeability saturation.

For a solenoid with a ferromagnetic core, the effective relative permeability
drops at high current:

    μ_eff(I) = μ_eff₀ / (1 + I/I_sat)

The inductance L ∝ μ_eff, and dL/dx ∝ ΔL ∝ μ_eff, so:

    dL/dx_eff = dL/dx_peak₀ / (1 + I_peak/I_sat)
    L_max_eff = L_base + ΔL₀ / (1 + I_peak/I_sat)

When p.I_sat = Inf (default) or I_peak ≤ 0, saturation is disabled and
(p.dL_dx_peak, p.L_max) are returned unchanged.
"""
function saturated_dldx_peak(p::OscillatorParams, I_peak::Float64)::Tuple{Float64, Float64}
    if !isfinite(p.I_sat) || I_peak <= 0
        return (p.dL_dx_peak, p.L_max)
    end
    μ_ratio = 1.0 / (1.0 + I_peak / p.I_sat)
    ΔL_eff = p.ΔL * μ_ratio
    dL_dx_eff = ΔL_eff / (2.0 * p.δ_L)
    L_max_eff = p.L_base + ΔL_eff
    return (dL_dx_eff, L_max_eff)
end

"""
    stroke_dldx_correction(p, τ; N=200)

Compute the stroke-averaged dL/dx correction factor for the analytical thrust.

The position-varying dL/dx(x) = dL_dx_peak · sech²(x/δ_L) is averaged over the
attract window weighted by i(t)²:

    c_L = ∫₀^{t_att} sech²(x(t)/δ_L) · i(t)² dt / ∫₀^{t_att} i(t)² dt

For sinusoidal motion x(t) = -z₀·cos(ωt), i(t) = I_ss·(1 - exp(-t/τ)).

Returns: c_L ∈ (0, 1] where c_L = 1 when stroke ≪ δ_L (peak dL/dx dominates)
         and c_L → 0 when stroke ≫ δ_L (force vanishes at stroke extremes).
"""
function stroke_dldx_correction(p::OscillatorParams, τ::Float64; N::Int=200)::Float64
    ω = p.ω_osc
    z₀ = p.amplitude
    t_att = p.t_attract

    if t_att <= 0
        return 1.0
    end

    # i(t) = I_ss · (1 - exp(-t/τ))
    # i(t)² = I_ss² · (1 - 2·exp(-t/τ) + exp(-2t/τ))
    # The I_ss² factor cancels in the ratio, so we just integrate the shape function.
    # x(t) = -z₀·cos(ωt), so sech²(x/δ_L) = sech²(z₀·cos(ωt)/δ_L) [even function]

    num = 0.0  # ∫ sech²(i_shape) · i_shape dt
    den = 0.0  # ∫ i_shape dt  where i_shape = (1 - exp(-t/τ))²

    dt = t_att / N
    for i in 0:N
        t = i * dt
        # Trapezoidal weight
        w = (i == 0 || i == N) ? 0.5 : 1.0

        x = -z₀ * cos(ω * t)
        dldx_shape = 1.0 / cosh(x / p.δ_L)
        dldx_shape_sq = dldx_shape * dldx_shape  # sech²(x/δ_L)

        # Current shape (1 - exp(-t/τ))²
        if τ > 0 && t > 0
            eθ = exp(-t / τ)
            i_shape = (1.0 - eθ) * (1.0 - eθ)  # (1 - e^{-t/τ})²
        elseif t <= 0
            i_shape = 0.0
        else
            # τ → 0: instantaneous current rise → i_shape → 1 immediately
            i_shape = 1.0
        end

        num += w * dldx_shape_sq * i_shape * dt
        den += w * i_shape * dt
    end

    if den <= 1e-30
        return 1.0
    end

    return min(1.0, max(0.0, num / den))
end

"""
    analytical_thrust(p; use_stroke_correction=false, use_saturation=false)

Compute average thrust from the analytical model **accounting for the
L/R current-rise limitation**.

The coil inductance L limits how quickly current can rise when the
drive voltage is applied. The L/R time constant τ = L/R determines
the fraction of steady-state current (V_bus/R) reached during a
drive pulse of duration t_drive:

    i(t) = (V_bus/R) · (1 − exp(−t·R/L))

The average force is computed from the exact time-integral of i(t)²
over the attract and repel windows:

    F_avg = 0.5·dL/dx · (⟨i²⟩_att·t_att + ⟨i²⟩_rep·t_rep) / t_half

When τ ≪ t_drive, this reduces to the instant-current bound:
    0.5·dL/dx·(V_bus/R)²·(t_att + t_rep)/t_half

**Keyword arguments:**

  • `use_stroke_correction` (Bool, default `false`):
    Apply position-dependent dL/dx correction. When enabled, the
    peak dL/dx is replaced by a weighted average of sech²(x/δ_L)
    over the attract window, weighted by i(t)². This accounts for
    the reduced force contribution when the slug is far from coil
    center during most of the drive window.

  • `use_saturation` (Bool, default `false`):
    Account for current-dependent permeability saturation. When
    enabled, L_max and dL_dx_peak are reduced by the factor
    1/(1 + I_ss/I_sat), which affects both the τ calculation and
    the peak force.
"""
function analytical_thrust(p::OscillatorParams;
                           use_stroke_correction::Bool=false,
                           use_saturation::Bool=false)::Float64

    # Determine effective dL/dx and L_max with saturation if applicable
    dL_dx_peak_eff = p.dL_dx_peak
    L_max_eff = p.L_max

    if use_saturation
        I_ss_sat = p.V_bus / p.R_coil
        dL_dx_peak_eff, L_max_eff = saturated_dldx_peak(p, I_ss_sat)
    end

    L_avg = (p.L_base + L_max_eff) / 2.0
    τ = L_avg / p.R_coil
    I_ss = p.V_bus / p.R_coil
    I_ss² = I_ss^2

    # Normalised drive durations θ = t_drive / τ
    θ_a = p.t_attract / τ
    θ_r = p.t_repel / τ

    # Mean i² over each drive window
    i2_avg_a = I_ss² * _lr_rms_factor(θ_a)
    i2_avg_r = I_ss² * _lr_rms_factor(θ_r)

    # Time-averaged force over one half-cycle (see docstring)
    numerator = i2_avg_a * p.t_attract + i2_avg_r * p.t_repel
    F_avg = 0.5 * dL_dx_peak_eff * numerator / p.t_half

    # Apply stroke-position correction (reduces F_avg when stroke ≫ δ_L)
    if use_stroke_correction
        c_L = stroke_dldx_correction(p, τ)
        F_avg *= c_L
    end

    return F_avg
end

"""
    analytical_power(p; use_stroke_correction=false, use_saturation=false)

Compute analytical power estimates.

Keyword arguments are forwarded to `analytical_thrust`.
"""
function analytical_power(p::OscillatorParams;
                          use_stroke_correction::Bool=false,
                          use_saturation::Bool=false)

    # Determine effective L_max with saturation if applicable
    L_max_eff = p.L_max
    if use_saturation
        I_ss_sat = p.V_bus / p.R_coil
        _, L_max_eff = saturated_dldx_peak(p, I_ss_sat)
    end

    # Parametric pump power: P_pump = (1/4) · k · h · ω · z₀² · η
    k = p.k_spring
    ω = p.ω_osc
    z₀ = p.amplitude
    η = p.η_repel
    h = p.t_attract / p.t_half  # fraction of half-cycle under attract

    P_pump_mech = 0.25 * k * h * ω * z₀^2 * η

    # Copper loss: I²R integrated over one cycle
    # L/R-aware current: uses exact time-average of i(t)²
    L_avg = (p.L_base + L_max_eff) / 2.0
    τ = L_avg / p.R_coil
    I_ss = p.V_bus / p.R_coil
    I_ss² = I_ss^2

    θ_a = p.t_attract / τ
    θ_r = p.t_repel / τ
    fac_a = _lr_rms_factor(θ_a)
    fac_r = _lr_rms_factor(θ_r)

    # Numerator = time-integral of i² over the active period
    numerator = I_ss² * fac_a * p.t_attract + I_ss² * fac_r * p.t_repel
    # Over a full cycle (2·t_half), each coil is active for t_half of it
    P_copper = numerator / p.t_half * p.R_coil

    # Thrust power — forward kwargs
    F_thrust = analytical_thrust(p; use_stroke_correction=use_stroke_correction,
                                   use_saturation=use_saturation)
    v_avg = 2 * z₀ * ω / π  # Average absolute velocity
    P_thrust = F_thrust * v_avg

    # Pickup power
    v_rms = z₀ * ω / sqrt(2)
    P_pickup = p.b_gen * v_rms^2

    P_net = P_pump_mech - P_thrust + P_pickup - P_copper

    return (P_pump_mech=P_pump_mech, P_copper=P_copper,
            P_thrust=P_thrust, P_pickup=P_pickup, P_net=P_net)
end

"""
    check_hover_feasibility(p; use_stroke_correction=false, use_saturation=false)

Check whether this parameter set can theoretically hover.

Keyword arguments are forwarded to `analytical_thrust` and `analytical_power`.
"""
function check_hover_feasibility(p::OscillatorParams;
                                 use_stroke_correction::Bool=false,
                                 use_saturation::Bool=false)
    F_thrust = analytical_thrust(p; use_stroke_correction=use_stroke_correction,
                                   use_saturation=use_saturation)
    weight = p.M_total * g₀

    power = analytical_power(p; use_stroke_correction=use_stroke_correction,
                               use_saturation=use_saturation)

    return (
        feasible=F_thrust >= weight,
        F_thrust=F_thrust,
        weight=weight,
        margin=(F_thrust - weight) / weight * 100,
        P_pump=power.P_pump_mech,
        P_net=power.P_net,
        c_L=use_stroke_correction ? stroke_dldx_correction(p, (p.L_base + p.L_max) / 2.0 / p.R_coil) : 1.0,
        dL_dx_eff=use_saturation ? saturated_dldx_peak(p, p.V_bus / p.R_coil)[1] : p.dL_dx_peak
    )
end

# =============================================================================
# ODE-Based Cycle Feasibility
# =============================================================================

"""
    mechanical_energy(p, x, v)

Compute total mechanical energy of the oscillator.

E_mech = ½·m_osc·v² + ½·k_spring·x²

[Watts·seconds = Joules]
"""
function mechanical_energy(p::OscillatorParams, x::Float64, v::Float64)::Float64
    return 0.5 * p.m_osc * v^2 + 0.5 * p.k_spring * x^2
end

"""
    find_zero_crossings(vals)

Find indices where `vals` crosses zero (sign change or exact zero).

Returns vector of crossing indices (the left-side index of each crossing interval).
"""
function find_zero_crossings(vals::Vector{Float64})::Vector{Int}
    crossings = Int[]
    for i in 1:(length(vals) - 1)
        if vals[i] == 0.0
            push!(crossings, i)
        elseif vals[i] * vals[i + 1] < 0.0
            push!(crossings, i)
        end
    end
    return crossings
end

"""
    energy_at_turning_points(p, sol)

Find all velocity zero crossings and compute mechanical energy at each.

Returns vectors of (time, x, E_mech) at each turning point.
"""
function energy_at_turning_points(p::OscillatorParams, sol)
    t_vals = sol.t
    x_vals = sol[3, :]
    v_vals = sol[4, :]

    crossings = find_zero_crossings(v_vals)

    if isempty(crossings)
        return Float64[], Float64[], Float64[]
    end

    t_cross = Float64[]
    x_cross = Float64[]
    e_cross = Float64[]

    for idx in crossings
        # Interpolate exact crossing time
        t_i = t_vals[idx]
        t_i1 = t_vals[idx + 1]
        v_i = v_vals[idx]
        v_i1 = v_vals[idx + 1]

        if v_i == 0.0
            # Exact zero at this point
            t_c = t_i
            x_c = x_vals[idx]
        else
            # Linear interpolation to zero crossing
            α = v_i / (v_i - v_i1)  # fraction from idx to crossing
            t_c = t_i + α * (t_i1 - t_i)
            x_c = x_vals[idx] + α * (x_vals[idx + 1] - x_vals[idx])
        end

        e_c = mechanical_energy(p, x_c, 0.0)

        push!(t_cross, t_c)
        push!(x_cross, x_c)
        push!(e_cross, e_c)
    end

    return t_cross, x_cross, e_cross
end

"""
    CycleFeasibilityResult

Results from a short ODE cycle-feasibility run.
"""
@with_kw struct CycleFeasibilityResult
    feasible::Bool          # Is oscillation self-sustaining?
    ΔE_total::Float64       # Total mechanical energy change [J]
    ΔE_per_cycle::Float64   # Average ΔE per full cycle [J/cycle]
    E_initial::Float64      # Initial mechanical energy [J]
    E_final::Float64        # Final mechanical energy [J]
    n_crossings::Int        # Number of turning points found
    n_cycles::Float64       # Number of full cycles simulated
    duration::Float64       # Simulation duration [s]
    max_current::Float64    # Peak coil A current over run [A]
end

"""
    cycle_feasibility(p; duration=2.0, ncycles=nothing)

Run ODE and assess whether oscillation is self-sustaining.

Measures mechanical energy at consecutive velocity zero crossings
(turning points). If more than 2 crossing exist, computes energy
trend. Returns a `CycleFeasibilityResult`.

If `ncycles` is provided, `duration` is ignored and the simulation
runs for exactly `ncycles / p.f_osc` seconds.

The key metric: `ΔE_per_cycle > 0` means the drive injects more energy
per cycle than generator damping + friction remove.
"""
function cycle_feasibility(p::OscillatorParams;
                           duration::Float64=2.0,
                           ncycles::Union{Int,Nothing}=nothing)::CycleFeasibilityResult

    # Determine simulation duration
    if ncycles !== nothing
        duration = ncycles / p.f_osc
    end

    # Solve ODE
    sol = solve_oscillator(p; duration=duration)

    # Find initial mechanical energy
    E_initial = mechanical_energy(p, p.x₀, p.v₀)

    # Find velocity zero crossings
    t_cross, x_cross, e_cross = energy_at_turning_points(p, sol)

    n_cross = length(t_cross)

    if n_cross < 2
        # Not enough data — ODE may have blown up or damped too fast
        return CycleFeasibilityResult(
            feasible=false,
            ΔE_total=0.0,
            ΔE_per_cycle=0.0,
            E_initial=E_initial,
            E_final=E_initial,
            n_crossings=n_cross,
            n_cycles=0.0,
            duration=duration,
            max_current=maximum(abs.(sol[1, :]))
        )
    end

    # Compute ΔE between first and last crossing
    E_first = e_cross[1]
    E_last = e_cross[end]
    ΔE_total = E_last - E_first

    # Number of full cycles (2 crossings per cycle: one at each extreme)
    n_full_cycles = (n_cross - 1) / 2.0
    ΔE_per_cycle = n_full_cycles > 0 ? ΔE_total / n_full_cycles : ΔE_total

    # Feasibility: energy growing over time
    feasible = ΔE_per_cycle > 0.0 && E_last > E_initial

    return CycleFeasibilityResult(
        feasible=feasible,
        ΔE_total=ΔE_total,
        ΔE_per_cycle=ΔE_per_cycle,
        E_initial=E_initial,
        E_final=E_last,
        n_crossings=n_cross,
        n_cycles=n_full_cycles,
        duration=duration,
        max_current=maximum(abs.(sol[1, :]))
    )
end

"""
    ODESweepConfig

Configuration for one ODE-based parameter sweep point.
"""
@with_kw struct ODESweepConfig
    V_bus::Float64
    L_max::Float64
    R_load::Float64
    stroke::Float64
    η_repel::Float64
    f_osc::Float64
    m_osc::Float64
    R_coil::Float64
    N_pickup::Int
end

"""
    ODESweepResult

Results from one ODE-based parameter sweep point.
"""
@with_kw struct ODESweepResult
    config::ODESweepConfig
    feasible::Bool
    ΔE_per_cycle::Float64
    E_initial::Float64
    E_final::Float64
    max_current::Float64
    n_cycles::Float64
    status::String  # "ok", "failed", "no_crossings"
end

"""
    run_ode_sweep(; kwargs...)

Run ODE-based feasibility sweep over parameter grid.

Keyword arguments define sweep ranges and fixed parameters:

  # Sweep ranges (vectors)
  V_bus_range::Vector{Float64}   = [48.0, 96.0, 192.0, 384.0, 600.0, 800.0]
  L_max_range::Vector{Float64}   = [0.01, 0.02, 0.05, 0.10, 0.20]
  R_load_range::Vector{Float64}  = [10.0, 50.0, 100.0, 500.0, 1000.0]
  stroke_range::Vector{Float64}  = [0.05]
  η_range::Vector{Float64}       = [0.20]
  f_range::Vector{Float64}       = [15.0]

  # Fixed parameters
  m_osc::Float64                 = 19.17   (115 kg / 6)
  R_coil::Float64                = 1.0
  N_pickup::Int                  = 100
  B::Float64                     = 0.5
  A_pickup::Float64              = 0.01
  d_rest::Float64                = 0.01

  # Simulation
  ncycles::Int                   = 6
  verbose::Bool                  = false

Returns vector of ODESweepResult, sorted by feasibility then ΔE.
"""
function run_ode_sweep(;
    V_bus_range::Vector{Float64}=[48.0, 96.0, 192.0, 384.0, 600.0, 800.0],
    L_max_range::Vector{Float64}=[0.01, 0.02, 0.05, 0.10, 0.20],
    R_load_range::Vector{Float64}=[10.0, 50.0, 100.0, 500.0, 1000.0],
    stroke_range::Vector{Float64}=[0.05],
    η_range::Vector{Float64}=[0.20],
    f_range::Vector{Float64}=[15.0],
    m_osc::Float64=115.0 / 6.0,
    R_coil::Float64=1.0,
    N_pickup::Int=100,
    B::Float64=0.5,
    A_pickup::Float64=0.01,
    d_rest::Float64=0.01,
    ncycles::Int=6,
    verbose::Bool=false)

    # Build all configs
    configs = ODESweepConfig[]
    for V_bus in V_bus_range,
        L_max in L_max_range,
        R_load in R_load_range,
        stroke in stroke_range,
        η in η_range,
        f in f_range

        push!(configs, ODESweepConfig(
            V_bus=V_bus, L_max=L_max, R_load=R_load,
            stroke=stroke, η_repel=η, f_osc=f,
            m_osc=m_osc, R_coil=R_coil, N_pickup=N_pickup
        ))
    end

    n_total = length(configs)
    if verbose
        @info "Running ODE sweep over $n_total parameter combinations..."
    end

    # Run all configurations
    results = Vector{ODESweepResult}(undef, n_total)

    for (i, cfg) in enumerate(configs)
        if verbose && mod(i, max(1, n_total ÷ 20)) == 0
            @printf "[%3d/%3d] V=%.0fV L=%.3fH R_L=%.0fΩ\n" i n_total cfg.V_bus cfg.L_max cfg.R_load
        end

        try
            p = init_params(
                M_total=115.0,
                η_repel=cfg.η_repel,
                f_osc=cfg.f_osc,
                m_osc=cfg.m_osc,
                L_max=cfg.L_max,
                V_bus=cfg.V_bus,
                R_coil=cfg.R_coil,
                N_pickup=cfg.N_pickup,
                B_pickup=B, A_pickup=A_pickup, d_rest=d_rest
            )

            # Override stroke via amplitude
            p = OscillatorParams(
                p, amplitude=cfg.stroke / 2.0,
                x₀=cfg.stroke / 2.0, v₀=0.0
            )

            feasi = cycle_feasibility(p; ncycles=ncycles)

            results[i] = ODESweepResult(
                config=cfg,
                feasible=feasi.feasible,
                ΔE_per_cycle=feasi.ΔE_per_cycle,
                E_initial=feasi.E_initial,
                E_final=feasi.E_final,
                max_current=feasi.max_current,
                n_cycles=feasi.n_cycles,
                status=feasi.n_crossings < 2 ? "no_crossings" : "ok"
            )
        catch e
            if verbose
                @warn "Failed at V=$(cfg.V_bus), L_max=$(cfg.L_max), R_load=$(cfg.R_load): $e"
            end
            results[i] = ODESweepResult(
                config=cfg, feasible=false,
                ΔE_per_cycle=0.0, E_initial=0.0, E_final=0.0,
                max_current=0.0, n_cycles=0.0, status="failed"
            )
        end
    end

    # Sort: feasible first (by ΔE descending), then infeasible
    sort!(results, by=r -> (r.feasible, r.ΔE_per_cycle), rev=true)

    return results
end

# =============================================================================
# Parameter Sweep
# =============================================================================

"""
    SweepConfig

Configuration for one parameter sweep point.
"""
@with_kw struct SweepConfig
    M_total::Float64
    η::Float64
    f::Float64
    m_ratio::Float64
end

"""
    SweepResult

Results for one sweep point.
"""
@with_kw struct SweepResult
    config::SweepConfig
    feasible::Bool
    F_thrust::Float64
    weight::Float64
    margin::Float64
    P_pump::Float64
    P_net::Float64
end

"""
    run_sweep(masses, etas, freqs, ratios)

Run analytical parameter sweep over all combinations.
"""
function run_sweep(masses::Vector{Float64}=[5, 50, 115, 250, 1200, 5000],
                   etas::Vector{Float64}=collect(0.05:0.025:0.50),
                   freqs::Vector{Float64}=collect(7.5:2.5:50.0),
                   ratios::Vector{Float64}=collect(0.05:0.0074:0.175))
    results = SweepResult[]

    total = length(masses) * length(etas) * length(freqs) * length(ratios)

    for M in masses
        for η in etas
            for f in freqs
                for r in ratios
                    p = init_params(
                        M_total=M, η_repel=η, f_osc=f,
                        m_ratio=r, m_osc=M * r
                    )

                    feasibility = check_hover_feasibility(p)

                    config = SweepConfig(M_total=M, η=η, f=f, m_ratio=r)
                    result = SweepResult(
                        config=config,
                        feasible=feasibility.feasible,
                        F_thrust=feasibility.F_thrust,
                        weight=feasibility.weight,
                        margin=feasibility.margin,
                        P_pump=feasibility.P_pump,
                        P_net=feasibility.P_net
                    )

                    push!(results, result)
                end
            end
        end
    end

    return results
end

"""
    run_sweep_parallel(args...)

Run parameter sweep using multi-threading.
"""
function run_sweep_parallel(masses::Vector{Float64}=[5, 50, 115, 250, 1200, 5000],
                            etas::Vector{Float64}=collect(0.05:0.025:0.50),
                            freqs::Vector{Float64}=collect(7.5:2.5:50.0),
                            ratios::Vector{Float64}=collect(0.05:0.0074:0.175))
    # Build all configs first (avoids thread safety issues with generators)
    configs = SweepConfig[]
    for M in masses, η in etas, f in freqs, r in ratios
        push!(configs, SweepConfig(M_total=M, η=η, f=f, m_ratio=r))
    end

    results = Vector{Union{Nothing, SweepResult}}(nothing, length(configs))

    Threads.@threads for i in eachindex(configs)
        cfg = configs[i]
        p = init_params(
            M_total=cfg.M_total, η_repel=cfg.η, f_osc=cfg.f,
            m_ratio=cfg.m_ratio, m_osc=cfg.M_total * cfg.m_ratio
        )

        feasibility = check_hover_feasibility(p)

        results[i] = SweepResult(
            config=cfg,
            feasible=feasibility.feasible,
            F_thrust=feasibility.F_thrust,
            weight=feasibility.weight,
            margin=feasibility.margin,
            P_pump=feasibility.P_pump,
            P_net=feasibility.P_net
        )
    end

    return [r for r in results if r !== nothing]
end

# =============================================================================
# Reporting
# =============================================================================

"""
    summarize_results(results)

Print a summary table of sweep results.
"""
function summarize_results(results::Vector{SweepResult})
    feasible = filter(r -> r.feasible, results)
    n_total = length(results)
    n_feasible = length(feasible)

    @printf("Parameter Sweep Summary\n")
    @printf("  Total configurations: %d\n", n_total)
    @printf("  Feasible for hover:   %d (%.1f%%)\n", n_feasible,
            100 * n_feasible / n_total)

    # Group by mass class
    masses = sort(unique([r.config.M_total for r in results]))

    @printf("\n%-10s %8s %8s %8s\n", "Mass[kg]", "Feasible", "Total", "%")
    @printf("%-10s %8s %8s %8s\n", "─"^8, "─"^8, "─"^8, "─"^8)

    for M in masses
        m_results = filter(r -> r.config.M_total == M, results)
        m_feasible = filter(r -> r.feasible, m_results)
        @printf("%-10.0f %8d %8d %7.1f%%\n", M, length(m_feasible),
                length(m_results), 100 * length(m_feasible) / length(m_results))
    end

    # Best configs per mass
    @printf("\nBest configurations by margin:\n")
    @printf("%-8s %-8s %-8s %-8s %-10s\n", "Mass", "η", "f[Hz]", "ratio", "margin%")
    @printf("%-8s %-8s %-8s %-8s %-10s\n", "─"^6, "─"^6, "─"^6, "─"^6, "─"^8)

    for M in masses
        m_feasible = filter(r -> r.config.M_total == M && r.feasible, results)
        if !isempty(m_feasible)
            best = argmax(r -> r.margin, m_feasible)
            @printf("%-8.0f %-8.2f %-8.1f %-8.3f %-10.1f\n",
                    M, best.config.η, best.config.f,
                    best.config.m_ratio, best.margin)
        end
    end
end

"""
    run_demo(; kwargs...)

Run a single-configuration demo and print results.
"""
function run_demo(; duration::Float64=1.0, kwargs...)
    p = init_params(; kwargs...)
    @printf("PEAT Numerical Demo\n")
    @printf("  Mass: %.1f kg, Freq: %.1f Hz, η: %.2f, Ratio: %.3f\n",
            p.M_total, p.f_osc, p.η_repel, p.m_ratio)
    @printf("  Bus: %.0f V, R_coil: %.3f Ω, L_max: %.3f H, dL/dx_peak: %.2f H/m\n",
            p.V_bus, p.R_coil, p.L_max, p.dL_dx_peak)
    @printf("  Osc mass: %.3f kg, Stroke: %.1f mm\n",
            p.m_osc, p.stroke * 1000)
    @printf("\n")

    # Analytical check
    feasible = check_hover_feasibility(p)
    @printf("Analytical:\n")
    @printf("  F_thrust: %.1f N (weight: %.1f N)\n",
            feasible.F_thrust, feasible.weight)
    if feasible.feasible
        @printf("  ✓ Feasible for hover (margin: %.1f%%)\n", feasible.margin)
    else
        @printf("  ✗ Not feasible (%.1f%% of weight)\n",
                100 * feasible.F_thrust / feasible.weight)
    end

    # Numerical ODE
    @printf("\nSolving ODE (%.1f s)...\n", duration)
    t_start = time()
    sol = solve_oscillator(p; duration=duration)
    t_elapsed = time() - t_start
    @printf("  Solved in %.3f s (%d steps)\n", t_elapsed, length(sol.t))

    # Power balance
    balance = compute_power_balance(p, sol)

    @printf("\nPower Balance (%.3f s run):\n", balance.duration)
    @printf("  Electrical input:  %10.1f J (%8.1f W)\n",
            balance.E_pump, balance.P_pump)
    @printf("  Copper loss:       %10.1f J (%8.1f W)  [%.1f%%]\n",
            balance.E_copper, balance.P_copper,
            100 * balance.E_copper / max(balance.E_pump, 1e-6))
    @printf("  Thrust work:       %10.1f J (%8.1f W)  [%.1f%%]\n",
            balance.E_thrust, balance.P_thrust,
            100 * balance.E_thrust / max(balance.E_pump, 1e-6))
    @printf("  Pickup recovery:   %10.1f J (%8.1f W)  [%.1f%%]\n",
            balance.E_pickup, balance.P_pickup,
            100 * balance.E_pickup / max(balance.E_pump, 1e-6))
    @printf("  Efficiency: %.1f%%\n", balance.efficiency)

    return (params=p, solution=sol, balance=balance)
end

"""
    run_verification()

Run analytical self-consistency checks.
"""
function run_verification()
    @printf("PEAT Analytical Verification\n")
    @printf("%-8s %-8s %-10s %-10s %-10s\n",
            "Mass[kg]", "η", "F_thrust[N]", "Weight[N]", "Margin[%]")
    @printf("%-8s %-8s %-10s %-10s %-10s\n",
            "─"^6, "─"^6, "─"^8, "─"^8, "─"^8)

    test_configs = [
        (M_total=5.0, η_repel=0.15, f_osc=15.0, m_ratio=0.15),
        (M_total=115.0, η_repel=0.20, f_osc=15.0, m_ratio=0.15),
        (M_total=115.0, η_repel=0.50, f_osc=47.5, m_ratio=0.15),
        (M_total=1200.0, η_repel=0.20, f_osc=7.5, m_ratio=0.10),
        (M_total=5000.0, η_repel=0.20, f_osc=7.5, m_ratio=0.05),
    ]

    for cfg in test_configs
        p = init_params(; cfg...)
        feasible = check_hover_feasibility(p)
        status = feasible.feasible ? "✓" : "✗"
        @printf("%-8.0f %-8.2f %-10.1f %-10.1f %-10.1f  %s\n",
                cfg.M_total, cfg.η_repel, feasible.F_thrust,
                feasible.weight, feasible.margin, status)
    end
end

# =============================================================================
# Plotting
# =============================================================================

"""
    plot_results(sol, p; filename=nothing)

Plot ODE solution results.
"""
function plot_results(sol, p::OscillatorParams; filename::Union{String,Nothing}=nothing)
    # Lazy load Plots — only when plotting is actually used
    # (This function should only be called from scripts, not core library use)

    t = sol.t
    i_A = [sol[1, i] for i in 1:length(t)]
    i_B = [sol[2, i] for i in 1:length(t)]
    x = [sol[3, i] for i in 1:length(t)]
    v = [sol[4, i] for i in 1:length(t)]

    thrust = compute_thrust(p, sol)

    pl = plot(layout=4, size=(1200, 800), xlabel="Time [s]")

    plot!(pl[1], t, i_A, label="Coil A [A]")
    plot!(pl[1], t, i_B, label="Coil B [A]")

    plot!(pl[2], t, x .* 1000, label="Position [mm]")
    plot!(pl[3], t, v, label="Velocity [m/s]")
    plot!(pl[4], t, thrust ./ 1000, label="Thrust [kN]")

    if filename !== nothing
        savefig(pl, filename)
    end

    return pl
end

"""
    plot_energy_balance(balance; filename=nothing)

Plot energy balance breakdown.
"""
function plot_energy_balance(balance; filename::Union{String,Nothing}=nothing)
    labels = ["Copper Loss", "Thrust Work", "Pickup Recovery"]
    values = [balance.E_copper, balance.E_thrust, balance.E_pickup]
    total = sum(values)

    pl = bar(labels, values ./ 1000,
             title="Energy Distribution (Total: $(round(total/1000, digits=1)) kJ)",
             ylabel="Energy [kJ]", legend=false)

    if filename !== nothing
        savefig(pl, filename)
    end

    return pl
end

"""
    plot_sweep(results; filename=nothing)

Plot sweep results summary.
"""
function plot_sweep(results::Vector{SweepResult}; filename::Union{String,Nothing}=nothing)
    masses = sort(unique([r.config.M_total for r in results]))

    pl = plot(layout=length(masses), size=(800, 200 * length(masses)),
              xlabel="η (repel fraction)", ylabel="Margin [%]")

    for (i, M) in enumerate(masses)
        m_results = filter(r -> r.config.M_total == M, results)
        etas = [r.config.η for r in m_results]
        margins = [r.margin for r in m_results]

        scatter!(pl[i], etas, margins, label="Mass=$(M)kg", markersize=2)
        hline!(pl[i], [0.0], color=:red, linestyle=:dash, label="Zero margin")
    end

    if filename !== nothing
        savefig(pl, filename)
    end

    return pl
end

# =============================================================================
# Coil Geometry Analysis
# =============================================================================

# ── Copper properties (at 20°C) ─────────────────────────────────────────────
const ρ_Cu = 1.68e-8       # Ω·m
const α_Cu = 0.00393       # K⁻¹ (temp coefficient)
const γ_Cu = 8960.0        # kg/m³ (density)

# ── AWG → wire diameter lookup ──────────────────────────────────────────────
"""
    awg_to_diameter(awg::Int) -> Float64

Wire diameter in meters for standard AWG gauge.
"""
function awg_to_diameter(awg::Int)
    # AWG table: AWG → diameter [mm]
    table = Dict(
        10 => 2.588, 11 => 2.305, 12 => 2.053, 13 => 1.828,
        14 => 1.628, 15 => 1.450, 16 => 1.291, 17 => 1.150,
        18 => 1.024, 19 => 0.912, 20 => 0.812, 21 => 0.723,
        22 => 0.644, 23 => 0.573, 24 => 0.511, 25 => 0.455,
        26 => 0.405, 27 => 0.361, 28 => 0.321, 29 => 0.286,
        30 => 0.255, 31 => 0.227, 32 => 0.202,
    )
    d_mm = get(table, awg, nothing)
    if d_mm === nothing
        # Fallback: AWG formula d = 0.127 * 92^((36-awg)/39) mm
        d_mm = 0.127 * 92.0 ^ ((36.0 - awg) / 39.0)
    end
    return d_mm * 1e-3  # convert to meters
end

"""
    awg_to_resistance_per_m(awg::Int) -> Float64

Resistance per meter [Ω/m] at 20°C for standard AWG gauge.
"""
function awg_to_resistance_per_m(awg::Int)
    d = awg_to_diameter(awg)
    A = π * (d / 2)^2
    return ρ_Cu / A
end

"""
    awg_table()

Print AWG reference table (diameter, resistance, max current).
"""
function awg_table()
    @printf("%-4s %-10s %-12s %-10s\n", "AWG", "d[mm]", "R[mΩ/m]", "d[A]")
    @printf("%-4s %-10s %-12s %-10s\n", "─"^3, "─"^8, "─"^10, "─"^8)
    for awg in [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30]
        d_mm = awg_to_diameter(awg) * 1000
        R_mΩ = awg_to_resistance_per_m(awg) * 1000
        # Approximate max current (chassis wiring, ~700 A·mm⁻²·s⁻¹ rule)
        d_in = d_mm / 25.4
        I_max = d_in^1.5 * 10  # rough approximation
        @printf("%-4d %-10.3f %-12.2f %-10.1f\n", awg, d_mm, R_mΩ, I_max)
    end
end

"""
    CoilGeometry

Electrical parameters computed from a coil geometry.
"""
@with_kw mutable struct CoilGeometry
    # Inputs
    N_turns::Int
    core_type::Symbol          # :air, :iron, :ferrite
    awg::Int
    r_mean_mm::Float64         # mean coil radius [mm]
    coil_length_mm::Float64    # axial length [mm]
    winding_depth_mm::Float64  # radial winding depth [mm]

    # Derived electrical
    L_H::Float64               # inductance [H]
    R_Ω::Float64               # resistance [Ω]
    τ_s::Float64               # L/R time constant [s]
    τ_us::Float64              # τ in microseconds
    τ_t_half_ratio::Float64    # τ / t_half (dimensionless regime metric)

    # Mechanical
    copper_mass_kg::Float64
    wire_length_m::Float64

    # Regime classification
    regime::String             # "current_limited", "transitional", "inductance_dominated"
end

function make_coil(; N_turns::Int, core_type::Symbol, awg::Int,
                    r_mean_mm::Float64, coil_length_mm::Float64,
                    winding_depth_mm::Float64 = r_mean_mm * 0.3)
    # Compute electrical parameters
    r = r_mean_mm * 1e-3
    l = coil_length_mm * 1e-3
    w = winding_depth_mm * 1e-3

    # Wire length: mean turn × N
    mean_turn_circ = 2π * r
    wire_length = mean_turn_circ * N_turns

    # Wire resistance
    R_wire_per_m = awg_to_resistance_per_m(awg)
    R = wire_length * R_wire_per_m

    # Copper mass
    d_wire = awg_to_diameter(awg)
    A_wire = π * (d_wire / 2)^2
    copper_vol = wire_length * A_wire
    copper_mass = copper_vol * γ_Cu

    # Inductance
    L = compute_inductance(N_turns, r, l, w, core_type)

    return CoilGeometry(
        N_turns=N_turns, core_type=core_type, awg=awg,
        r_mean_mm=r_mean_mm, coil_length_mm=coil_length_mm,
        winding_depth_mm=winding_depth_mm,
        L_H=L, R_Ω=R, τ_s=0.0, τ_us=0.0, τ_t_half_ratio=0.0,
        copper_mass_kg=copper_mass, wire_length_m=wire_length,
        regime="unclassified"
    )
end

"""
    compute_inductance(N, r, l, w, core_type) -> L [H]

Compute coil inductance using appropriate model for core type.

Core types:
  :air      — Wheeler approximation for short air-core solenoid
  :iron     — Ideal iron core (μ_r applied to magnetic circuit)
  :ferrite  — Same as :iron with typical μ_r ≈ 2000
  :pot      — Pot core / RM core approximation
"""
function compute_inductance(N::Int, r::Float64, l::Float64,
                             w::Float64, core_type::Symbol)
    μ₀ = 4π * 1e-7

    if core_type == :air
        # Wheeler approximation for short solenoid
        # L = μ₀ * N² * π * r² / (l + 0.9 * r)
        # Effective length includes fringe field correction
        # More accurate: Nagaoka's coefficient K_N
        if l > 1e-6
            α = 2r / l  # aspect ratio (diameter/length)
            if α > 0.1
                # Nagaoka's coefficient for finite solenoid
                K_N = 1.0 / (1.0 + 0.9 * α^(-1) - 0.2 * α^(-2))
                K_N = clamp(K_N, 0.1, 1.0)
            else
                K_N = 1.0  # very long solenoid → ideal
            end
            A = π * r^2
            L = μ₀ * N^2 * A / l * K_N
        else
            # Pancake coil (l → 0): use flat coil formula
            # L = μ₀ * N² * r * (ln(8r/r_wire) - 0.5) approx
            r_wire = 0.001  # nominal wire radius
            L = μ₀ * N^2 * r * (log(8 * r / r_wire) - 0.5)
        end

    elseif core_type == :iron || core_type == :ferrite
        # Slug-centered inductance: Wheeler air-core × μ_eff
        # Consistent with estimate_dL_dx — NOT a closed magnetic circuit.
        # The slug partially fills the bore; effective μ is given by
        # μ_slug_from_core (≈8 for iron/ferrite), not full μ_r ≈ 2000.
        L = compute_inductance(N, r, l, w, :air) * μ_slug_from_core(core_type)

    elseif core_type == :pot
        # Pot core / RM core — closed magnetic path
        μ_r = 2000.0
        A_core = π * r^2 * 0.5  # core cross-section
        l_mag = 2 * (r + l)     # approximate magnetic path
        L = μ₀ * μ_r * N^2 * A_core / l_mag

    else
        error("Unknown core_type: $core_type. Use :air, :iron, :ferrite, or :pot.")
    end

    return L
end

"""
    compute_τ_t_half_ratio(geom::CoilGeometry; f_osc::Float64=15.0) -> CoilGeometry

Compute τ = L/R and t_half = 1/(2f), return updated geometry with regime.
"""
function compute_τ_t_half_ratio(geom::CoilGeometry; f_osc::Float64=15.0)
    τ = geom.L_H / max(geom.R_Ω, 1e-12)
    t_half = 1.0 / (2.0 * f_osc)
    ratio = τ / t_half

    if ratio < 0.1
        regime = "current_limited"
    elseif ratio < 0.5
        regime = "transitional"
    else
        regime = "inductance_dominated"
    end

    geom.τ_s = τ
    geom.τ_us = τ * 1e6
    geom.τ_t_half_ratio = ratio
    geom.regime = regime
    return geom
end

# ── Geometry sweep ────────────────────────────────────────────────────────────

"""
    GeometrySweepConfig

Configuration for one geometry sweep point.
"""
@with_kw struct GeometrySweepConfig
    N_turns::Int
    core_type::Symbol
    awg::Int
    r_mean_mm::Float64
    coil_length_mm::Float64
    f_osc::Float64
end

"""
    GeometrySweepResult

Results for one geometry sweep point.
"""
@with_kw struct GeometrySweepResult
    config::GeometrySweepConfig
    L_mH::Float64
    R_Ω::Float64
    τ_us::Float64
    τ_t_half_ratio::Float64
    copper_mass_kg::Float64
    wire_length_m::Float64
    regime::String
end

"""
    coil_geometry_sweep(; kwargs...)

Sweep over coil geometry parameters to discover τ/t_half regimes.

Keyword arguments:
  N_range          — Turn counts to sweep
  core_types       — Core types [:air, :iron, :ferrite]
  awg_range        — AWG gauges to sweep
  r_mean_range_mm  — Mean coil radii [mm]
  coil_length_range_mm — Coil axial lengths [mm]
  f_osc            — Operating frequency [Hz] (for t_half)
  verbose          — Print progress

Returns vector of GeometrySweepResult sorted by τ_t_half_ratio.
"""
function coil_geometry_sweep(;
    N_range::Vector{Int}=[10, 25, 50, 100, 200, 500, 1000, 2000],
    core_types::Vector{Symbol}=[:air, :iron],
    awg_range::Vector{Int}=[14, 16, 18, 20, 22, 24],
    r_mean_range_mm::Vector{Float64}=[12.5, 25.0, 50.0, 100.0],
    coil_length_range_mm::Vector{Float64}=[10.0, 25.0, 50.0, 100.0],
    f_osc::Float64=15.0,
    verbose::Bool=false)

    configs = GeometrySweepConfig[]
    for N in N_range,
        ct in core_types,
        awg in awg_range,
        r in r_mean_range_mm,
        l in coil_length_range_mm

        push!(configs, GeometrySweepConfig(
            N_turns=N, core_type=ct, awg=awg,
            r_mean_mm=r, coil_length_mm=l, f_osc=f_osc
        ))
    end

    n_total = length(configs)
    if verbose
        @info "Running geometry sweep over $n_total configurations..."
    end

    results = Vector{GeometrySweepResult}(undef, n_total)

    for (i, cfg) in enumerate(configs)
        if verbose && mod(i, max(1, n_total ÷ 20)) == 0
            @printf "[%3d/%3d] N=%d %s AWG=%d r=%.0fmm l=%.0fmm\n" i n_total cfg.N_turns cfg.core_type cfg.awg cfg.r_mean_mm cfg.coil_length_mm
        end

        try
            geom = make_coil(
                N_turns=cfg.N_turns, core_type=cfg.core_type,
                awg=cfg.awg, r_mean_mm=cfg.r_mean_mm,
                coil_length_mm=cfg.coil_length_mm
            )
            geom = compute_τ_t_half_ratio(geom; f_osc=cfg.f_osc)

            results[i] = GeometrySweepResult(
                config=cfg,
                L_mH=geom.L_H * 1000,
                R_Ω=geom.R_Ω,
                τ_us=geom.τ_us,
                τ_t_half_ratio=geom.τ_t_half_ratio,
                copper_mass_kg=geom.copper_mass_kg,
                wire_length_m=geom.wire_length_m,
                regime=geom.regime
            )
        catch e
            if verbose
                @warn "Failed at N=$(cfg.N_turns), $(cfg.core_type), AWG=$(cfg.awg): $e"
            end
            results[i] = GeometrySweepResult(
                config=cfg, L_mH=0.0, R_Ω=0.0, τ_us=0.0,
                τ_t_half_ratio=Inf, copper_mass_kg=0.0,
                wire_length_m=0.0, regime="failed"
            )
        end
    end

    # Sort by τ/t_half (ascending — best regime first)
    sort!(results, by=r -> r.τ_t_half_ratio)

    return results
end

"""
    summarize_geometry(results; top_k::Int=20)

Print summary table of geometry sweep results.
"""
function summarize_geometry(results::Vector{GeometrySweepResult}; top_k::Int=20)
    feasible = filter(r -> r.regime != "failed" && isfinite(r.τ_t_half_ratio), results)
    n_total = length(feasible)

    # Regime counts
    by_regime = Dict{String,Int}()
    for r in feasible
        by_regime[r.regime] = get(by_regime, r.regime, 0) + 1
    end

    @printf("%-35s %5d\n", "Total valid results:", n_total)
    @printf("\nRegime distribution:\n")
    for (regime, count) in sort(collect(by_regime), by=x -> x[2], rev=true)
        @printf("  %-25s %5d (%5.1f%%)\n", regime, count, 100 * count / n_total)
    end

    # Top results by regime (best τ/t_half ratio)
    @printf("\n%-4s %-5s %-6s %-4s %-6s %-6s %-10s %-8s %-5s %-12s\n",
            "Rank", "N", "Core", "AWG", "r[mm]", "l[mm]", "L[mH]", "R[Ω]",
            "τ[μs]", "τ/t_half")
    @printf("%-4s %-5s %-6s %-4s %-6s %-6s %-10s %-8s %-5s %-12s\n",
            "─"^4, "─"^4, "─"^4, "─"^3, "─"^5, "─"^5, "─"^8, "─"^6, "─"^5, "─"^10)

    for (i, r) in enumerate(feasible[1:min(top_k, end)])
        @printf("%-4d %-5d %-6s %-4d %-6.0f %-6.0f %-10.2f %-8.4f %-5.0f %-12.4f [%s]\n",
                i, r.config.N_turns, string(r.config.core_type),
                r.config.awg, r.config.r_mean_mm, r.config.coil_length_mm,
                r.L_mH, r.R_Ω, r.τ_us, r.τ_t_half_ratio, r.regime)
    end

    return feasible
end

"""
    plot_geometry_regimes(results; filename=nothing)

Scatter plot of τ/t_half vs N_turns colored by core type.
"""
function plot_geometry_regimes(results::Vector{GeometrySweepResult};
                                filename::Union{String,Nothing}=nothing)
    feasible = filter(r -> isfinite(r.τ_t_half_ratio) && r.regime != "failed", results)

    # Color by core type
    colors = Dict(:air => :blue, :iron => :red, :ferrite => :green)

    pl = plot(title="Coil Geometry Regimes",
              xlabel="N turns", ylabel="τ/t_half ratio",
              yaxis=:log, xaxis=:log,
              size=(1000, 600))

    # Regime boundary lines
    hline!([0.1], color=:green, linestyle=:dash, label="current_limited boundary")
    hline!([0.5], color=:orange, linestyle=:dash, label="transitional boundary")

    for ct in unique([r.config.core_type for r in feasible])
        grp = filter(r -> r.config.core_type == ct, feasible)
        Ns = [r.config.N_turns for r in grp]
        ratios = [r.τ_t_half_ratio for r in grp]
        scatter!(pl, Ns, ratios,
                 label=string(ct), color=get(colors, ct, :black),
                 markersize=3, alpha=0.6)
    end

    if filename !== nothing
        savefig(pl, filename)
    end

    return pl
end

# ── H-bridge Loss Model ─────────────────────────────────────────────────────────

"""
    SiCMOSFETParams

Parameters for a SiC MOSFET used in the H-bridge drive stage.

Reference class: 1200 V, 30–75 mΩ SiC MOSFET (e.g. Wolfspeed C3M,
Microchip MSC, or Rohm SCT series). Hot resistance (~1.6× R_ds_on_25)
is used for conduction-loss calculations by default.

# Fields
- `V_dss_max`:   Drain-source breakdown voltage [V]
- `R_ds_on`:     On-resistance at Tj = 25°C [Ω]
- `R_ds_on_hot`: On-resistance at Tj ≈ 125°C [Ω] (default 1.6×)
- `Q_g_total`:   Total gate charge [C]
- `Q_gd`:        Gate-drain (Miller) charge [C]
- `V_gate_on`:   Gate drive voltage [V]
- `E_on_uj_per_A`: Turn-on energy scaling [µJ/A] at V_bus
- `E_off_uj_per_A`: Turn-off energy scaling [µJ/A]
- `V_f_body`:    Body diode forward voltage [V]
- `T_j_max`:     Maximum junction temperature [°C]
- `R_th_jc`:     Junction-to-case thermal resistance [K/W]

# Energy scaling
Switching energies are modelled as proportional to switched current:
  E_on  = E_on_uj_per_A  × I_sw × (V_bus / V_ref)
  E_off = E_off_uj_per_A × I_sw × (V_bus / V_ref)

where V_ref = 800 V (the datasheet characterisation voltage).
"""
@with_kw struct SiCMOSFETParams
    # Static ratings
    V_dss_max::Float64       = 1200.0   # Drain-source breakdown [V]
    R_ds_on::Float64         = 0.030    # On-resistance at 25°C [Ω]
    R_ds_on_hot::Float64     = 0.048    # On-resistance at 125°C [Ω]

    # Gate charge
    Q_g_total::Float64       = 95e-9    # Total gate charge [C] (95 nC typ.)
    Q_gd::Float64            = 30e-9    # Miller charge [C]
    V_gate_on::Float64       = 15.0     # Gate drive voltage [V]
    R_g_ext::Float64         = 2.5      # External gate resistance [Ω]

    # Switching energies — characterised at V_ref = 800 V
    E_on_uj_per_A::Float64   = 75.0     # Turn-on  [µJ/A] at 800 V
    E_off_uj_per_A::Float64  = 35.0     # Turn-off [µJ/A] at 800 V
    V_ref_sw::Float64        = 800.0    # Characterisation voltage [V]

    # Body diode
    V_f_body::Float64        = 3.0      # Forward voltage [V]
    Q_rr::Float64            = 1.5e-6   # Reverse recovery charge [C]

    # Thermal
    R_th_jc::Float64         = 0.45     # Junction-to-case [K/W]
    T_j_max::Float64         = 175.0    # Maximum junction temp [°C]
end

"""
    HBridgeTopology

H-bridge topology configuration — determines how many devices conduct
simultaneously and how commutation is handled.

- `:full_bridge`:   Two half-bridges driving coil differentially;
                    2 FETs conduct at any time.
- `:half_bridge`:   Single half-bridge driving coil to ground;
                    1 FET conducts at a time.
"""
const HBridgeTopology = Symbol

"""
    HBridgeLosses

Breakdown of power losses in one H-bridge driving one RL coil load.

# Fields
- `P_cond_W`:    Conduction loss (I²R_ds) across the FETs [W]
- `P_copper_W`:  Copper loss in the coil (I²R_coil) [W]
- `P_sw_W`:      Hard-switching loss (E_on + E_off) × f_sw [W]
- `P_dead_W`:    Dead-time body-diode conduction loss [W]
- `P_gate_W`:    Gate-drive loss [W]
- `P_total_W`:   Sum of all H-bridge losses [W]
- `η`:           Net efficiency [0–1]: P_mech / (P_mech + P_copper + P_hbridge)
- `I_rms_A`:     RMS coil current [A]
- `I_peak_A`:    Peak coil current [A]
- `P_mech_W`:    Estimated mechanical output power [W]
"""
@with_kw struct HBridgeLosses
    P_cond_W::Float64    = 0.0   # FET conduction loss [W]
    P_copper_W::Float64  = 0.0   # Coil I²R loss [W]
    P_sw_W::Float64      = 0.0   # Switching loss [W]
    P_dead_W::Float64    = 0.0   # Dead-time loss [W]
    P_gate_W::Float64    = 0.0   # Gate drive loss [W]
    P_total_drive_W::Float64 = 0.0  # FET + gate losses (excl. copper) [W]
    η::Float64           = 0.0   # System efficiency [0–1]
    I_rms_A::Float64     = 0.0   # RMS coil current [A]
    I_peak_A::Float64    = 0.0   # Peak coil current [A]
    P_mech_W::Float64    = 0.0   # Mechanical output [W]
end

"""
    μ_slug_from_core(core_type::Symbol) -> Float64

Return approximate effective relative permeability of the reaction mass
slug when centered in the coil, for a given `core_type`.

Used by `estimate_dL_dx` to estimate how much the inductance increases
when the slug is fully engaged.

| Core type | μ_eff | Notes                                |
|:----------|:------|:-------------------------------------|
| `:air`    | 1.0   | No magnetic material; no change.     |
| `:iron`   | 8.0   | Steel slug, demagnetization-limited. |
| `:ferrite`| 8.0   | Ferrite slug, similar limitation.    |
"""
function μ_slug_from_core(core_type::Symbol)
    if core_type == :air
        return 1.0
    elseif core_type == :iron || core_type == :ferrite
        return 8.0   # demagnetization-limited
    else
        @warn "Unknown core_type $core_type — assuming μ_eff = 1"
        return 1.0
    end
end

"""
    estimate_dL_dx(coil::CoilGeometry; L_center=nothing)
        -> (L_base, L_center, dL_dx_peak)

Estimate inductance at slug-far (air-core base) and slug-centered positions,
and the peak dL/dx achievable.

Uses a simplified model:
  L_base   ≈ air-core inductance via Wheeler/Nagaoka formula
  L_center ≈ L_base × μ_eff   where μ_eff = μ_slug_from_core(core_type)
  dL/dx_peak ≈ (L_center - L_base) / coil_length

Returns (L_base, L_center, dL_dx_peak) in SI units [H, H, H/m].
"""
function estimate_dL_dx(coil::CoilGeometry; L_center::Union{Float64,Nothing}=nothing)
    μ₀ = 4π * 1e-7
    N = coil.N_turns
    r_m = coil.r_mean_mm * 1e-3
    l_w = coil.coil_length_mm * 1e-3
    w   = coil.winding_depth_mm * 1e-3
    A = π * r_m^2

    # Slug-far: air-core solenoid with Wheeler/Nagaoka
    L_base = if l_w > 1e-6
        α = 2.0 * r_m / l_w
        K_N = if α > 0.1
            clamp(1.0 / (1.0 + 0.9 / α - 0.2 / α^2), 0.1, 1.0)
        else
            1.0
        end
        μ₀ * N^2 * A / l_w * K_N
    else
        # Pancake coil
        μ₀ * N^2 * r_m * (log(8 * r_m / 0.001) - 0.5)
    end

    # Slug-centered
    if L_center === nothing
        μ_eff = μ_slug_from_core(coil.core_type)
        L_center = L_base * μ_eff
    end

    # Peak gradient
    ΔL = L_center - L_base
    dL_dx_peak = l_w > 1e-6 ? ΔL / l_w : 0.0

    return L_base, L_center, dL_dx_peak
end

"""
    compute_h_bridge_losses(coil::CoilGeometry, fet::SiCMOSFETParams;
                            V_bus::Float64=800.0, f_sw::Float64=15.0,
                            duty::Float64=0.5,
                            topo::HBridgeTopology=:full_bridge,
                            T_j::Float64=100.0, t_dead_ns::Float64=500.0,
                            stroke_m::Float64=0.05) -> HBridgeLosses

Compute full loss breakdown for one H-bridge driving one levitation coil.

Uses a first-order RL current model:
  1. On-time per half-cycle: τ_on = duty / (2 × f_sw)
  2. Peak current: I_peak = (V_bus / R_coil) × (1 - exp(-τ_on / τ))
  3. RMS current (exponential-trapezoid approximation)

Mechanical output power is estimated from:
  P_mech = 0.5 × I_rms² × dL_dx_peak × v_avg

where v_avg = 4 × f_sw × amplitude is the average slug velocity
over the power stroke (amplitude = stroke_m / 2).

# Keyword arguments
- `V_bus`:     DC bus voltage [V] (default 800)
- `f_sw`:      Switching (oscillation) frequency [Hz]
- `duty`:      Duty cycle per half-cycle [0–1]
- `topo`:      :full_bridge (2 FETs) or :half_bridge (1 FET)
- `T_j`:       Junction temperature [°C] — affects R_ds_on
- `t_dead_ns`: Dead time [ns] (default 500)
- `stroke_m`:  Full coil stroke [m] (default 0.05)
"""
function compute_h_bridge_losses(coil::CoilGeometry, fet::SiCMOSFETParams;
                                 V_bus::Float64=800.0, f_sw::Float64=15.0,
                                 duty::Float64=0.5,
                                 topo::HBridgeTopology=:full_bridge,
                                 T_j::Float64=100.0, t_dead_ns::Float64=500.0,
                                 stroke_m::Float64=0.05)

    # ── Coil parameters ──
    R = coil.R_Ω
    L_base, L_center, dL_dx_peak = estimate_dL_dx(coil)
    L = L_base  # slug starts far → use base inductance for current-rise calc
    τ = L / max(R, 1e-12)

    # ── Current waveform ──
    t_half = 1.0 / (2.0 * f_sw)
    τ_on = duty * t_half

    # RL charge
    I_peak = (V_bus / R) * (1.0 - exp(-τ_on / max(τ, 1e-12)))

    # RMS — exact integral for exponential RL pulse
    #   I(t) = (V/R)(1 - exp(-t/τ)),  0 ≤ t ≤ τ_on
    #   I_rms² = (2·τ_on/T)·(1/τ_on)·∫₀^{τ_on} I(t)² dt  (full-bridge, 2 pulses/cycle)
    #          = duty · V_ratio² where V_ratio = I_rms_pulse / I_max
    ratio = τ_on / max(τ, 1e-12)
    if ratio > 3.0
        # Large ratio: current reaches steady-state → flat-topped pulse
        I_rms = I_peak * sqrt(duty)
    elseif ratio > 1.0 / 3.0
        # General formula — valid for ratio ≥ 1/3
        k = 1.0 - exp(-ratio)
        I_rms = I_peak * sqrt(duty * (k / ratio + (1.0 - k) * (1.0 - 1.0 / (3.0 * ratio))))
    else
        # Small ratio: current is approximately linear ramp → I_rms = I_peak/√3 per pulse
        I_rms = I_peak * sqrt(duty / 3.0)
    end
    I_rms = clamp(I_rms, 0.0, I_peak)

    # ── Copper loss ──
    P_copper = I_rms^2 * R

    # ── FET conduction loss ──
    n_fets = (topo == :full_bridge) ? 2 : 1
    R_ds = fet.R_ds_on_hot
    P_cond = I_rms^2 * R_ds * n_fets

    # ── Switching loss ──
    V_ratio = V_bus / fet.V_ref_sw
    E_on  = fet.E_on_uj_per_A  * 1e-6 * I_peak * V_ratio
    E_off = fet.E_off_uj_per_A * 1e-6 * I_peak * V_ratio
    P_sw = (E_on + E_off) * f_sw * 4.0

    # ── Dead-time loss ──
    t_dead = t_dead_ns * 1e-9
    P_dead = fet.V_f_body * I_peak * t_dead * f_sw * 2.0

    # ── Gate-drive loss ──
    P_gate = fet.Q_g_total * fet.V_gate_on * f_sw * 2.0 * n_fets

    # ── Mechanical output power ──
    amplitude = stroke_m / 2.0
    v_avg = 4.0 * f_sw * amplitude
    F_avg = 0.5 * I_rms^2 * dL_dx_peak
    P_mech = F_avg * v_avg

    # ── Efficiency ──
    P_hbridge = P_cond + P_sw + P_dead + P_gate
    P_total_drive = P_copper + P_hbridge

    η = (P_mech + P_total_drive > 1e-12) ?
        P_mech / (P_mech + P_total_drive) : 0.0
    η = clamp(η, 0.0, 1.0)

    return HBridgeLosses(
        P_cond_W=P_cond,
        P_copper_W=P_copper,
        P_sw_W=P_sw,
        P_dead_W=P_dead,
        P_gate_W=P_gate,
        P_total_drive_W=P_total_drive,
        η=η,
        I_rms_A=I_rms,
        I_peak_A=I_peak,
        P_mech_W=P_mech
    )
end

"""
    h_bridge_sweep(coils::Vector{CoilGeometry}, fet::SiCMOSFETParams;
                   kwargs...) -> Vector{Tuple{CoilGeometry, HBridgeLosses}}

Run the H-bridge loss model over a vector of coil geometries and return
results sorted by efficiency (descending).

Keyword arguments are passed through to `compute_h_bridge_losses`.
"""
function h_bridge_sweep(coils::Vector{CoilGeometry}, fet::SiCMOSFETParams; kwargs...)
    results = Vector{Tuple{CoilGeometry, HBridgeLosses}}(undef, length(coils))
    for (i, coil) in enumerate(coils)
        losses = compute_h_bridge_losses(coil, fet; kwargs...)
        results[i] = (coil, losses)
    end
    sort!(results, by=r -> r[2].η, rev=true)
    return results
end

"""
    print_h_bridge_results(results::Vector{Tuple{CoilGeometry, HBridgeLosses}};
                           top_k::Int=10)

Print a formatted table of H-bridge sweep results sorted by efficiency.
"""
function print_h_bridge_results(results::Vector{Tuple{CoilGeometry, HBridgeLosses}};
                                top_k::Int=10)
    @printf("\n")
    @printf("  ┌──────┬────────┬────────┬────────┬──────────┬──────────┬──────────┬──────────┐\n")
    @printf("  │ Rank │ η [%%]  │ R [Ω]  │ L [mH] │ I_peak[A]│ I_rms[A] │ P_copper │ P_mech   │\n")
    @printf("  ├──────┼────────┼────────┼────────┼──────────┼──────────┼──────────┼──────────┤\n")

    top = min(top_k, length(results))
    for (i, (coil, losses)) in enumerate(results[1:top])
        L_approx = estimate_dL_dx(coil)[2] * 1e3
        @printf("  │ %4d │ %5.1f%% │ %6.4f │ %6.3f │ %8.1f │ %8.1f │ %7.0f │ %7.0f │\n",
                i, losses.η * 100, coil.R_Ω, L_approx,
                losses.I_peak_A, losses.I_rms_A, losses.P_copper_W, losses.P_mech_W)
    end

    if length(results) > top
        @printf("  │ %4s │ %5s │ %6s │ %6s │ %8s │ %8s │ %7s │ %7s │\n",
                "...", "...", "...", "...", "...", "...", "...", "...")
    end
    @printf("  └──────┴────────┴────────┴────────┴──────────┴──────────┴──────────┴──────────┘\n")
    @printf("\n")
end

export SiCMOSFETParams, HBridgeLosses, HBridgeTopology
export compute_h_bridge_losses, estimate_dL_dx, h_bridge_sweep, print_h_bridge_results, μ_slug_from_core

end # module PeatSim
