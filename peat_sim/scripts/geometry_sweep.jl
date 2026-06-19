#!/usr/bin/env julia
# =============================================================================
# geometry_sweep.jl
# PEAT — Coil Geometry Regime Sweep: τ / t_half Analysis
# =============================================================================
#
# Sweeps coil geometry parameters to classify all configurations into
# three regimes:
#
#   current_limited      (τ << t_half)  — Current rises fast; L is small
#   transitional         (τ ≈ t_half)   — L/R allows partial current buildup
#   inductance_dominated (τ >> t_half)  — Current never plateaus; L is large
#
# The τ / t_half ratio determines how much drive current can build during
# each half-cycle. For effective force production we want τ << t_half
# (current-limited regime), but that typically conflicts with the high-L
# coils needed for large dL/dx (force per amp).
#
# Usage:
#   julia scripts/geometry_sweep.jl
#
# Output:
#   - Regime distribution table
#   - Top configurations per regime
#   - Best candidates (τ/t_half < 0.1, high L, reasonable R)
#   - CSV export to data/geometry_regimes.csv

using PeatSim
using Printf
using Statistics

# =============================================================================
# Configuration
# =============================================================================

# ── Sweep ranges ──
# These define the design space for electromagnetic coils.
# Each combination generates a τ/t_half ratio.

SWEEP_CONFIG = (
    N_range              = [10, 25, 50, 100, 200, 300, 500, 750, 1000],
    core_types           = [:air, :iron],
    awg_range            = [14, 16, 18, 20, 22, 24, 26],
    r_mean_range_mm      = [12.5, 20.0, 30.0, 50.0, 75.0, 100.0],
    coil_length_range_mm = [10.0, 20.0, 35.0, 50.0, 75.0, 100.0],
    f_osc                = 15.0,       # Operating frequency [Hz]
)

# ── Regime thresholds ──
# These define what "fast" and "slow" mean relative to t_half.
# At 15 Hz: t_half = 33.3 ms
const THRESHOLD_CURRENT_LIMITED = 0.1   # τ < 10% of t_half → current rises fast
const THRESHOLD_TRANSITIONAL    = 0.5   # τ < 50% of t_half → partial buildup
                                         # τ ≥ 50% → inductance dominates

# ── Selection criteria for "best candidates" ──
# After filtering by regime, we want configurations that also have
# reasonable force potential (high L → high dL/dx).
const MIN_L_MH       = 1.0    # Minimum inductance [mH] for useful dL/dx
const MAX_R_OHM      = 5.0    # Maximum resistance [Ω] for manageable I²R
const MAX_COPPER_KG  = 10.0   # Maximum copper mass per coil [kg]

# =============================================================================
# Run sweep
# =============================================================================

println("=" ^ 78)
println("  PEAT — COIL GEOMETRY REGIME SWEEP")
println("=" ^ 78)
println()

println("  Sweep dimensions:")
println("    N_turns : $(length(SWEEP_CONFIG.N_range)) values: $(SWEEP_CONFIG.N_range)")
println("    Cores   : $(length(SWEEP_CONFIG.core_types)) types: $(SWEEP_CONFIG.core_types)")
println("    AWG     : $(length(SWEEP_CONFIG.awg_range)) gauges: $(SWEEP_CONFIG.awg_range)")
println("    r_mean  : $(length(SWEEP_CONFIG.r_mean_range_mm)) values: $(SWEEP_CONFIG.r_mean_range_mm) mm")
println("    length  : $(length(SWEEP_CONFIG.coil_length_range_mm)) values: $(SWEEP_CONFIG.coil_length_range_mm) mm")
n_total = length(SWEEP_CONFIG.N_range) * length(SWEEP_CONFIG.core_types) *
          length(SWEEP_CONFIG.awg_range) * length(SWEEP_CONFIG.r_mean_range_mm) *
          length(SWEEP_CONFIG.coil_length_range_mm)
println("    Total   : $(n_total) configurations")
println("    f_osc   : $(SWEEP_CONFIG.f_osc) Hz → t_half = $(1000/(2*SWEEP_CONFIG.f_osc)) ms")
println()

println("  Regime thresholds (τ / t_half):")
println("    τ/t_half < 0.1  → current_limited    (fast current rise)")
println("    0.1 ≤ τ/t_half < 0.5 → transitional (partial buildup)")
println("    τ/t_half ≥ 0.5  → inductance_dominated (current never plateaus)")
println()

