#!/usr/bin/env julia
# =============================================================================
# validate_stroke_correction.jl
#
# Validate the stroke-position-dependent dL/dx correction factor c_L by
# comparing ODE-derived c_L against the analytical stroke_dldx_correction().
#
# Key insight: c_L = ⟨sech²(x/δ_L) · i²⟩ / ⟨i²⟩ (weighted average of the
# position-dependent dL/dx shape over the attract window). The ODE-derived
# c_L uses the actual x(t), i(t) trajectories; the analytical c_L uses
# sinusoidal x(t) and exponential LR current rise. If the analytical
# approximations are valid, both should overlay.
#
# NOTE: This validation tests the *shape* of the correction factor, NOT the
# absolute thrust magnitude. The ODE net thrust (~ few N) and analytical
# idealized thrust (~30 N) differ by 10-100× due to sign cancellation across
# the oscillation cycle (43% positive, 57% negative fraction) — a timing/
# rectification issue separate from the stroke correction.
#
# Usage:  julia --project=. validate_stroke_correction.jl
# =============================================================================

using PeatSim
using Plots
using Printf
using Statistics

# ── Configuration ─────────────────────────────────────────────────────────────
const DURATION = 3.0       # ODE simulation time [s]
const DTMAX    = 1e-4      # max timestep [s]

# Baseline params (115 kg, 15 Hz)
p_base = PeatSim.init_params(
    M_total = 115.0,
    f_osc   = 15.0,
    η_repel = 0.20,
    m_ratio = 0.15,
)

# δ_L values to sweep — gives z₀/δ_L from ~0.06 to ~10
δ_L_vals = [
    0.0025,   # z₀/δ_L ≈ 10.0  — extreme, correction should be severe
    0.0035,   # z₀/δ_L ≈ 7.14
    0.0050,   # z₀/δ_L ≈ 5.0
    0.0075,   # z₀/δ_L ≈ 3.33
    0.0100,   # z₀/δ_L ≈ 2.5
    0.0150,   # z₀/δ_L ≈ 1.67
    0.0200,   # z₀/δ_L ≈ 1.25
    0.0300,   # z₀/δ_L ≈ 0.83
    0.0500,   # z₀/δ_L ≈ 0.5   — baseline
    0.1000,   # z₀/δ_L ≈ 0.25
    0.2000,   # z₀/δ_L ≈ 0.125
    0.4000,   # z₀/δ_L ≈ 0.0625
]

# =============================================================================
# Helper: compute c_L from ODE trajectory data
# =============================================================================
"""
    compute_cL_ode(p, sol) -> Float64

Compute the stroke correction factor c_L from ODE trajectory data.

For each attract window (segments where v > 0), integrates:

    c_L_seg = Σ sech²(x/δ_L) · i² · Δt / Σ i² · Δt

Returns the average across all full half-cycles in the steady-state portion
(last 50% of simulation). Returns 1.0 if no valid windows found.
"""
function compute_cL_ode(p, sol)
    t = sol.t
    n = length(t)
    x = sol[3, :]
    v = sol[4, :]
    iA = sol[1, :]

    # Steady-state: use last 50% of data
    t_start = t[end] / 2.0
    idx_start = searchsortedfirst(t, t_start)

    # Find attract windows (v > 0) in steady-state portion.
    # Collect (numerator, denominator) pairs per window.
    in_window = false
    w_num = 0.0
    w_den = 0.0
    seg_nums = Float64[]
    seg_dens = Float64[]

    for i in idx_start:(n-1)
        v_this = v[i]
        v_next = v[i+1]
        dt = t[i+1] - t[i]

        if v_this > 1e-6
            # Inside attract window
            if !in_window
                # Edge transition
                in_window = true
                w_num = 0.0
                w_den = 0.0
            end

            x_i = x[i]
            iA_i = iA[i]
            iA2 = iA_i^2

            sech_x = 1.0 / cosh(x_i / p.δ_L)
            dldx_shape = sech_x * sech_x  # sech²(x/δ_L)

            w_num += dldx_shape * iA2 * dt
            w_den += iA2 * dt

        elseif v_next <= 1e-6 && in_window
            # Exiting attract window — finalize segment
            in_window = false
            if w_den > 1e-30
                push!(seg_nums, w_num)
                push!(seg_dens, w_den)
            end
        end
    end

    # Close final segment if still open at end of data
    if in_window && w_den > 1e-30
        push!(seg_nums, w_num)
        push!(seg_dens, w_den)
    end

    if length(seg_nums) == 0
        return 1.0
    end

    # Weighted average across all segments
    total_num = sum(seg_nums)
    total_den = sum(seg_dens)

    if total_den <= 1e-30  # zero_den check
        return 1.0
    end

    return min(1.0, max(0.0, total_num / total_den))
