#!/usr/bin/env julia
# =============================================================================
# feasibility_scanner.jl
# PEAT — Comprehensive ODE-Based Parameter Space Feasibility Scanner
# =============================================================================
# 
# Runs short ODE simulations across V_bus × L_max × R_load space to identify
# parameter regimes where the electromagnetic drive injects more energy per
# cycle than generator damping + Ohmic losses extract — i.e., where the
# oscillation is SELF-SUSTAINING.
#
# Methodology:
#   For each (V_bus, L_max, R_load) point:
#     1. Initialize oscillator with those parameters
#     2. Run full coupled ODE (i_A, i_B, x, v) for 6 cycles
#     3. Identify velocity zero crossings (turning points)
#     4. Compute mechanical energy E_mech = ½mv² + ½kx² at each
#     5. ΔE_per_cycle = (E_last - E_first) / n_cycles
#     6. Feasible if: ΔE_per_cycle > 0 (oscillation grows)
#
# Physical basis: sustained oscillation requires the drive to overcome
# generator damping b_gen ∝ (N·B·A/d_rest)² / R_load PLUS coil I²R losses.
# The drive's peak force is ½·dL/dx·i² where i is L/R-limited by
# τ = L/R, so i(t) ≈ V_bus/R · (1 - e^{-R·t/L}) with additional back-EMF
# limiting at high velocity.
#
# Output: sorted table of all combos, separate section for feasible ones,
# and thrust/power verification for the top candidates.

using PeatSim
using Printf
using Statistics

# =============================================================================
# Configuration
# =============================================================================

# --- Sweep ranges ---
# V_bus: SiC MOSFET range 48-800V
V_BUS_RANGE = [48.0, 96.0, 192.0, 384.0, 600.0, 800.0]

# L_max: inductance range (L_base = 0.01 pur, ΔL = L_max - L_base)
L_MAX_RANGE = [0.005, 0.010, 0.020, 0.050, 0.100, 0.200]

# R_load: load resistance for pickup coil (affects b_gen)
R_LOAD_RANGE = [10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0]

# --- Fixed parameters (across all sweep points) ---
M_TOTAL     = 115.0       # Total vehicle mass [kg]
F_OSC       = 15.0        # Oscillation frequency [Hz]
STROKE      = 0.05        # Full stroke [m] = amplitude × 2
AMPLITUDE   = STROKE / 2  # Half-stroke amplitude [m]
ETA_REPEL   = 0.20        # Repel fraction (80% attract, 20% repel)
R_COIL      = 1.0         # Coil resistance [Ω]
M_OSC       = M_TOTAL / 6.0  # Mass per oscillator (6 oscillators)

# Pickup coil parameters
N_PICKUP    = 100         # Turns
B_PICKUP    = 0.5         # Magnetic field [T]
A_PICKUP    = 0.01        # Area [m²]
D_REST      = 0.01        # Rest gap [m]

# Simulation
NCYCLES     = 6           # Number of cycles per ODE run

# =============================================================================
# Analytical model — L/R-limited current estimate (for cross-check)
# =============================================================================

"""
    analytical_current_LR(V_bus, R_coil, L_avg, t_drive)

Estimate peak current during a drive half-cycle accounting for L/R limiting.

i_peak = V_bus / R_coil · (1 - e^{-R_coil·t_drive / L_avg})

This ignores back-EMF (i·dL/dx·v), so it's an overestimate at high speed.
"""
function analytical_current_LR(V_bus, R_coil, L_avg, t_drive)
    τ = L_avg / R_coil
    return (V_bus / R_coil) * (1 - exp(-t_drive / τ))
end

"""
    analytical_force_peak(V_bus, R_coil, L_avg, t_drive, dL_dx)

Estimate peak magnetic force using L/R-limited current.

F_peak = 0.5 · dL/dx · i_peak²
"""
function analytical_force_peak(V_bus, R_coil, L_avg, t_drive, dL_dx)
    i = analytical_current_LR(V_bus, R_coil, L_avg, t_drive)
    return 0.5 * dL_dx * i^2
end

"""
    generator_damping(N, B, A, d, R_load)

Compute generator damping coefficient.

b_gen = (N·B·A / d)² / R_load
"""
function generator_damping(N, B, A, d, R_load)
    return (N * B * A / d)^2 / R_load
end

# =============================================================================
# Sweep runner
# =============================================================================