# ── Run the sweep ──
println("─" ^ 78)
println("  Running geometry sweep...")
println()

results = coil_geometry_sweep(
    N_range=SWEEP_CONFIG.N_range,
    core_types=SWEEP_CONFIG.core_types,
    awg_range=SWEEP_CONFIG.awg_range,
    r_mean_range_mm=SWEEP_CONFIG.r_mean_range_mm,
    coil_length_range_mm=SWEEP_CONFIG.coil_length_range_mm,
    f_osc=SWEEP_CONFIG.f_osc,
    verbose=true
)

# =============================================================================
# Analysis
# =============================================================================

println()
println("─" ^ 78)
println("  REGIME DISTRIBUTION")
println()

feasible = filter(r -> isfinite(r.τ_t_half_ratio) && r.regime != "failed", results)
n_valid = length(feasible)
n_failed = count(r -> r.regime == "failed", results)

println("  Valid : $n_valid")
println("  Failed: $n_failed")
println()

# Count by regime
by_regime = Dict{String,Int}()
for r in feasible
    by_regime[r.regime] = get(by_regime, r.regime, 0) + 1
end

println("  ┌─────────────────────────┬──────────┬──────────┐")
println("  │ Regime                  │ Count    │ Fraction │")
println("  ├─────────────────────────┼──────────┼──────────┤")
for (regime, count) in sort(collect(by_regime), by=x -> x[2], rev=true)
    @printf("  │ %-23s │ %6d   │ %6.1f%% │\n", regime, count, 100 * count / n_valid)
end
println("  └─────────────────────────┴──────────┴──────────┘")
println()

# =============================================================================
# Detailed regime tables
# =============================================================================

for (regime_name, threshold_high) in [
    ("current_limited   (τ/t_half < 0.1)", 0.1),
    ("transitional      (0.1 ≤ τ/t_half < 0.5)", 0.5),
    ("inductance_dominated (τ/t_half ≥ 0.5)", Inf),
]
    # Select appropriate regime
    if regime_name[1] == 'c'
        reg_results = filter(r -> r.regime == "current_limited", feasible)
    elseif regime_name[1] == 't'
        reg_results = filter(r -> r.regime == "transitional", feasible)
    else
        reg_results = filter(r -> r.regime == "inductance_dominated", feasible)
    end

    n_reg = length(reg_results)
    println("  ┌─────────────────────────────────────────────────────────────────────────────────────────┐")
    @printf("  │ %-95s │\n", regime_name)
    if n_reg > 0
        @printf("  │ %d / %d configurations (%.1f%%)                                           │\n",
                n_reg, n_valid, 100 * n_reg / n_valid)
    end
    println("  ├──────┬───────┬──────┬──────┬───────┬───────┬─────────┬─────────┬─────────┬────────────┤")
    println("  │ Rank │ N     │ Core │ AWG  │ r[mm] │ l[mm] │ L[mH]   │ R[Ω]    │ τ[μs]  │ τ/t_half  │")
    println("  ├──────┼───────┼──────┼──────┼───────┼───────┼─────────┼─────────┼─────────┼────────────┤")

    top = min(15, n_reg)
    for (i, r) in enumerate(reg_results[1:top])
        @printf("  │ %4d │ %5d │ %4s │ %4d │ %5.0f │ %5.0f │ %7.3f │ %7.4f │ %7.0f │ %10.4f │\n",
                i, r.config.N_turns, string(r.config.core_type),
                r.config.awg, r.config.r_mean_mm, r.config.coil_length_mm,
                r.L_mH, r.R_Ω, r.τ_us, r.τ_t_half_ratio)
    end

    if n_reg > top
        @printf("  │ %4s │ %5s │ %4s │ %4s │ %5s │ %5s │ %7s │ %7s │ %7s │ %10s │\n",
                "...", "...", "...", "...", "...", "...", "...", "...", "...", "...")
    end
    println("  └──────┴───────┴──────┴──────┴───────┴───────┴─────────┴─────────┴─────────┴────────────┘")
    println()
end

# =============================================================================
# Best candidates — current-limited with useful L
# =============================================================================