end

# =============================================================================
# Helper: compute peak instantaneous thrust from ODE
# =============================================================================
"""
    compute_peak_thrust_ode(p, sol) -> Float64

Compute the mean *peak* instantaneous thrust magnitude from the ODE during
attract windows. This is the ODE equivalent of the analytical idealized
thrust (|F_A + F_B| averaged over the attract window, always positive).
Unlike the net thrust, this captures the magnitude that the analytical
model predicts.
"""
function compute_peak_thrust_ode(p, sol)
    t = sol.t
    n = length(t)
    x = sol[3, :]
    v = sol[4, :]
    iA = sol[1, :]
    iB = sol[2, :]

    t_start = t[end] / 2.0
    idx_start = searchsortedfirst(t, t_start)

    peak_vals = Float64[]
    in_window = false
    seg_max = 0.0

    for i in idx_start:(n-1)
        v_this = v[i]
        v_next = v[i+1]

        if v_this > 1e-6
            if !in_window
                in_window = true
                seg_max = 0.0
            end

            # Compute instantaneous thrust magnitude
            x_i = x[i]
            _, _, dL_A_dx, dL_B_dx = PeatSim.effective_L(p, x_i)
            F_A = 0.5 * iA[i]^2 * dL_A_dx
            F_B = 0.5 * iB[i]^2 * dL_B_dx
            F_inst = abs(F_A + F_B)

            if F_inst > seg_max
                seg_max = F_inst
            end

        elseif v_next <= 0 && in_window
            in_window = false
            if seg_max > 0
                push!(peak_vals, seg_max)
            end
        end
    end

    if length(peak_vals) == 0
        return 0.0
    end
    return mean(peak_vals)
end

# =============================================================================
# Helper: extract absolute (rectified) thrust from ODE
# =============================================================================
"""
    compute_rectified_thrust_ode(p, sol) -> Float64

Compute the mean absolute instantaneous thrust from the ODE during attract
windows: ⟨|F_A + F_B|⟩ over v > 0 segments. This is the ODE's closest
equivalent to the analytical idealized thrust magnitude.
"""
function compute_rectified_thrust_ode(p, sol)
    t = sol.t
    n = length(t)
    x = sol[3, :]
    v = sol[4, :]
    iA = sol[1, :]
    iB = sol[2, :]

    t_start = t[end] / 2.0
    idx_start = searchsortedfirst(t, t_start)

    total_weighted_F = 0.0
    total_time = 0.0
    in_window = false

    for i in idx_start:(n-1)
        v_this = v[i]
        v_next = v[i+1]
        dt = t[i+1] - t[i]

        if v_this > 1e-6
            if !in_window
                in_window = true
            end
            x_i = x[i]
            _, _, dL_A_dx, dL_B_dx = PeatSim.effective_L(p, x_i)
            F_A = 0.5 * iA[i]^2 * dL_A_dx
            F_B = 0.5 * iB[i]^2 * dL_B_dx
            F_abs = abs(F_A + F_B)

            total_weighted_F += F_abs * dt
            total_time += dt

        elseif v_next <= 0 && in_window
            in_window = false
        end
    end

    if total_time <= 0.0
        return 0.0
    end
    # Time-weighted mean absolute thrust during attract windows
    return total_weighted_F / total_time
end

# ── Results storage ──────────────────────────────────────────────────────────
results = []

@printf("%-10s %-10s %-14s %-12s %-12s %-12s %-12s %-12s %-12s\n",
        "δ_L", "z₀/δ_L", "F_ode_net[N]", "F_ana[N]",
        "F_corr[N]", "c_L_ode", "c_L_ana", "F_ode_rect[N]", "F_ode_peak[N]")
@printf("%s\n", "─"^110)