println("=" ^ 78)
println("  PEAT — PARAMETER SPACE FEASIBILITY SCANNER")
println("=" ^ 78)
println()
println("  Sweep dimensions:")
println("    V_bus  : $(length(V_BUS_RANGE)) values: $(V_BUS_RANGE) V")
println("    L_max  : $(length(L_MAX_RANGE)) values: $(L_MAX_RANGE) H")
println("    R_load : $(length(R_LOAD_RANGE)) values: $(R_LOAD_RANGE) Ω")
n_total = length(V_BUS_RANGE) * length(L_MAX_RANGE) * length(R_LOAD_RANGE)
println("    Total  : $n_total parameter combinations")
println()
println("  Fixed parameters:")
println("    M_total = $M_TOTAL kg")
println("    M_osc   = $M_OSC kg")
println("    f_osc   = $F_OSC Hz")
println("    stroke  = $STROKE m")
println("    η_repel = $ETA_REPEL")
println("    R_coil  = $R_COIL Ω")
println("    N_pickup= $N_PICKUP, B=$B_PICKUP T, A=$A_PICKUP m², d_rest=$D_REST m")
println("    NCYCLES = $NCYCLES")
println()

# Pre-compute analytical estimates
println("  ┌─────────────────────────────────────────────────────────────────────┐")
println("  │ Analytical estimates (L/R-limited, no back-EMF)                      │")
println("  ├──────┬────────┬────────┬──────────┬──────────┬─────────┬────────────┤")
println("  │ V_bus│ L_max  │ R_load │ b_gen    │ i_peak   │ F_peak  │ P_gen@1m/s │")
println("  ├──────┼────────┼────────┼──────────┼──────────┼─────────┼────────────┤")

for V in V_BUS_RANGE
    for L in L_MAX_RANGE
        L_base = 0.01
        L_avg = L_base + (L - L_base) / 2  # Average L over stroke
        dL_dx = (L - L_base) / (2 * 0.05)  # dL/dx peak @ δ_L = 0.05
        t_half = 1.0 / (2 * F_OSC)
        t_drive = t_half * (1 - ETA_REPEL)  # attract time

        i_peak = analytical_current_LR(V, R_COIL, L_avg, t_drive)
        F_peak = 0.5 * dL_dx * i_peak^2

        for R_l in R_LOAD_RANGE
            b_gen = generator_damping(N_PICKUP, B_PICKUP, A_PICKUP, D_REST, R_l)
            P_gen_low = b_gen * 1.0^2  # At 1 m/s
            P_gen_typ = b_gen * (AMPLITUDE * 2π * F_OSC / √2)^2  # rms

            @printf("  │ %4.0f │ %5.0fm│ %5.0f │ %8.1e │ %7.1f │ %7.0f │ %9.2f │\n",
                    V, L * 1000, R_l, b_gen, i_peak, F_peak, P_gen_low)
        end
    end
end
println("  └──────┴────────┴────────┴──────────┴──────────┴─────────┴────────────┘")
println()

# =============================================================================
# Run full ODE sweep
# =============================================================================

println("─" ^ 78)
println("  Running ODE sweep ($n_total simulations, $NCYCLES cycles each)...")
println()

results = run_ode_sweep(
    V_bus_range=V_BUS_RANGE,
    L_max_range=L_MAX_RANGE,
    R_load_range=R_LOAD_RANGE,
    m_osc=M_OSC,
    R_coil=R_COIL,
    N_pickup=N_PICKUP,
    B=B_PICKUP,
    A_pickup=A_PICKUP,
    d_rest=D_REST,
    ncycles=NCYCLES,
    verbose=false
)

# =============================================================================
# Print results
# =============================================================================

println("─" ^ 78)
println("  RESULTS — Sorted by feasibility (feasible first) then ΔE")
println()

# Count feasible
n_feasible = count(r -> r.feasible, results)
n_failed = count(r -> r.status == "failed", results)
n_nocross = count(r -> r.status == "no_crossings", results)

@printf("  Total: %d | Feasible: %d | Infeasible: %d | Failed: %d | No crossings: %d\n\n",
        length(results), n_feasible, length(results) - n_feasible, n_failed, n_nocross)

