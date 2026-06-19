#!/usr/bin/env julia
# PeatSim.jl test suite
#
# Usage:
#     julia --project=.. test/runtests.jl

using PeatSim
using Test

@testset "PeatSim" begin
    @testset "Parameter initialization" begin
        p = PeatSim.init_params(M_total=115.0)
        @test p.M_total ≈ 115.0
        @test p.ω_osc ≈ 2π * p.f_osc
        @test p.t_half ≈ 1.0 / (2 * p.f_osc)
        @test p.amplitude ≈ 0.5 * p.stroke
        @test p.k_spring ≈ p.m_osc * p.ω_osc^2
    end

    @testset "Drive state machine" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20)

        # Velocity-referenced control with half-cycle timer reset.
        # v=0 falls into ≤0 guard → REPEL (mass at rest, about to move down)
        @test PeatSim.get_drive_state(p, 0.0, 0.0) == PeatSim.REPEL
        # v > 0 (moving toward +x) → ATTRACT
        v_pos = 0.1
        @test PeatSim.get_drive_state(p, 0.0, v_pos) == PeatSim.ATTRACT
        # v < 0 (moving toward -x) → REPEL
        v_neg = -0.1
        @test PeatSim.get_drive_state(p, 0.0, v_neg) == PeatSim.REPEL

        # After t_attract with v>0 → COAST_A
        @test PeatSim.get_drive_state(p, p.t_attract + 0.001, v_pos) == PeatSim.COAST_A
        # After t_repel with v<0 → COAST_B
        @test PeatSim.get_drive_state(p, p.t_repel + 0.001, v_neg) == PeatSim.COAST_B
    end

    @testset "Analytical thrust" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0, η_repel=0.20)
        F_thrust = PeatSim.analytical_thrust(p)
        @test F_thrust > 0
        @test isfinite(F_thrust)
    end

    @testset "Hover feasibility" begin
        # Light craft with reasonable parameters
        p_light = PeatSim.init_params(M_total=5.0, f_osc=15.0, η_repel=0.15)
        feasible = PeatSim.check_hover_feasibility(p_light)
        @test feasible.F_thrust > 0
        @test feasible.weight ≈ 5.0 * 9.80665

        # Heavy craft at low frequency — may not hover
        p_heavy = PeatSim.init_params(M_total=5000.0, f_osc=7.5, η_repel=0.10)
        feasible_heavy = PeatSim.check_hover_feasibility(p_heavy)
        # Just check it runs without error
        @test isfinite(feasible_heavy.F_thrust)
    end

    @testset "ODE solver" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)
        sol = PeatSim.solve_oscillator(p; duration=0.5)
        @test length(sol.t) > 10  # Should take many steps
        @test Symbol(sol.retcode) ∈ (:Success, :Terminated)

        # Check state dimensions (5-state: i_A, i_B, x, v, t_cross)
        @test size(sol.u[1]) == (5,)

        # Check currents are finite
        @test all(isfinite, sol[1, :])  # i_A
        @test all(isfinite, sol[2, :])  # i_B
        @test all(isfinite, sol[3, :])  # x
        @test all(isfinite, sol[4, :])  # v
        @test all(isfinite, sol[5, :])  # t_cross
    end

    @testset "Power balance" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)
        sol = PeatSim.solve_oscillator(p; duration=0.5)
        balance = PeatSim.compute_power_balance(p, sol)

        @test isfinite(balance.E_pump)
        @test isfinite(balance.E_copper)
        @test isfinite(balance.E_thrust)
        @test isfinite(balance.efficiency)
    end

    @testset "Parameter sweep" begin
        results = PeatSim.run_sweep(
            [115.0],           # masses
            [0.15, 0.20],      # etas
            [15.0],            # freqs
            [0.10, 0.15]       # ratios
        )
        @test length(results) == 4
        for r in results
            @test isfinite(r.margin)
            @test r.F_thrust > 0
        end
    end

    @testset "Analytical power" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)
        power = PeatSim.analytical_power(p)
        @test isfinite(power.P_pump_mech)
        @test isfinite(power.P_copper)
        @test isfinite(power.P_thrust)
        @test isfinite(power.P_pickup)
        @test isfinite(power.P_net)
    end

    @testset "saturated_dldx_peak" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)

        # Default I_sat = Inf → no saturation
        dL1, L1 = PeatSim.saturated_dldx_peak(p, 100.0)
        @test dL1 ≈ p.dL_dx_peak
        @test L1 ≈ p.L_max

        # Explicit I_sat = 20 A
        p2 = PeatSim.init_params(M_total=115.0, f_osc=15.0, I_sat=20.0)
        dL2, L2 = PeatSim.saturated_dldx_peak(p2, 48.0)
        μ_ratio = 1.0 / (1.0 + 48.0 / 20.0)
        @test dL2 ≈ p.dL_dx_peak * μ_ratio
        @test L2 ≈ p.L_base + p.ΔL * μ_ratio

        # Zero current → no saturation even with finite I_sat
        dL3, L3 = PeatSim.saturated_dldx_peak(p2, 0.0)
        @test dL3 ≈ p.dL_dx_peak
        @test L3 ≈ p.L_max
    end

    @testset "stroke_dldx_correction" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)
        τ = (p.L_base + p.L_max) / 2.0 / p.R_coil

        c = PeatSim.stroke_dldx_correction(p, τ)
        @test 0 < c <= 1.0
        @test isfinite(c)

        # For small stroke/δ_L, correction should be close to 1
        @test c > 0.80  # z₀/δ_L = 0.5 → expected around 0.85-0.95

        # For large stroke/δ_L, correction should be significantly < 1
        p_long = PeatSim.init_params(M_total=115.0, f_osc=15.0, δ_L=0.01, stroke=0.2)
        τ_long = (p_long.L_base + p_long.L_max) / 2.0 / p_long.R_coil
        c_long = PeatSim.stroke_dldx_correction(p_long, τ_long)
        @test c_long < 0.55  # z₀=0.1, δ_L=0.01 → ratio=10 → correction ~0.51

        # Verify the function handles N=1 (coarse integration)
        c_coarse = PeatSim.stroke_dldx_correction(p, τ; N=4)
        @test 0 < c_coarse <= 1.0
        @test isfinite(c_coarse)
    end

    @testset "Nonlinear analytical thrust" begin
        p = PeatSim.init_params(M_total=115.0, f_osc=15.0)

        # Backward compatible: no kwargs → same as before
        F_baseline = PeatSim.analytical_thrust(p)
        @test F_baseline > 0

        # With stroke correction (should be ≤ baseline)
        F_corrected = PeatSim.analytical_thrust(p; use_stroke_correction=true)
        @test F_corrected <= F_baseline
        @test F_corrected > 0

        # With saturation: reduced L → smaller τ → faster current rise (more i²)
        # This is the key trade-off: lower dL/dx vs faster L/R response.
        # Which effect dominates depends on θ = t_drive/τ.
        p_sat = PeatSim.init_params(M_total=115.0, f_osc=15.0, I_sat=20.0)
        F_sat = PeatSim.analytical_thrust(p_sat; use_saturation=true)
        F_base_sat = PeatSim.analytical_thrust(p_sat)  # no kwargs
        @test F_sat > 0
        @test isfinite(F_sat)
        # Note: with these params, the faster τ dominates → F_sat > F_base_sat
        # Shorter τ → current rises faster during short pulse → more i² → more force
        @test F_sat != F_base_sat  # physically different model

        # Both corrections combined
        F_both = PeatSim.analytical_thrust(p_sat; use_stroke_correction=true,
                                                   use_saturation=true)
        @test F_both > 0
        @test F_both <= F_sat  # stroke correction always reduces vs saturation alone
        @test F_both > 0
    end

    @testset "Nonlinear check_hover_feasibility" begin
        # Use a lightweight, high-η config that floats analytically
        p = PeatSim.init_params(M_total=1.0, f_osc=15.0, η_repel=0.3)

        # Baseline
        f0 = PeatSim.check_hover_feasibility(p)
        @test f0.feasible
        @test haskey(f0, :c_L)

        # With stroke correction
        f1 = PeatSim.check_hover_feasibility(p; use_stroke_correction=true)
        @test isfinite(f1.F_thrust)
        @test f1.c_L > 0
        @test f1.c_L < 1.0

        # With saturation
        p_sat = PeatSim.init_params(M_total=1.0, f_osc=15.0, η_repel=0.3, I_sat=20.0)
        f2 = PeatSim.check_hover_feasibility(p_sat; use_saturation=true)
        @test isfinite(f2.F_thrust)
        @test haskey(f2, :dL_dx_eff)
        @test f2.dL_dx_eff < p_sat.dL_dx_peak
        @test f2.dL_dx_eff > 0
    end
end

println()
println("All tests passed.")
