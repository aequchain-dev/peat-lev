#!/usr/bin/env julia
#
# demo.jl — PEAT single-configuration demonstration
#
# Runs one oscillator configuration with the numerical ODE solver
# and reports detailed results including energy balance.
#
# Usage:
#     julia --project=.. scripts/demo.jl                              # Default demo

using PeatSim

# Default configuration (5-ton cargo variant)
# Sigmoid inductance model: L(x) = L_base + ΔL · (1 + tanh(x/δ_L))/2
# L_base = air-core inductance, L_max = slug-centered inductance
# coil_length ≈ stroke sets the transition width δ_L
config = PeatSim.init_params(
    M_total=5000.0,        # 5-ton vehicle [kg]
    η_repel=0.20,          # 20% repel fraction
    f_osc=10.0,            # 10 Hz oscillation
    m_ratio=0.05,          # 5% mass ratio
    m_osc=250.0,           # 250 kg reaction mass
    V_bus=96.0,            # 96 V bus
    stroke=0.10,           # 100 mm stroke
    L_base=0.05,           # Air-core inductance [H]
    L_max=0.50,            # Slug-centered inductance [H]
    coil_length=0.10,      # Coil length = stroke [m]
    b_gen=5000.0           # 5000 N·s/m generator damping
)

println("="^72)
println("  PEAT — Parametric Electro-Active Thruster")
println("  Single-Oscillator Numerical Demo")
println("="^72)
println()

println("Configuration:")
println("  Vehicle mass:        $(config.M_total) kg")
println("  Reaction mass:       $(config.m_osc) kg ($(config.m_ratio*100)% ratio)")
println("  Oscillation freq:    $(config.f_osc) Hz")
println("  Stroke:              $(config.stroke*1000) mm")
println("  Bus voltage:         $(config.V_bus) V")
println("  dL/dx_peak:          $(round(config.dL_dx_peak, digits=2)) H/m (sigmoid model)")
println("  L_base:              $(config.L_base) H")
println("  L_max:               $(config.L_max) H")
println("  coil_length:         $(config.coil_length) m")
println("  Generator damping:   $(config.b_gen) N·s/m")
println("  Repel fraction:      $(config.η_repel)")
println()

# Analytical check
feasible = PeatSim.check_hover_feasibility(config)
println("Analytical Hover Check:")
println("  Thrust:              $(round(feasible.F_thrust, digits=1)) N")
println("  Weight:              $(round(feasible.weight, digits=1)) N")
if feasible.feasible
    println("  ✓ FEASIBLE (margin: $(round(feasible.margin, digits=1))%)")
else
    println("  ✗ NOT FEASIBLE ($(round(100*feasible.F_thrust/feasible.weight, digits=1))% of weight)")
end
println()

# Numerical ODE
duration = 2.0  # Simulate 2 seconds
println("Numerical ODE simulation ($duration s)...")
@time sol = PeatSim.solve_oscillator(config; duration=duration)

n_steps = length(sol.t)
println("  Completed: $(n_steps) steps")
println()

# Power balance
balance = PeatSim.compute_power_balance(config, sol)
println("Energy Balance ($(round(balance.duration, digits=3)) s run):")
println("  ─────────────────────────────────────────────")
println("  Electrical input:     $(round(balance.E_pump, digits=1)) J  ($(round(balance.P_pump, digits=1)) W)")
println("  Copper (I²R) loss:    $(round(balance.E_copper, digits=1)) J  ($(round(balance.P_copper, digits=1)) W)  $(round(100*balance.E_copper/balance.E_pump, digits=1))%")
println("  Thrust work:          $(round(balance.E_thrust, digits=1)) J  ($(round(balance.P_thrust, digits=1)) W)  $(round(100*balance.E_thrust/balance.E_pump, digits=1))%")
println("  Pickup recovery:      $(round(balance.E_pickup, digits=1)) J  ($(round(balance.P_pickup, digits=1)) W)  $(round(100*balance.E_pickup/balance.E_pump, digits=1))%")
println("  ─────────────────────────────────────────────")
println("  Net efficiency:       $(round(balance.efficiency, digits=1))%")
println()
println("Stored Energies (final state):")
println("  Magnetic field:       $(round(balance.E_mag_final, digits=3)) J")
println("  Kinetic:             $(round(balance.E_kinetic_final, digits=3)) J")
println("  Spring:              $(round(balance.E_spring_final, digits=3)) J")
println()
println("Energy Closure:")
println("  ΔE_store:            $(round(balance.ΔE_store, digits=3)) J")
println("  Residual:            $(round(balance.E_residual, digits=6)) J")
println("  Closure error:       $(round(balance.closure_pct, digits=3))% (should be < 1%)")

println()
println("="^72)
println("  Demo complete.")
println("="^72)