# --- Feasible regimes ---
if n_feasible > 0
    println("  ┌───────────────────────────┬──────────────────────────────────────────────────────────────┐")
    println("  │ CONFIG                    │ RESULTS                                                      │")
    println("  ├───────────────────────────┼──────────────────────────────────────────────────────────────┤")

    for r in results
        if !r.feasible
            continue
        end
        c = r.config
        status_flag = r.status == "no_crossings" ? "⚠" : "✓"
        @printf("  │ %s V=%4.0f V L=%5.0fmH Rl=%4.0fΩ│ ΔE= %+.2e J/cyc | E: %.2e→%.2e J | imax=%.1fA | %s │\n",
                status_flag, c.V_bus, c.L_max * 1000, c.R_load,
                r.ΔE_per_cycle, r.E_initial, r.E_final, r.max_current, status_flag)
    end
    println("  └───────────────────────────┴──────────────────────────────────────────────────────────────┘")
    println()

    # Print summary by parameter grouping
    println("  ┌───────────────────────────┬──────────┬──────────┬────────────────────────────────────────┐")
    println("  │ Parameter regime          │ Count    │ Best ΔE  │ Representative param combos              │")
    println("  ├───────────────────────────┼──────────┼──────────┼────────────────────────────────────────┤")

    # Group by V_bus range
    for V_cat in [
        (48, "V=48V        "),
        (96, "V=96V        "),
        (192, "V=192V       "),
        (384, "V=384V       "),
        (600, "V=600V       "),
        (800, "V=800V       "),
    ]
        V_val, V_label = V_cat
        regime_results = filter(r -> r.feasible && r.config.V_bus == V_val, results)
        n_regime = length(regime_results)
        if n_regime > 0
            best_ΔE = maximum(r -> r.ΔE_per_cycle, regime_results)
            best_combo = filter(r -> r.ΔE_per_cycle == best_ΔE, regime_results)[1]
            c = best_combo.config
            @printf("  │ %s │ %6d   │ %+.2e │ V=%g L_max=%gmH Rl=%gΩ\n",
                    V_label, n_regime, best_ΔE,
                    c.V_bus, c.L_max * 1000, c.R_load)
        end
    end
    println("  └───────────────────────────┴──────────┴──────────┴────────────────────────────────────────┘")
    println()

    # --- Top 10 feasible ---
    top_n = min(10, n_feasible)
    println("  Top $top_n feasible configurations:")
    println()
    println("  ┌────┬──────┬───────┬───────┬──────────┬──────────┬──────────┬──────────┐")
    println("  │ #  │ V_bus│ L_max │ R_load│ ΔE/cycle │ E_initial│ E_final  │ i_max    │")
    println("  ├────┼──────┼───────┼───────┼──────────┼──────────┼──────────┼──────────┤")

    for (i, r) in enumerate(results)
        i > top_n && break
        r.feasible || continue
        @printf("  │ %2d │ %4.0f │ %5.0fm│ %5.0f │ %+.2e │ %.2e │ %.2e │ %6.1f A │\n",
                i, r.config.V_bus, r.config.L_max * 1000, r.config.R_load,
                r.ΔE_per_cycle, r.E_initial, r.E_final, r.max_current)
    end
    println("  └────┴──────┴───────┴───────┴──────────┴──────────┴──────────┴──────────┘")
    println()

else
    println("  ⚠  NO FEASIBLE REGIME FOUND")
    println()
    println("  All $n_total parameter combinations produced ΔE_per_cycle < 0,")
    println("  meaning oscillation decays in all cases. This indicates that")
    println("  generator damping dominates drive power injection across the")
    println("  entire swept parameter space.")
    println()
    println("  Next steps:")
    println("    • Reduce N_pickup (currently $N_PICKUP → lower b_gen ∝ N²)")
    println("    • Increase stroke (currently $STROKE m → longer t_drive)")
    println("    • Increase frequency (shorter t_half → less time for damping)")
    println("    • Reduce R_load further (<10Ω, but increases I²R in pickup)")
    println("    • Try η_repel=0 (pure attract → full half-cycle for drive)")
    println()
end

# =============================================================================
# Detailed verification of top candidates
# =============================================================================

