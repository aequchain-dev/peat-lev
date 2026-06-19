#!/usr/bin/env python3
"""
PEAT calibration controller — analytical-level PLL, gain scheduling, and
energy-balance regulation for the 2ω₀ parametric pump.

This module intentionally lives at the analytical/model layer rather than the
hardware-control layer. It provides a deterministic reference controller that can
be used by the PEAT analytical sweep, simulation harnesses, and later embedded
control firmware.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional

import numpy as np


def wrap_phase(phase: float) -> float:
    """Wrap phase to [-π, π)."""
    return (phase + np.pi) % (2.0 * np.pi) - np.pi


@dataclass
class PLLState:
    phase: float = 0.0
    frequency: float = 0.0


@dataclass
class ControllerOutput:
    eta_repel: float
    pump_modulation_depth: float
    phase_estimate: float
    frequency_estimate: float
    amplitude_error: float
    phase_error: float
    pump_power_error: float
    load_factor_g: float


class KalmanPLL:
    """
    Two-state Kalman-filtered phase-locked loop.

    State:
      x = [phase_rad, frequency_rad_s]

    Measurement:
      z = measured_phase_rad, optionally measured_frequency_rad_s.

    The PLL is tuned for the parametric pump frequency 2ω₀, where small phase
    errors are wrapped before the Kalman update to avoid 2π discontinuities.
    """

    def __init__(
        self,
        initial_phase: float = 0.0,
        initial_frequency: float = 0.0,
        process_noise: float = 1.0e-4,
        measurement_noise: float = 5.0e-2,
        frequency_measurement_noise: float = 2.0,
        default_dt: float = 1.0e-3,
    ) -> None:
        self.x = np.array([initial_phase, initial_frequency], dtype=float)
        self.P = np.eye(2) * np.array([measurement_noise, frequency_measurement_noise])
        self.Q = np.eye(2) * process_noise
        self.R_phase = measurement_noise
        self.R_frequency = frequency_measurement_noise
        self.default_dt = default_dt
        self.last_t: Optional[float] = None

    def reset(self, initial_phase: float = 0.0, initial_frequency: float = 0.0) -> None:
        self.x = np.array([initial_phase, initial_frequency], dtype=float)
        self.P = np.eye(2) * np.array([self.R_phase, self.R_frequency])
        self.last_t = None

    def update(self, t: float, measured_phase: float, measured_frequency: Optional[float] = None) -> PLLState:
        if self.last_t is None:
            dt = self.default_dt
        else:
            dt = max(t - self.last_t, self.default_dt)
        self.last_t = t

        F = np.array([[1.0, dt], [0.0, 1.0]], dtype=float)
        self.x = F @ self.x
        self.P = F @ self.P @ F.T + self.Q

        # Phase measurement update.
        H_phase = np.array([[1.0, 0.0]])
        innovation_phase = wrap_phase(measured_phase - self.x[0])
        S_phase = float((H_phase @ self.P @ H_phase.T)[0, 0] + self.R_phase)
        K_phase = self.P @ H_phase.T / S_phase
        self.x = self.x + (K_phase[:, 0] * innovation_phase).reshape(2)
        I = np.eye(2)
        self.P = (I - K_phase @ H_phase) @ self.P

        # Optional direct frequency measurement update.
        if measured_frequency is not None:
            H_freq = np.array([[0.0, 1.0]])
            innovation_freq = measured_frequency - self.x[1]
            S_freq = float((H_freq @ self.P @ H_freq.T)[0, 0] + self.R_frequency)
            K_freq = self.P @ H_freq.T / S_freq
            self.x = self.x + (K_freq[:, 0] * innovation_freq).reshape(2)
            self.P = (I - K_freq @ H_freq) @ self.P

        self.x[0] = wrap_phase(self.x[0])
        return PLLState(phase=float(self.x[0]), frequency=float(self.x[1]))


class GainScheduler:
    """
    Load-adaptive η_repel scheduler.

    Lower η_repel increases the asymmetry effectiveness ξ = 1 - η_repel and
    therefore increases available thrust/pump demand. Higher η_repel reduces
    thrust and is used to shed load when amplitude or pump power is excessive.
    """

    def __init__(
        self,
        base_eta: float = 0.20,
        min_eta: float = 0.05,
        max_eta: float = 0.60,
        eta_per_g: float = 0.035,
        eta_per_amp_error: float = 0.8,
        eta_per_pump_error: float = 2.0e-6,
        max_pump_power: float = 10_000.0,
        min_pump_power: float = 1_000.0,
    ) -> None:
        self.base_eta = base_eta
        self.min_eta = min_eta
        self.max_eta = max_eta
        self.eta_per_g = eta_per_g
        self.eta_per_amp_error = eta_per_amp_error
        self.eta_per_pump_error = eta_per_pump_error
        self.max_pump_power = max_pump_power
        self.min_pump_power = min_pump_power

    def schedule(
        self,
        amplitude_error: float,
        load_factor_g: float,
        pump_power: float,
    ) -> float:
        eta = self.base_eta

        # Load compensation: higher g-load needs more thrust margin.
        eta -= self.eta_per_g * max(load_factor_g - 1.0, 0.0)

        # Amplitude regulation: under-amplitude needs more thrust; over-amplitude
        # needs less thrust.
        eta -= self.eta_per_amp_error * amplitude_error

        # Pump-power regulation: if pump power is too high, reduce thrust demand;
        # if it is too low and the oscillator is under-amplitude, allow more thrust.
        pump_error = pump_power - self.max_pump_power
        eta += self.eta_per_pump_error * pump_error

        if pump_power < self.min_pump_power and amplitude_error < 0.0:
            eta -= self.eta_per_pump_error * (self.min_pump_power - pump_power) * 0.25

        return float(np.clip(eta, self.min_eta, self.max_eta))


class EnergyBalanceController:
    """
    Pump-depth regulator for oscillation amplitude vs available pump power.

    The controller increases pump_modulation_depth when amplitude is low and
    decreases it when pump power is above target or amplitude is high.
    """

    def __init__(
        self,
        nominal_depth: float = 0.30,
        min_depth: float = 0.05,
        max_depth: float = 0.60,
        kp_amplitude: float = 0.12,
        kp_power: float = 1.0e-6,
        target_power_margin: float = 0.85,
    ) -> None:
        self.nominal_depth = nominal_depth
        self.min_depth = min_depth
        self.max_depth = max_depth
        self.kp_amplitude = kp_amplitude
        self.kp_power = kp_power
        self.target_power_margin = target_power_margin

    def regulate(
        self,
        amplitude_error: float,
        pump_power: float,
        target_pump_power: float,
    ) -> float:
        depth = self.nominal_depth
        depth -= self.kp_amplitude * amplitude_error
        power_error = pump_power - self.target_power_margin * target_pump_power
        depth -= self.kp_power * power_error
        return float(np.clip(depth, self.min_depth, self.max_depth))


class CalibrationController:
    """Composite analytical calibration controller for PEAT."""

    def __init__(
        self,
        nominal_frequency: float = 15.0,
        base_eta: float = 0.20,
    ) -> None:
        self.nominal_frequency = nominal_frequency
        self.nominal_omega = 2.0 * np.pi * nominal_frequency
        self.nominal_pump_frequency = 2.0 * self.nominal_omega
        self.pll = KalmanPLL(
            initial_phase=0.0,
            initial_frequency=self.nominal_pump_frequency,
        )
        self.gain_scheduler = GainScheduler(base_eta=base_eta)
        self.energy_controller = EnergyBalanceController()
        self.last_output: Optional[ControllerOutput] = None

    def update(
        self,
        t: float,
        measured_phase: float,
        measured_frequency: float,
        measured_amplitude: float,
        target_amplitude: float,
        M_total: float,
        load_factor_g: float = 1.0,
        pump_power: float = 0.0,
    ) -> ControllerOutput:
        pll_state = self.pll.update(t, measured_phase, measured_frequency)
        phase_error = wrap_phase(measured_phase - pll_state.phase)
        amplitude_error = measured_amplitude - target_amplitude
        target_pump_power = max(1_000.0, 0.02 * self.nominal_frequency * M_total)

        eta_repel = self.gain_scheduler.schedule(
            amplitude_error=amplitude_error,
            load_factor_g=load_factor_g,
            pump_power=pump_power,
        )
        pump_modulation_depth = self.energy_controller.regulate(
            amplitude_error=amplitude_error,
            pump_power=pump_power,
            target_pump_power=target_pump_power,
        )

        self.last_output = ControllerOutput(
            eta_repel=eta_repel,
            pump_modulation_depth=pump_modulation_depth,
            phase_estimate=pll_state.phase,
            frequency_estimate=pll_state.frequency,
            amplitude_error=amplitude_error,
            phase_error=phase_error,
            pump_power_error=pump_power - target_pump_power,
            load_factor_g=load_factor_g,
        )
        return self.last_output

    def reset(self) -> None:
        self.pll.reset(initial_phase=0.0, initial_frequency=self.nominal_pump_frequency)
        self.last_output = None


def simulate_disturbance_case(
    duration: float = 1.0,
    dt: float = 0.001,
    frequency_hz: float = 15.0,
    target_amplitude: float = 0.05,
    M_total: float = 115.0,
    phase_noise_std: float = 0.03,
    amplitude_disturbance: float = 0.006,
    load_disturbance_g: float = 0.25,
) -> Dict[str, float]:
    """
    Run a deterministic disturbance simulation for the calibration controller.

    Returns summary statistics for phase error, η_repel range, pump-depth range,
    and amplitude regulation error.
    """
    rng = np.random.default_rng(42)
    controller = CalibrationController(nominal_frequency=frequency_hz)
    omega = 2.0 * np.pi * frequency_hz
    pump_omega = 2.0 * omega

    phase_errors: List[float] = []
    amplitude_errors: List[float] = []
    eta_values: List[float] = []
    depth_values: List[float] = []
    freq_errors: List[float] = []

    for step in range(int(duration / dt)):
        t = step * dt
        load_factor_g = 1.0 + load_disturbance_g * np.sin(2.0 * np.pi * 1.2 * t)
        measured_amplitude = target_amplitude + amplitude_disturbance * np.sin(2.0 * np.pi * 0.7 * t)
        measured_phase = pump_omega * t + 0.05 * np.sin(2.0 * np.pi * 0.4 * t)
        measured_frequency = pump_omega + 1.5 * np.sin(2.0 * np.pi * 0.3 * t)
        measured_phase += rng.normal(0.0, phase_noise_std)

        pump_power = 8_000.0 + 2_500.0 * np.sin(2.0 * np.pi * 0.5 * t)
        out = controller.update(
            t=t,
            measured_phase=measured_phase,
            measured_frequency=measured_frequency,
            measured_amplitude=measured_amplitude,
            target_amplitude=target_amplitude,
            M_total=M_total,
            load_factor_g=load_factor_g,
            pump_power=pump_power,
        )
        phase_errors.append(out.phase_error)
        amplitude_errors.append(out.amplitude_error)
        eta_values.append(out.eta_repel)
        depth_values.append(out.pump_modulation_depth)
        freq_errors.append(out.frequency_estimate - measured_frequency)

    return {
        "rms_phase_error_rad": float(np.sqrt(np.mean(np.square(phase_errors)))),
        "max_abs_phase_error_rad": float(np.max(np.abs(phase_errors))),
        "rms_amplitude_error_m": float(np.sqrt(np.mean(np.square(amplitude_errors)))),
        "eta_min": float(np.min(eta_values)),
        "eta_max": float(np.max(eta_values)),
        "pump_depth_min": float(np.min(depth_values)),
        "pump_depth_max": float(np.max(depth_values)),
        "rms_frequency_error_rad_s": float(np.sqrt(np.mean(np.square(freq_errors)))),
    }


def run_demo() -> Dict[str, Dict[str, float]]:
    """Run representative disturbance cases and return summary statistics."""
    cases = {
        "human_1g": simulate_disturbance_case(),
        "human_load_step": simulate_disturbance_case(load_disturbance_g=0.6, amplitude_disturbance=0.010),
        "hovercar_10hz": simulate_disturbance_case(frequency_hz=10.0, target_amplitude=0.12, M_total=1200.0),
    }
    for name, stats in cases.items():
        print(f"{name}:")
        for key, value in stats.items():
            print(f"  {key}: {value:.6g}")
    return cases


if __name__ == "__main__":
    run_demo()