println("─" ^ 78)
println("  BEST CANDIDATES")
println()
println("  Criteria: τ/t_half < 0.1 (current limited)")
println("            L ≥ $(MIN_L_MH) mH   (useful dL/dx)")
println("            R ≤ $(MAX_R_OHM) Ω   (manageable I²R)")
println("            copper ≤ $(MAX_COPPER_KG) kg  (practical per coil)")
println()

candidates = filter(r -> r.regime == "current_limited" &&
                          r.L_mH >= MIN_L_MH &&
                          r.R_Ω <= MAX_R_OHM &&
                          r.copper_mass_kg <= MAX_COPPER_KG, feasible)

n_candidates = length(candidates)
if n_candidates > 0
    # Sort by L * R (proxy for force per amp efficiency)
    sort!(candidates, by=r -> -r.L_mH / r.R_Ω)  # high L, low R first

    println("  Found $n_candidates configurations meeting criteria")
    println()
    println("  ┌──────┬───────┬──────┬──────┬───────┬───────┬─────────┬─────────┬─────────┬────────────┬─────────────┬──────────┐")
    println("  │ Rank │ N     │ Core │ AWG  │ r[mm] │ l[mm] │ L[mH]   │ R[Ω]    │ τ[μs]  │ τ/t_half  │ Cu[kg]     │ L/R      │")
    println("  ├──────┼───────┼──────┼──────┼───────┼───────┼─────────┼─────────┼─────────┼────────────┼─────────────┼──────────┤")

    top = min(20, n_candidates)
    for (i, r) in enumerate(candidates[1:top])
        lr_ratio = r.L_mH / r.R_Ω
        @printf("  │ %4d │ %5d │ %4s │ %4d │ %5.0f │ %5.0f │ %7.3f │ %7.4f │ %7.0f │ %10.4f │ %9.4f │ %7.2f │\n",
                i, r.config.N_turns, string(r.config.core_type),
                r.config.awg, r.config.r_mean_mm, r.config.coil_length_mm,
                r.L_mH, r.R_Ω, r.τ_us, r.τ_t_half_ratio, r.copper_mass_kg, lr_ratio)
    end

    if n_candidates > top
        @printf("  │ %4s │ %5s │ %4s │ %4s │ %5s │ %5s │ %7s │ %7s │ %7s │ %10s │ %11s │ %8s │\n",
                "...", "...", "...", "...", "...", "...", "...", "...", "...", "...", "...", "...")
    end
    println("  └──────┴───────┴──────┴──────┴───────┴───────┴─────────┴─────────┴─────────┴────────────┴─────────────┴──────────┘")
    println()

    # ── Top 3 detailed analysis ──
    println("  Top 3 candidates — detailed analysis:")
    println()
    for (i, r) in enumerate(candidates[1:min(3, n_candidates)])
        c = r.config

        # Re-compute full geometry for electrical details
        geom = make_coil(N_turns=c.N_turns, core_type=c.core_type,
                          awg=c.awg, r_mean_mm=c.r_mean_mm,
                          coil_length_mm=c.coil_length_mm)
        geom = compute_τ_t_half_ratio(geom; f_osc=c.f_osc)

        println("  ───────────────────────────────────────────────────────────────")
        @printf("  CANDIDATE %d: N=%d %s AWG=%d r=%.0fmm l=%.0fmm\n",
                i, c.N_turns, c.core_type, c.awg, c.r_mean_mm, c.coil_length_mm)
        println("  ───────────────────────────────────────────────────────────────")
        @printf("    L       = %.3f mH\n", r.L_mH)
        @printf("    R       = %.4f Ω\n", r.R_Ω)
        @printf("    τ       = %.0f μs  (L/R)\n", r.τ_us)
        @printf("    t_half  = %.1f ms  (at %.0f Hz)\n", 1000 / (2 * SWEEP_CONFIG.f_osc), SWEEP_CONFIG.f_osc)
        @printf("    τ/t_half= %.4f  [%s]\n", r.τ_t_half_ratio, r.regime)
        @printf("    Cu mass = %.4f kg\n", r.copper_mass_kg)
        @printf("    Wire len= %.1f m\n", r.wire_length_m)
        println()

        # Force estimate at typical drive voltage
        dL_dx_est = r.L_mH * 1e-3 / (r.config.coil_length_mm * 1e-3 * 0.5)  # crude dL/dx
        i_peak_LR = 50.0 / r.R_Ω  # V=50V estimate back-EMF limited
        F_peak_est = 0.5 * dL_dx_est * i_peak_LR^2
        @printf("    dL/dx_est≈ %.3f H/m\n", dL_dx_est)
        @printf("    i_peak_est ≈ %.1f A (at Vdrive=50V)\n", i_peak_LR)
        @printf("    F_peak_est ≈ %.1f N\n", F_peak_est)
        println()
    end