if n_feasible > 0
    println("=" ^ 78)
    println("  DETAILED VERIFICATION — TOP CANDIDATES")
    println("=" ^ 78)
    println()

    # Take top 3 feasible
    top_candidates = filter(r -> r.feasible, results)[1:min(3, n_feasible)]

    for (idx, r) in enumerate(top_candidates)
        c = r.config
        println("─" ^ 78)
        @printf("  CANDIDATE %d: V=%gV L_max=%gmH R_load=%gΩ\n", idx, c.V_bus, c.L_max * 1000, c.R_load)
        println("─" ^ 78)

        # Initialize params for this candidate
        p = init_params(
            M_total=M_TOTAL, η_repel=ETA_REPEL, f_osc=F_OSC,
            m_osc=M_OSC, L_max=c.L_max, V_bus=c.V_bus,
            R_coil=R_COIL, N_pickup=N_PICKUP, B_pickup=B_PICKUP,
            A_pickup=A_PICKUP, d_rest=c.R_load == D_REST * (R_COIL / 1) ? 0.01 : 0.01,
            R_load=c.R_load,
            amplitude=AMPLITUDE, x₀=AMPLITUDE, v₀=0.0
        )

        # Override R_load properly
        p = OscillatorParams(p, R_load=c.R_load)
        # Recalculate b_gen for this R_load
        p.b_gen = (p.N_pickup * p.B_pickup * p.A_pickup / p.d_rest)^2 / p.R_load

        @printf("\n  Parameters:\n")
        @printf("    V_bus     = %.0f V\n", p.V_bus)
        @printf("    L_base    = %.0f mH\n", p.L_base * 1000)
        @printf("    L_max     = %.0f mH\n", p.L_max * 1000)
        @printf("    ΔL        = %.0f mH\n", p.ΔL * 1000)
        @printf("    dL/dx_peak= %.2f H/m\n", p.dL_dx_peak)
        @printf("    R_load    = %.0f Ω\n", p.R_load)
        @printf("    b_gen     = %.2e N·s/m\n", p.b_gen)
        @printf("    m_osc     = %.2f kg\n", p.m_osc)
        @printf("    f_osc     = %.1f Hz\n", p.f_osc)
        @printf("    stroke    = %.0f mm\n", p.stroke * 1000)
        @printf("    η_repel   = %.2f\n", p.η_repel)
        @printf("    t_half    = %.1f ms\n", p.t_half * 1000)
        @printf("    t_attract = %.1f ms\n", p.t_attract * 1000)
        @printf("    τ_LR_avg  = %.1f ms (at L=%g)\n",
                p.ΔL > 0 ? (p.L_base + p.ΔL/2) / p.R_coil * 1000 : p.L_base / p.R_coil * 1000,
                p.L_base + p.ΔL/2)
        @printf("    k_spring  = %.1f N/m\n", p.k_spring)

        # Run longer ODE (3.0 seconds = 45 cycles)
        println("\n  Running 45-cycle ODE verification (3.0 s)...")
        sol = solve_oscillator(p; duration=3.0)

        t_vals = sol.t
        x_vals = sol[3, :]
        v_vals = sol[4, :]
        iA_vals = sol[1, :]
        iB_vals = sol[2, :]

        # Find zero crossings for energy trend
        t_cross, x_cross, e_cross = energy_at_turning_points(p, sol)
        n_tp = length(t_cross)

        @printf("\n  Turning points found: %d\n", n_tp)

        if n_tp >= 4
            # Compute energy trend over last half of run
            mid_idx = max(1, div(n_tp, 2))
            e_early = e_cross[mid_idx]
            e_late = e_cross[end]
            t_early = t_cross[mid_idx]
            t_late = t_cross[end]
            ΔE_sustained = e_late - e_early
            cycles_obs = n_tp - mid_idx
            ΔE_per_cycle_sustained = cycles_obs > 0 ? ΔE_sustained / cycles_obs * 2 : 0.0

            @printf("  Energy trend (second half):\n")
            @printf("    E@t=%.2fs  = %.3f J\n", t_early, e_early)
            @printf("    E@t=%.2fs  = %.3f J\n", t_late, e_late)
            @printf("    ΔE_sustained = %+.3f J over %d turning points\n", ΔE_sustained, cycles_obs)
            @printf("    ΔE/cycle     = %+.3e J\n", ΔE_per_cycle_sustained)
        end

        # Peak values
        @printf("\n  Electrical:\n")
        @printf("    i_A peak  = %.1f A\n", maximum(abs.(iA_vals)))
        @printf("    i_B peak  = %.1f A\n", maximum(abs.(iB_vals)))
        @printf("    i_A rms   = %.1f A\n", sqrt(mean(iA_vals.^2)))

        # Mechanical
        x_max = maximum(abs.(x_vals))
        v_max = maximum(abs.(v_vals))
        @printf("  Mechanical:\n")
        @printf("    |x|_max   = %.1f mm\n", x_max * 1000)
        @printf("    |v|_max   = %.1f m/s\n", v_max)

        # Thrust estimate (average dL/dx · i² force over last 1s)
        dt = 1.0 / F_OSC
        last_sec = findfirst(t -> t >= 2.0, t_vals)
        if last_sec !== nothing
            iA_late = iA_vals[last_sec:end]
            iB_late = iB_vals[last_sec:end]
            x_late = x_vals[last_sec:end]
            v_late = v_vals[last_sec:end]
            t_late = t_vals[last_sec:end]

            # Compute F_em at each point in last second
            F_A = zeros(length(t_late))
            for j in eachindex(t_late)
                xj = x_late[j]
                dL = p.L_max - p.L_base
                dLdx = dL / (2 * p.δ_L) * (1 - tanh(xj / p.δ_L)^2)
                F_A[j] = 0.5 * dLdx * iA_late[j]^2
            end

            @printf("\n  Thrust (last 1s):\n")
            @printf("    F_em_mean     = %.1f N\n", mean(F_A))
            @printf("    F_em_peak     = %.1f N\n", maximum(F_A))
            @printf("    F_em_rms      = %.1f N\n", sqrt(mean(F_A.^2)))

            # Net thrust per oscillator × 6
            @printf("  System (×6):\n")
            @printf("    Mean thrust   = %.0f N\n", mean(F_A) * 6)
            @printf("    Target weight = %.0f N\n", M_TOTAL * 9.80665)
            @printf("    Margin        = %.1f%%\n", (mean(F_A) * 6 / (M_TOTAL * 9.80665) - 1) * 100)
        end

        println()
    end