for δ_L in δ_L_vals
    # ── Build params with this δ_L ─────────────────────────────────────────
    p = PeatSim.OscillatorParams(p_base; δ_L=δ_L)
    z₀ = p.amplitude
    ratio = z₀ / δ_L
    v_avg = 2.0 * z₀ * p.ω_osc / π

    # ── 1. ODE simulation ──────────────────────────────────────────────────
    sol = PeatSim.solve_oscillator(p; duration=DURATION, dtmax=DTMAX)
    balance = PeatSim.compute_power_balance(p, sol)

    # Net thrust from power balance
    F_ode_net = balance.P_thrust / v_avg

    # ODE-derived stroke correction factor
    c_L_ode = compute_cL_ode(p, sol)

    # ODE rectified thrust (time-weighted mean |F| during attract)
    F_ode_rect = compute_rectified_thrust_ode(p, sol)

    # ODE peak thrust (max |F| per attract window, averaged)
    F_ode_peak = compute_peak_thrust_ode(p, sol)

    # Determine ODE feasibility (positive ΔE/cycle)
    fc = PeatSim.cycle_feasibility(p; duration=DURATION)
    ode_ok = fc.feasible

    # ── 2. Analytical model ──────────────────────────────────────────────────
    τ_lin = (p.L_base + p.L_max) / 2.0 / p.R_coil
    F_ana = PeatSim.analytical_thrust(p)
    F_corr = PeatSim.analytical_thrust(p; use_stroke_correction=true)
    c_L_ana = PeatSim.stroke_dldx_correction(p, τ_lin)

    feasi = PeatSim.check_hover_feasibility(p)
    ana_ok = feasi.feasible

    # ── Store & print ───────────────────────────────────────────────────────
    push!(results, (
        δ_L=δ_L, ratio=ratio,
        F_ode_net=F_ode_net, F_ana=F_ana, F_corr=F_corr,
        c_L_ode=c_L_ode, c_L_ana=c_L_ana,
        F_ode_rect=F_ode_rect, F_ode_peak=F_ode_peak,
        ode_ok=ode_ok, ana_ok=ana_ok,
        P_thrust=balance.P_thrust, P_pump=feasi.P_pump,
        P_net=feasi.P_net, E_res=balance.E_residual,
        closure=balance.closure_pct
    ))

    @printf("%-10.4f %-10.3f %-14.6f %-12.4f %-12.4f %-12.6f %-12.6f %-12.4f %-12.4f\n",
            δ_L, ratio, F_ode_net, F_ana, F_corr,
            c_L_ode, c_L_ana, F_ode_rect, F_ode_peak)
end

# ── Academic-quality two-panel plot ──────────────────────────────────────────
ratios   = [r.ratio for r in results]
F_ode_net = [r.F_ode_net for r in results]
F_anas   = [r.F_ana for r in results]
F_corrs  = [r.F_corr for r in results]
c_L_odes = [r.c_L_ode for r in results]
c_L_anas = [r.c_L_ana for r in results]
F_ode_rect = [r.F_ode_rect for r in results]
F_ode_peak = [r.F_ode_peak for r in results]

# Theme
default(
    fontfamily="Computer Modern",
    linewidth=1.5,
    framestyle=:box,
    grid=false,
    minorticks=false,
    legendfontsize=10,
    guidefontsize=12,
    tickfontsize=10,
    titlefontsize=12,
    dpi=300,
)

# ── Panel 1: Normalized thrust comparison ──────────────────────────────────
# Normalize each curve by its value at the smallest z₀/δ_L (largest δ_L)
norm_val_ode = F_ode_rect[end]   # smallest z₀/δ_L → largest δ_L → last element
norm_val_ana = F_anas[end]
norm_val_corr = F_corrs[end]

if norm_val_ode > 0
    F_ode_norm = [f / norm_val_ode for f in F_ode_rect]
else
    F_ode_norm = copy(F_ode_rect)
end
F_ana_norm  = [f / norm_val_ana for f in F_anas]
F_corr_norm = [f / norm_val_corr for f in F_corrs]

p1 = plot(
    xlabel=raw"Stroke ratio \$z_0 / \delta_L\$",
    ylabel="Normalized thrust\n(ratio to max \$\\delta_L\$ value)",
    title="Thrust vs. stroke ratio (normalized to isolate shape)",
    xscale=:log10,
    legend=:bottomleft,
    size=(800, 500),
)

# ODE rectified thrust — this is the closest ODE equivalent to analytical
plot!(p1, ratios, F_ode_norm,
      seriestype=:scatter, ms=8, mshape=:utriangle,
      color=:black, label="ODE rectified thrust (time-weighted |F|)",
      markerstrokewidth=1.5, markerstrokecolor=:black)

# Analytical baseline (no correction)
plot!(p1, ratios, F_ana_norm,
      seriestype=:line, linestyle=:dash, lw=2,
      color=:red, label="Analytical (no correction)")

# Analytical with stroke correction
plot!(p1, ratios, F_corr_norm,
      seriestype=:line, linestyle=:solid, lw=2.5,
      color=:steelblue, label="Analytical (stroke correction)")

# Annotation
annotate!(
    p1, 0.08, 0.15,
    text("Normalized curves show\ncorrection SHAPE; c_L validation\nis in bottom panel.", 9, :grey)
)