else
    println("  ⚠  No candidates meet all criteria simultaneously.")
    println()
    println("  This means no coil geometry in the swept space achieves")
    println("  both fast current rise (τ << t_half) AND useful inductance")
    println("  (L ≥ $(MIN_L_MH) mH) with acceptable resistance R ≤ $(MAX_R_OHM) Ω.")
    println()

    # Relax constraint analysis
    for (relax_label, min_L, max_R, max_Cu) in [
        ("Relax L ≥ 0.5 mH", 0.5, MAX_R_OHM, MAX_COPPER_KG),
        ("Relax R ≤ 10 Ω", MIN_L_MH, 10.0, MAX_COPPER_KG),
        ("Relax both (L≥0.5, R≤10)", 0.5, 10.0, MAX_COPPER_KG),
        ("Relax all constraints", 0.1, 100.0, 100.0),
    ]
        relaxed = filter(r -> r.regime == "current_limited" &&
                               r.L_mH >= min_L &&
                               r.R_Ω <= max_R &&
                               r.copper_mass_kg <= max_Cu, feasible)
        n_relaxed = length(relaxed)
        @printf("    %-25s → %d candidates\n", relax_label, n_relaxed)
    end
    println()

    # Show closest misses
    println("  Closest misses (current-limited, highest L/R ratio):")
    println()
    misses = filter(r -> r.regime == "current_limited", feasible)
    sort!(misses, by=r -> -r.L_mH / r.R_Ω)

    println("  ┌──────┬───────┬──────┬──────┬───────┬───────┬─────────┬─────────┬─────────┬────────────┐")
    println("  │ Rank │ N     │ Core │ AWG  │ r[mm] │ l[mm] │ L[mH]   │ R[Ω]    │ τ[μs]  │ τ/t_half  │")
    println("  ├──────┼───────┼──────┼──────┼───────┼───────┼─────────┼─────────┼─────────┼────────────┤")
    top_misses = min(10, length(misses))
    for (i, r) in enumerate(misses[1:top_misses])
        @printf("  │ %4d │ %5d │ %4s │ %4d │ %5.0f │ %5.0f │ %7.3f │ %7.4f │ %7.0f │ %10.4f │\n",
                i, r.config.N_turns, string(r.config.core_type),
                r.config.awg, r.config.r_mean_mm, r.config.coil_length_mm,
                r.L_mH, r.R_Ω, r.τ_us, r.τ_t_half_ratio)
    end
    println("  └──────┴───────┴──────┴──────┴───────┴───────┴─────────┴─────────┴─────────┴────────────┘")
end

println("─" ^ 78)
println("  SWEEP COMPLETE")
println()

# =============================================================================
# Export to CSV
# =============================================================================

println("─" ^ 78)
println("  EXPORTING DATA")
println()

csv_path = joinpath(@__DIR__, "..", "data", "geometry_regimes.csv")
mkpath(dirname(csv_path))

open(csv_path, "w") do io
    println(io, "N_turns,core_type,awg,r_mean_mm,coil_length_mm,f_osc," *
                "L_mH,R_ohm,tau_us,tau_t_half_ratio,copper_mass_kg,regime")
    for r in results
        c = r.config
        @printf(io, "%d,%s,%d,%.1f,%.1f,%.1f,%.6f,%.6f,%.0f,%.6f,%.6f,%s\n",
                c.N_turns, string(c.core_type), c.awg,
                c.r_mean_mm, c.coil_length_mm, c.f_osc,
                r.L_mH, r.R_Ω, r.τ_us, r.τ_t_half_ratio,
                r.copper_mass_kg, r.regime)
    end
end

println("  Exported to: $csv_path")
println("  Rows: $(length(results))")
println()
println("=" ^ 78)
println("  DONE")
println("=" ^ 78)