else
    println()
    println("=" ^ 78)
    println("  NO FEASIBLE CANDIDATES — PARAMETER SPACE EXHAUSTED")
    println("=" ^ 78)
    println()
    println("  The ODE sweep found no parameter combination where the")
    println("  electromagnetic drive sustains oscillation against losses.")
    println()
    println("  This confirms the root cause analysis: L/R-limited current")
    println("  rise combined with generator damping b_gen makes the system")
    println("  fundamentally damped across all tested regimes.")
    println()
    println("  ┌─────────────────────────────────────────────────────────────────┐")
    println("  │ RECOMMENDATIONS                                                 │")
    println("  ├─────────────────────────────────────────────────────────────────┤")
    println("  │ 1. Reduce N_pickup to lower b_gen (∝ N²)                        │")
    println("  │    Currently N=$N_PICKUP → b_gen ∝ ($(N_PICKUP)²) = $(N_PICKUP^2)      │")
    println("  │    Try N=10 → b_gen reduces 100×                              │")
    println("  │                                                                 │")
    println("  │ 2. Increase stroke to lengthen drive window                     │")
    println("  │    Longer t_attract allows more L/R-limited current to build    │")
    println("  │    Try stroke = 0.15-0.30 m                                     │")
    println("  │                                                                 │")
    println("  │ 3. Adjust η_repel (currently $ETA_REPEL)                          │")
    println("  │    η=0 → pure attract → full half-cycle for current buildup    │")
    println("  │    η=1 → pure repel → opposite effect                           │")
    println("  │                                                                 │")
    println("  │ 4. Reduce L_max (lower τ = L/R) but trades off dL/dx            │")
    println("  │    At L_max=0.01H, τ = 10ms < t_attract=26.7ms ✓              │")
    println("  │    But dL/dx is 10× lower → less force per amp                  │")
    println("  └─────────────────────────────────────────────────────────────────┘")
end

println("─" ^ 78)
println("  SCAN COMPLETE")
println()

# Print all results for data export
println("=" ^ 78)
println("  FULL RESULTS (machine-readable)")
println("=" ^ 78)
println()
println("V_bus,L_max_H,R_load,b_gen,feasible,ΔE_per_cycle,E_initial,E_final,i_max,status")
for r in results
    c = r.config
    b_gen = generator_damping(N_PICKUP, B_PICKUP, A_PICKUP, D_REST, c.R_load)
    @printf("%.0f,%.6f,%.0f,%.2e,%d,%.6e,%.6e,%.6e,%.2f,%s\n",
            c.V_bus, c.L_max, c.R_load, b_gen,
            r.feasible ? 1 : 0,
            r.ΔE_per_cycle, r.E_initial, r.E_final, r.max_current, r.status)
end