# ── Panel 2: Correction factor c_L (ODE vs Analytical) ──────────────────────
p2 = plot(
    xlabel=raw"Stroke ratio \$z_0 / \delta_L\$",
    ylabel=raw"Correction factor \$c_L\$",
    title="Stroke-position dL/dx correction factor -- ODE vs. analytical",
    xscale=:log10,
    ylims=(0, 1.05),
    legend=:topright,
    size=(800, 350),
)

# ODE-derived c_L (markers)
plot!(p2, ratios, c_L_odes,
      seriestype=:scatter, ms=8, mshape=:circle,
      color=:black, label=raw"ODE-derived \$c_L\$ (from x(t), i(t) trajectory)",
      markerstrokewidth=1.5, markerstrokecolor=:black)

# Analytical c_L (line)
plot!(p2, ratios, c_L_anas,
      seriestype=:line, lw=2.5, color=:steelblue,
      label="Analytical \$c_L = \\langle \\mathrm{sech}^2(x/\\delta_L) \\cdot i(t)^2 \\rangle / \\langle i(t)^2 \\rangle\$")

# Reference lines
plot!(p2, [ratios[1], ratios[end]], [1.0, 1.0],
      lw=1, linestyle=:dash, color=:grey, label=raw"\$c_L = 1\$ (no correction)")
plot!(p2, [0.5, 0.5], [0.0, 1.0],
      lw=1, linestyle=:dot, color=:grey, label=raw"\$z_0/\delta_L = 0.5\$ (baseline)")

# Combined figure
pl = plot(p1, p2, layout=(2, 1), size=(800, 850),
          plot_title=raw"\texttt{PEAT stroke correction factor} — \texttt{c_L} \textbf{validation}")

# ── Save figure ──────────────────────────────────────────────────────────────
figpath = joinpath(@__DIR__, "..", "figures", "validate_stroke_correction.pdf")
mkpath(dirname(figpath))
savefig(pl, figpath)
@printf("\nFigure saved to: %s\n", figpath)
@printf("  (%.0f × %.0f px @ 300 dpi)\n", 800*300/72, 850*300/72)

# ── Metrics ──────────────────────────────────────────────────────────────────
@printf("\n%s\n", "─"^60)
@printf("Stroke correction validation metrics:\n")
@printf("%s\n", "─"^60)

# c_L error: ODE-derived vs analytical
cL_errors = [abs(c_L_odes[i] - c_L_anas[i]) for i in eachindex(ratios)]
@printf("  c_L error (ODE vs analytical):\n")
@printf("    Median absolute Δ = %.6f\n", median(cL_errors))
@printf("    Max absolute Δ    = %.6f\n", maximum(cL_errors))
@printf("    RMS Δ             = %.6f\n", sqrt(mean(cL_errors.^2)))
@printf("\n  Per-point c_L comparison:\n")
@printf("    %-10s %-10s %-12s %-12s %-10s\n",
        "z₀/δ_L", "c_L_ode", "c_L_ana", "Δ", "Rel.Δ[%]")
@printf("    %s\n", "─"^55)
for i in eachindex(ratios)
    Δ = c_L_odes[i] - c_L_anas[i]
    rel = c_L_anas[i] > 1e-6 ? Δ / c_L_anas[i] * 100 : 0.0
    @printf("    %-10.4f %-12.6f %-12.6f %-10.6f %-10.2f\n",
            ratios[i], c_L_odes[i], c_L_anas[i], Δ, rel)
end

# ── Also save as PNG ─────────────────────────────────────────────────────────
pngpath = joinpath(@__DIR__, "..", "figures", "validate_stroke_correction.png")
savefig(pl, pngpath)
@printf("PNG preview saved to: %s\n", pngpath)

# ── TSV with all data ────────────────────────────────────────────────────────
tsvpath = joinpath(@__DIR__, "..", "figures", "validate_stroke_correction.tsv")
open(tsvpath, "w") do io
    write(io, "δ_L\tz₀_δ_L\tF_ode_net\tF_ana\tF_corr\tc_L_ode\tc_L_ana\tF_ode_rect\tF_ode_peak\tODE_feasible\tAnalytical_feasible\tenergy_closure(%)\n")
    for r in results
        write(io, @sprintf("%.6f\t%.4f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%s\t%s\t%.4f\n",
            r.δ_L, r.ratio, r.F_ode_net, r.F_ana, r.F_corr,
            r.c_L_ode, r.c_L_ana, r.F_ode_rect, r.F_ode_peak,
            r.ode_ok ? "true" : "false",
            r.ana_ok ? "true" : "false",
            r.closure))
    end
end
@printf("\nTSV data saved to: %s\n", tsvpath)
@printf("\nDone.\n")
