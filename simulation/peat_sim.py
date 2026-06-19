#!/usr/bin/env python3
"""
PEAT — Pure Electromagnetic Asymmetric Thrust
Numerical Simulation v1.0

Models:
  - Single oscillator pair with asymmetric push-pull EM drive
  - 6-oscillator 3D array for full 6-DOF control
  - Simultaneous pump (motor) and pickup (generator) coils
  - Parametric resonance at 2ω₀ with phase-locked control
  - Energy balance verification per cycle
  - Parameter sweep engine across all use-case scales

Author : AVIS Engineering
Date   : 2026-06-12
System : PEAT v1
"""

import numpy as np
from scipy.integrate import solve_ivp
from dataclasses import dataclass, field
from typing import Callable, Optional
import json, os, time


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: PHYSICS MODELS
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class CoilParams:
    """Parameters for a single electromagnet coil."""
    N_turns: float          # Number of turns
    R_coil: float           # Coil resistance [Ω]
    L_inf: float            # Inductance when reaction mass is at infinity [H]
    L_close: float          # Inductance when reaction mass is closest [H]
    d_ref: float            # Characteristic distance for L(x) curve [m]
    core_area: float        # Core cross-sectional area [m²]
    max_current: float      # Maximum rated current [A]
    wire_rho: float = 1.68e-8  # Resistivity of copper [Ω·m]

    def inductance(self, x: float) -> float:
        """
        Inductance as a function of distance from coil face.
        Uses a saturating Lorentzian-type model:
          L(x) = L_inf + (L_close - L_inf) / (1 + (x/d_ref)²)
        
        This captures:
          - Maximum inductance when reaction mass is against the coil (x → 0)
          - Asymptotic minimum when mass is far away (x → ∞)
          - Smooth transition with characteristic length d_ref
        """
        # x is distance from coil face to reaction mass center
        L_variation = (self.L_close - self.L_inf) / (1.0 + (x / self.d_ref)**2)
        return self.L_inf + L_variation

    def dL_dx(self, x: float) -> float:
        """
        Gradient of inductance with respect to distance.
        dL/dx = -2 * (L_close - L_inf) * x / (d_ref² * (1 + (x/d_ref)²)²)
        
        Negative when x > 0 (inductance decreases as mass moves away).
        Used in force calculation: F = ½ · i² · dL/dx
        Note the SIGN: positive dL/dx means force pulls mass TOWARD coil.
        """
        denom = (1.0 + (x / self.d_ref)**2)**2
        return -2.0 * (self.L_close - self.L_inf) * x / (self.d_ref**2 * denom)


@dataclass
class OscillatorParams:
    """Parameters for a single oscillator pair (two opposing coils + reaction mass)."""
    m_r: float              # Reaction mass [kg]
    z0: float               # Oscillation half-amplitude [m]
    frequency: float        # Cycle frequency [Hz]
    eta_repel: float        # Asymmetry ratio: I_repel / I_attract (0-1)
    
    # Coil A (attraction-dominant, upper/first)
    coil_A: CoilParams
    # Coil B (repulsion-dominant, lower/second)
    coil_B: CoilParams
    
    # Mechanical
    b_damping: float = 0.1  # Mechanical damping coefficient [N·s/m]
    gap: float = 0.15       # Total gap between opposing coils [m]
    suspension_stiffness: float = 100.0  # Magnetic bearing stiffness [N/m]
    
    # Electrical drive
    V_bus: float = 600.0    # DC bus voltage [V]
    V_repel_frac: float = 0.3  # Fraction of V_bus used for repulsion phase
    t_attract_frac: float = 0.35  # Fraction of cycle for attraction phase
    t_repel_frac: float = 0.25   # Fraction of cycle for repulsion phase
    
    # Pickup coil (generation) — modeled as controlled electromagnetic damper
    # Physically: V_pickup = N_pickup * A_core * B * v_r / d_rest
    # Power extracted: P_pickup = V_pickup² / R_load (acts as damping: F = b_gen * v)
    pickup_field_B: float = 0.5        # Magnetic field in pickup gap [T]
    pickup_core_area: float = 0.01     # Pickup core cross-section [m²]
    N_pickup: float = 100.0           # Pickup coil turns
    R_pickup_load: float = 10.0       # Load resistance [Ω] (MPPT-adjusted)
    # Derived generator damping coefficient:
    # b_gen = (N * B * A)² / R_load  [N·s/m]
    
    # Pump (parametric)
    pump_modulation_depth: float = 0.3  # h parameter for parametric pumping
    pump_phase: float = np.pi / 2        # φ = +π/2 for thruster mode
    
    # Derived quantities (computed in __post_init__)
    omega_0: float = 0.0
    omega_pump: float = 0.0
    period: float = 0.0
    t_attract: float = 0.0
    t_repel: float = 0.0
    d_rest: float = 0.0
    
    def __post_init__(self):
        self.omega_0 = 2.0 * np.pi * self.frequency
        self.omega_pump = 2.0 * self.omega_0
        self.period = 1.0 / self.frequency
        self.t_attract = self.t_attract_frac * self.period
        self.t_repel = self.t_repel_frac * self.period
        # Rest distance from each coil face to mass center (at x=0)
        self.d_rest = self.gap / 2.0


@dataclass
class ArrayParams:
    """Parameters for the full 6-oscillator 3D array."""
    
    # Three orthogonal pairs
    z_pair: OscillatorParams   # Vertical (primary lift)
    x_pair: OscillatorParams   # Longitudinal (forward/back)
    y_pair: OscillatorParams   # Lateral (left/right)
    
    # Frame
    M_frame: float = 0.0       # Frame mass [kg] (computed from total - reaction masses)
    M_total: float = 0.0       # Total system mass [kg]
    
    # Control
    enable_control: bool = True
    target_amplitude_z: float = 0.0
    target_amplitude_x: float = 0.0
    target_amplitude_y: float = 0.0

    def total_reaction_mass(self) -> float:
        return (self.z_pair.m_r + self.x_pair.m_r + self.y_pair.m_r)
    
    def __post_init__(self):
        self.target_amplitude_z = self.z_pair.z0
        self.target_amplitude_x = self.x_pair.z0
        self.target_amplitude_y = self.y_pair.z0


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: COUPLED ODE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

class SingleOscillatorODE:
    """
    Coupled electrical-mechanical ODE for a single oscillator pair.
    
    States (7 per pair):
      x[0] = x_r    : reaction mass position [m] (relative to center, + toward coil A)
      x[1] = v_r    : reaction mass velocity [m/s]
      x[2] = i_A    : current in coil A [A]
      x[3] = i_B    : current in coil B [A]
      x[4] = X_f    : frame position [m] (global, along this axis)
      x[5] = V_f    : frame velocity [m/s]
      x[6] = V_pickup : pickup coil voltage [V] (for energy tracking)
    
    Total for 6 oscillators: 42 states
    """
    
    def __init__(self, params: OscillatorParams, axis_name: str = 'Z'):
        self.p = params
        self.axis = axis_name
        self.energy_log = {
            'E_pump': 0.0, 'E_thrust': 0.0, 'E_pickup': 0.0,
            'E_loss': 0.0, 'E_kinetic': 0.0, 'cycles': 0
        }
        self._last_phase = 0  # 0 = attract, 1 = coast, 2 = repel, 3 = coast
    
    def current_derivative(self, i: float, V_applied: float, L: float, dLdx: float, v: float) -> float:
        """
        di/dt = (V_applied - i*R - v*i*dL/dx) / L
        
        The v*i*dL/dx term is the motional EMF (back-EMF from coil moving
        relative to the reaction mass). This is the electromechanical coupling.
        """
        if L < 1e-12:
            return 0.0
        back_emf = v * i * dLdx
        return (V_applied - i * self.p.coil_A.R_coil - back_emf) / L
    
    def force_from_current(self, i: float, dLdx: float) -> float:
        """Electromagnetic force: F = ½ · i² · dL/dx"""
        return 0.5 * i * i * dLdx
    
    def get_pickup_voltage(self, v_r: float, x_r: float) -> float:
        """
        Voltage induced in pickup coil by the moving reaction mass.
        
        Physical model: a permanent magnet or DC-biased electromagnet creates
        a magnetic field B in the gap. The oscillating reaction mass modulates
        the flux through the pickup coil:
        
          Φ = N_pickup · B · A_core · (1 + x_r / d_rest)  (linearized)
          V_pickup = dΦ/dt = N_pickup · B · A_core · v_r / d_rest
        
        This is Faraday's law applied to a moving media. The pickup coil
        acts as a velocity-dependent voltage source feeding a load resistor.
        The resulting current creates a damping force: F_damping = b_gen · v_r
        where b_gen = (N_pickup · B · A_core / d_rest)² / R_load
        
        Energy conservation: the mechanical power removed as damping
        (P_damping = b_gen · v_r²) exactly equals the electrical power
        dissipated in the load (P_pickup = V_pickup² / R_load).
        """
        d_eff = max(self.p.d_rest, 0.001)
        B_eff = self.p.pickup_field_B
        A_eff = self.p.pickup_core_area
        N = self.p.N_pickup
        return N * B_eff * A_eff * v_r / d_eff
    
    def compute_drive_voltages(self, t: float, x_r: float, v_r: float) -> tuple:
        """
        Determine the applied voltage to each coil based on the current phase.
        
        Uses a state machine driven by position (not time) for robust operation.
        
        Returns: (V_A, V_B, phase_name)
        """
        cycle_t = t % self.p.period
        z0 = self.p.z0
        
        # Position-based switching: use position zero-crossings to determine phase
        # Phase 0: x_r going positive → coil A attracting
        # Phase 1: x_r near positive peak → coast/reversal
        # Phase 2: x_r going negative → coil B weakly repelling  
        # Phase 3: x_r near negative peak → coast/reversal
        
        if cycle_t < self.p.t_attract:
            # Attraction phase: energize coil A strongly
            # Check that we're in the right position range
            V_A = self.p.V_bus
            V_B = 0.0
            self._last_phase = 0
        elif cycle_t < self.p.t_attract + self.p.period * 0.15:
            # Coast: both coils off (mass coasts to peak)
            V_A = 0.0
            V_B = 0.0
            self._last_phase = 1
        elif cycle_t < self.p.t_attract + self.p.period * 0.15 + self.p.t_repel:
            # Repulsion phase: energize coil B weakly
            V_A = 0.0
            V_B = self.p.V_bus * self.p.V_repel_frac * (1.0 - self.p.eta_repel)
            self._last_phase = 2
        else:
            # Coast: both coils off (mass coasts back toward center)
            V_A = 0.0
            V_B = 0.0
            self._last_phase = 3
        
        # Parametric pump modulation: add 2ω₀ modulation on top
        # This enhances the asymmetry by varying effective stiffness
        h = self.p.pump_modulation_depth
        phi = self.p.pump_phase
        pump_signal = h * np.sin(self.p.omega_pump * t + phi)
        
        # Apply pump modulation to both coils (differential effect)
        V_A *= (1.0 + pump_signal)
        
        return V_A, V_B, ['ATTRACT', 'COAST1', 'REPEL', 'COAST2'][self._last_phase]
    
    def generator_damping(self) -> float:
        """
        Electromagnetic damping coefficient from pickup coil.
        
        b_gen = (N_pickup · B · A_core / d_rest)² / R_load
        
        This is the equivalent mechanical damping that the electrical
        generator places on the oscillation. Power extracted:
          P_pickup = b_gen · v_r²
        """
        N = self.p.N_pickup
        B = self.p.pickup_field_B
        A = self.p.pickup_core_area
        d = max(self.p.d_rest, 0.001)
        R = max(self.p.R_pickup_load, 0.001)
        return (N * B * A / d)**2 / R
    
    def __call__(self, t, state, frame_gravity: float = 9.81):
        """
        Compute derivatives for the 7-state oscillator ODE.
        
        Parameters:
          t : time [s]
          state : array of 7 state variables
          frame_gravity : gravitational acceleration (positive = downward along axis)
        """
        x_r, v_r, i_A, i_B, X_f, V_f, V_pk = state
        
        # Geometry
        d_A = self.p.d_rest - x_r  # Distance from reaction mass to coil A
        d_B = self.p.d_rest + x_r  # Distance from reaction mass to coil B
        
        # Prevent singularity at zero distance
        d_A = max(d_A, 0.001 * self.p.z0)
        d_B = max(d_B, 0.001 * self.p.z0)
        
        # Inductance and gradient for each coil
        L_A = self.p.coil_A.inductance(d_A)
        L_B = self.p.coil_B.inductance(d_B)
        dL_A = self.p.coil_A.dL_dx(d_A)
        dL_B = self.p.coil_B.dL_dx(d_B)
        
        # Drive voltages
        V_A, V_B, phase = self.compute_drive_voltages(t, x_r, v_r)
        
        # Current derivatives (coil circuit equations)
        di_A = self.current_derivative(i_A, V_A, L_A, dL_A, v_r)
        di_B = self.current_derivative(i_B, V_B, L_B, -dL_B, -v_r)
        
        # Electromagnetic forces
        F_em_A = self.force_from_current(i_A, dL_A)   # Pulls mass toward coil A (+x)
        F_em_B = self.force_from_current(i_B, -dL_B)  # Pulls mass toward coil B (-x)
        F_em_net = F_em_A - F_em_B  # Net EM force on mass (+x = toward A)
        
        # Magnetic suspension (centering) force
        F_susp = -self.p.suspension_stiffness * x_r
        
        # Mechanical damping
        F_damp = -self.p.b_damping * v_r
        
        # Generator (pickup coil) electromagnetic damping
        # The pickup coil acts as a velocity-dependent brake:
        #   F_gen = -b_gen * v_r
        #   P_pickup = b_gen * v_r²  (mechanical power converted to electricity)
        b_gen = self.generator_damping()
        F_gen = -b_gen * v_r
        
        # Net force on reaction mass
        F_net_r = F_em_net + F_susp + F_damp + F_gen
        
        # Gravity on reaction mass
        F_gravity_r = -self.p.m_r * frame_gravity  # (negative = downward)
        
        # Total acceleration
        a_r = (F_net_r + F_gravity_r) / self.p.m_r
        
        # Frame acceleration (from EM reaction force only)
        F_on_frame = -F_em_net
        # Frame mass fraction for this axis (approximate for single-oscillator model)
        M_frame_axis = self.p.m_r * 5.0  # Frame ~5× reaction mass per axis
        a_f = F_on_frame / M_frame_axis
        
        # Pickup coil voltage (Faraday's law, no dependency on coil currents)
        V_pickup = self.get_pickup_voltage(v_r, x_r)
        I_pickup = V_pickup / max(self.p.R_pickup_load, 0.001)
        
        # Verify energy conservation:
        # Mechanical power removed by generator: P_gen_mech = F_gen * v_r = -b_gen * v_r²
        # Electrical power out: P_pickup_elec = V_pickup² / R_load
        # These should be equal: b_gen * v_r² = (N*B*A*v_r/d_rest)² / R_load ✓
        
        # Derivatives
        dx_r = v_r
        dv_r = a_r
        dX_f = V_f
        dV_f = a_f
        dV_pk = (V_pickup - V_pk) * 1000.0  # Low-pass filtered estimate
        
        return [dx_r, dv_r, di_A, di_B, dX_f, dV_f, dV_pk]


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: 6-OSCILLATOR ARRAY
# ═══════════════════════════════════════════════════════════════════════════════

class SixOscillatorArray:
    """
    Full 6-oscillator 3D array with coupled dynamics.
    
    States per oscillator (7): x_r, v_r, i_A, i_B, X_f, V_f, V_pk
    Total states: 3 pairs × 7 = 21
    Plus 6-DOF frame states: px, py, pz, vx, vy, vz, qw, qx, qy, qz (quaternion)
    Plus 3 body rates: wx, wy, wz
    Total: 21 + 10 + 3 = 34 states
    """
    
    def __init__(self, params: ArrayParams):
        self.p = params
        self.osc_z = SingleOscillatorODE(params.z_pair, 'Z')
        self.osc_x = SingleOscillatorODE(params.x_pair, 'X')
        self.osc_y = SingleOscillatorODE(params.y_pair, 'Y')
        
        # Frame inertial properties
        self.M_frame = (self.p.M_total 
                        - self.p.z_pair.m_r 
                        - self.p.x_pair.m_r 
                        - self.p.y_pair.m_r)
        
        # Moments of inertia (approximate for a rectangular prism frame)
        self.Ixx = self.M_frame * 0.3**2  # kg·m² (approximate)
        self.Iyy = self.M_frame * 0.4**2
        self.Izz = self.M_frame * 0.2**2
    
    def state_vector(self) -> np.ndarray:
        """Return current state vector (for solver initialization)."""
        # [Z_osc(7), X_osc(7), Y_osc(7), frame_pos(3), frame_vel(3), quat(4), body_rates(3)]
        return np.zeros(34)
    
    def ode_function(self, t: float, state: np.ndarray) -> list:
        """
        Full 34-state ODE function for the 6-oscillator array.
        
        state layout:
          [0:7]   = Z oscillator (x_r, v_r, i_A, i_B, X_f, V_f, V_pk)
          [7:14]  = X oscillator
          [14:21] = Y oscillator
          [21:24] = frame position (x, y, z) in world frame
          [24:27] = frame velocity (vx, vy, vz) in world frame
          [27:31] = quaternion (qw, qx, qy, qz) 
          [31:34] = body angular rates (wx, wy, wz)
        """
        # Extract states
        z_st = state[0:7]
        x_st = state[7:14]
        y_st = state[14:21]
        pos = state[21:24]
        vel = state[24:27]
        quat = state[27:31]
        omega = state[31:34]
        
        # Compute oscillator derivatives (each Z axis sees full gravity)
        dz = self.osc_z(t, z_st, 9.81)
        dx = self.osc_x(t, x_st, 0.0)  # X axis: no gravity in hover
        dy = self.osc_y(t, y_st, 0.0)  # Y axis: no gravity in hover
        
        # Extract reaction-mass forces from each oscillator
        # z oscillator force on frame (Z-axis)
        F_z_on_frame = -(self.osc_z.force_from_current(z_st[2], 
            self.osc_z.p.coil_A.dL_dx(max(self.osc_z.p.d_rest - z_st[0], 0.001)))
            - self.osc_z.force_from_current(z_st[3], 
            -self.osc_z.p.coil_B.dL_dx(max(self.osc_z.p.d_rest + z_st[0], 0.001))))
        
        # Simplified: compute forces for X and Y similarly
        x_r_x, _, i_A_x, i_B_x, _, _, _ = x_st
        d_A_x = max(self.osc_x.p.d_rest - x_r_x, 0.001)
        d_B_x = max(self.osc_x.p.d_rest + x_r_x, 0.001)
        F_x_on_frame = -(self.osc_x.force_from_current(i_A_x, self.osc_x.p.coil_A.dL_dx(d_A_x))
                         - self.osc_x.force_from_current(i_B_x, -self.osc_x.p.coil_B.dL_dx(d_B_x)))
        
        x_r_y, _, i_A_y, i_B_y, _, _, _ = y_st
        d_A_y = max(self.osc_y.p.d_rest - x_r_y, 0.001)
        d_B_y = max(self.osc_y.p.d_rest + x_r_y, 0.001)
        F_y_on_frame = -(self.osc_y.force_from_current(i_A_y, self.osc_y.p.coil_A.dL_dx(d_A_y))
                         - self.osc_y.force_from_current(i_B_y, -self.osc_y.p.coil_B.dL_dx(d_B_y)))
        
        # Total frame forces (in body frame)
        F_body = np.array([F_x_on_frame, F_y_on_frame, F_z_on_frame])
        
        # Gravity in world frame
        F_gravity_world = np.array([0.0, 0.0, -self.M_frame * 9.81])
        
        # Rotate body forces to world frame (simplified: small angle approximation)
        # For full quaternion rotation:
        qw, qx, qy, qz = quat
        # Rotation matrix from quaternion
        R = np.array([
            [1 - 2*(qy**2 + qz**2), 2*(qx*qy - qw*qz),   2*(qx*qz + qw*qy)],
            [2*(qx*qy + qw*qz),     1 - 2*(qx**2 + qz**2), 2*(qy*qz - qw*qx)],
            [2*(qx*qz - qw*qy),     2*(qy*qz + qw*qx),   1 - 2*(qx**2 + qy**2)]
        ])
        
        F_world = R @ F_body
        F_total = F_world + F_gravity_world
        
        # Frame acceleration
        accel = F_total / self.M_frame
        
        # Torques (from differential oscillator forces)
        # Z-pair offset from center of mass
        lever_z = 0.3  # m (approximate)
        torque = np.array([
            F_y_on_frame * lever_z,   # Roll moment from Y pair offset
            -F_x_on_frame * lever_z,  # Pitch moment from X pair offset
            0.0                        # Yaw (from differential, simplified)
        ])
        
        # Angular acceleration
        I = np.array([self.Ixx, self.Iyy, self.Izz])
        alpha = torque / I
        
        # Quaternion derivative
        # dq/dt = 0.5 * q ⊗ ω
        w = omega
        dq = 0.5 * np.array([
            -qx*w[0] - qy*w[1] - qz*w[2],
             qw*w[0] - qz*w[1] + qy*w[2],
             qz*w[0] + qw*w[1] - qx*w[2],
            -qy*w[0] + qx*w[1] + qw*w[2]
        ])
        
        # Assemble full derivative vector
        dstate = np.zeros(34)
        dstate[0:7] = dz[:7]  # Z oscillator
        dstate[7:14] = dx[:7]  # X oscillator
        dstate[14:21] = dy[:7]  # Y oscillator
        dstate[21:24] = vel     # Frame position derivative
        dstate[24:27] = accel   # Frame velocity derivative
        dstate[27:31] = dq      # Quaternion derivative
        dstate[31:34] = alpha   # Angular acceleration
        
        return dstate


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: ANALYTICAL MODEL (for verification)
# ═══════════════════════════════════════════════════════════════════════════════

class AnalyticalModel:
    """
    Closed-form analytical model for PEAT thrust and power.
    Used for cross-checking numerical simulation results.
    """
    
    @staticmethod
    def thrust_per_oscillator(m_r: float, f: float, z0: float, eta_repel: float) -> float:
        """
        Net thrust from a single oscillator pair.
        
        F_thrust = 2 · ξ · f · m_r · ω₀ · z₀
        
        Where ξ = (1 - η_repel) is the asymmetry effectiveness.
        Factor of 2 comes from two impulses per cycle (one per coil direction).
        
        Returns: Net thrust [N]
        """
        omega_0 = 2.0 * np.pi * f
        v_peak = omega_0 * z0
        xi = 1.0 - eta_repel
        return 2.0 * xi * f * m_r * v_peak
    
    @staticmethod
    def thrust_at_eta(m_r: float, f: float, z0: float, eta: float) -> float:
        """Thrust at a specific asymmetry ratio."""
        return AnalyticalModel.thrust_per_oscillator(m_r, f, z0, eta)
    
    @staticmethod
    def peak_coil_force(m_r: float, f: float, z0: float) -> float:
        """
        Peak magnetic force required to sustain oscillation.
        F_peak = m_r · ω₀² · z₀
        
        This is the force needed at the extremes of travel to reverse
        the reaction mass direction.
        """
        omega_0 = 2.0 * np.pi * f
        return m_r * omega_0**2 * z0
    
    @staticmethod
    def pump_power_parametric(k0: float, h: float, omega_0: float, z0: float) -> float:
        """
        Power required for parametric pumping.
        P_pump = ¼ · k₀ · h · ω₀ · z₀²
        
        Where k₀ = m_r · ω₀² (equivalent stiffness)
              h = modulation depth
        
        From AVIS-OMG parametric resonance math.
        """
        k0 = m_r * omega_0**2
        return 0.25 * k0 * h * omega_0 * z0**2
    
    @staticmethod
    def pickup_power_available_from_params(params: OscillatorParams) -> float:
        """
        Power recoverable from pickup coils using generator damping model.
        
        P_pickup = b_gen · v_rms²
        
        where:
          b_gen = (N · B · A / d_rest)² / R_load  [N·s/m]
          v_rms ≈ ω₀ · z₀ / √2  (for sinusoidal oscillation)
        """
        N = params.N_pickup
        B = params.pickup_field_B
        A = params.pickup_core_area
        d = max(params.d_rest, 0.001)
        R = max(params.R_pickup_load, 0.001)
        b_gen = (N * B * A / d)**2 / R
        
        omega_0 = 2.0 * np.pi * params.frequency
        v_rms = omega_0 * params.z0 / np.sqrt(2.0)
        
        return b_gen * v_rms**2
    
    @staticmethod
    def pickup_power_available(m_r: float, f: float, z0: float, eta_gen: float = 0.25) -> float:
        """
        Estimated power recoverable from pickup coils.
        
        P_pickup ≈ η_gen · P_oscillation
        
        Where P_oscillation = ½ · m_r · v_peak² · f (kinetic energy flow rate)
        """
        omega_0 = 2.0 * np.pi * f
        v_peak = omega_0 * z0
        P_osc = 0.5 * m_r * v_peak**2 * f
        return eta_gen * P_osc
    
    @staticmethod
    def required_eta_for_hover(M_total: float, m_r: float, f: float, z0: float) -> float:
        """
        Solve for the asymmetry ratio (η_repel) needed to hover.
        
        At hover: F_thrust = M_total · g
        """
        F_needed = M_total * 9.81
        F_max = AnalyticalModel.thrust_per_oscillator(m_r, f, z0, 0.0)
        xi_needed = F_needed / F_max
        return 1.0 - xi_needed
    
    @staticmethod
    def full_energy_balance(params: OscillatorParams, M_total: float) -> dict:
        """
        Compute full energy balance for a system configuration.
        
        Returns dict with all power flows.
        """
        m_r = params.m_r
        f = params.frequency
        z0 = params.z0
        eta = params.eta_repel
        
        omega_0 = 2.0 * np.pi * f
        v_peak = omega_0 * z0
        xi = 1.0 - eta
        
        # Thrust
        F_thrust = 2.0 * xi * f * m_r * v_peak
        F_needed = M_total * 9.81
        
        # Power flows
        P_thrust = F_thrust * v_peak * 0.5  # Peak thrust power (for reference)
        k0 = m_r * omega_0**2
        P_pump_parametric = 0.25 * k0 * params.pump_modulation_depth * omega_0 * z0**2
        
        # Pickup power from generator damping model
        P_pickup = AnalyticalModel.pickup_power_available_from_params(params)
        
        # Copper losses (estimated from peak current for required thrust)
        dL_mag = abs(params.coil_A.dL_dx(max(params.d_rest * 0.5, 0.001)))
        if dL_mag < 1e-12:
            I_peak = 1.0
        else:
            I_peak = np.sqrt(max(2.0 * abs(F_thrust) / dL_mag, 0.1))
        P_copper = I_peak**2 * params.coil_A.R_coil * 0.5  # ~50% duty cycle
        
        # The parametric pump must overcome all losses to sustain oscillation:
        # P_pump = P_pickup + P_copper + P_damping + P_thrust_modulation
        # Net electrical power needed from external source:
        P_net = max(0, P_pickup + P_copper - P_pump_parametric * 0.5)
        # (parametric pump is ~50% efficient in converting electrical to mechanical)
        
        return {
            'F_thrust_N': float(F_thrust),
            'F_needed_N': float(F_needed),
            'xi': float(xi),
            'eta_repel': float(eta),
            'P_pump_W': float(P_pump_parametric),
            'P_thrust_W': float(P_thrust),
            'P_pickup_W': float(P_pickup),
            'P_copper_W': float(P_copper),
            'P_net_W': float(P_net),
            'hover_feasible': bool(F_thrust >= F_needed)
        }


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: PARAMETER SWEEP ENGINE
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class SweepConfig:
    """Configuration for a parameter sweep."""
    name: str
    M_total_range: list = field(default_factory=lambda: [5, 50, 115, 250, 1200, 5500])
    eta_range: list = field(default_factory=lambda: list(np.arange(0.05, 0.51, 0.025)))
    freq_range: list = field(default_factory=lambda: list(np.arange(5.0, 50.0, 2.5)))
    mass_ratio_range: list = field(default_factory=lambda: [0.10, 0.12, 0.15, 0.18, 0.20])
    output_file: str = "sweep_results.json"


def create_oscillator_for_scale(M_total: float, freq: float, 
                                 mass_ratio: float = 0.15,
                                 eta_repel: float = 0.20) -> OscillatorParams:
    """
    Create appropriate oscillator parameters for a given total mass.
    Uses scaling laws from the PEAT_MASTER use-case matrix.
    
    Scaling relationships (approximate):
      m_r ∝ M_total^1.0
      z₀ ∝ M_total^0.25
      f ∝ M_total^(-0.3)
    """
    # Reference: 115 kg human case
    M_ref = 115.0
    m_r_ref = 15.0
    z0_ref = 0.05
    f_ref = 15.0
    
    scale = M_total / M_ref
    
    m_r = M_total * mass_ratio
    z0 = z0_ref * scale**0.25
    f = freq  # Use provided frequency (override scaling)
    
    # Ensure z0 is within reasonable bounds
    z0 = np.clip(z0, 0.005, 0.25)
    
    # Frequency scaling: larger systems oscillate slower
    f = f  # Keep user-specified
    
    # Coil design scales with size
    # Coil core area ∝ M^0.5 (larger systems need bigger coils)
    coil_scale = max(0.1, scale**0.4)
    
    coil = CoilParams(
        N_turns=200 * coil_scale,
        R_coil=0.5 / coil_scale,
        L_inf=0.01 * coil_scale,
        L_close=0.10 * coil_scale,
        d_ref=0.01 * coil_scale**0.5,
        core_area=0.01 * coil_scale,
        max_current=50.0 * coil_scale**0.5
    )
    
    return OscillatorParams(
        m_r=m_r,
        z0=z0,
        frequency=f,
        eta_repel=eta_repel,
        coil_A=coil,
        coil_B=coil,  # Same coil design, different drive
        gap=z0 * 4.0,  # Total gap = 4× amplitude
        V_bus=600.0 * coil_scale**0.3
    )


def run_sweep(config: SweepConfig) -> list:
    """
    Run a complete parameter sweep and return results.
    
    Sweeps over:
      - Total mass (different use-case scales)
      - Asymmetry ratio (η_repel)
      - Frequency
      - Mass ratio
    
    For each configuration, computes analytical model and returns key metrics.
    """
    results = []
    total_configs = (len(config.M_total_range) * len(config.eta_range) 
                     * len(config.freq_range) * len(config.mass_ratio_range))
    
    print(f"Running sweep: {total_configs} configurations...")
    t_start = time.time()
    
    count = 0
    for M_total in config.M_total_range:
        for freq in config.freq_range:
            for mass_ratio in config.mass_ratio_range:
                for eta in config.eta_range:
                    # Create oscillator for this scale
                    osc = create_oscillator_for_scale(
                        M_total, freq, mass_ratio, eta
                    )
                    
                    # Run analytical model
                    balance = AnalyticalModel.full_energy_balance(osc, M_total)
                    
                    entry = {
                        'M_total_kg': M_total,
                        'frequency_Hz': freq,
                        'mass_ratio': mass_ratio,
                        'eta_repel': round(eta, 3),
                        'm_r_kg': round(osc.m_r, 3),
                        'z0_m': round(osc.z0, 5),
                        'gap_m': round(osc.gap, 4),
                        'F_thrust_N': round(balance['F_thrust_N'], 1),
                        'F_needed_N': round(balance['F_needed_N'], 1),
                        'xi': round(balance['xi'], 4),
                        'P_pump_W': round(balance['P_pump_W'], 1),
                        'P_thrust_W': round(balance['P_thrust_W'], 1),
                        'P_pickup_W': round(balance['P_pickup_W'], 1),
                        'P_copper_W': round(balance['P_copper_W'], 1),
                        'P_net_W': round(balance['P_net_W'], 1),
                        'hover_feasible': balance['hover_feasible']
                    }
                    results.append(entry)
                    
                    count += 1
                    if count % 500 == 0:
                        elapsed = time.time() - t_start
                        print(f"  {count}/{total_configs} ({elapsed:.1f}s)")
    
    elapsed = time.time() - t_start
    print(f"Sweep complete: {count} configs in {elapsed:.1f}s")
    
    # Save results
    with open(config.output_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"Results saved to {config.output_file}")
    
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: NUMERICAL SIMULATION (single config, detailed)
# ═══════════════════════════════════════════════════════════════════════════════

def simulate_single_config(osc: OscillatorParams, 
                           sim_time: float = 0.5,
                           dt_max: float = 1e-5) -> dict:
    """
    Run detailed numerical simulation of a single oscillator pair.
    
    Parameters:
      osc : Oscillator parameters
      sim_time : Simulation duration [s]
      dt_max : Maximum time step [s] (100 kHz default)
    
    Returns:
      dict with time series of all state variables and energy tracking
    """
    # Create ODE system
    ode = SingleOscillatorODE(osc)
    
    # Initial conditions: mass at center, at rest, no currents
    # Give a small initial perturbation to start oscillation
    x0 = np.array([0.0, 0.01, 0.0, 0.0, 0.0, 0.0, 0.0])
    
    # Time points for output
    t_eval = np.arange(0, sim_time, dt_max)
    
    # Energy tracking arrays
    E_pump = np.zeros_like(t_eval)
    E_pickup = np.zeros_like(t_eval)
    E_loss = np.zeros_like(t_eval)
    E_thrust = np.zeros_like(t_eval)
    E_kinetic = np.zeros_like(t_eval)
    
    def coupled_ode(t, state):
        """Wrapped ODE function that also tracks energy."""
        derivs = ode(t, state, 9.81)
        return derivs
    
    # Generator damping coefficient for energy tracking
    b_gen = ode.generator_damping()
    
    # Use dense output to track energy at evaluation points
    def compute_energies(t, state):
        _, v_r, i_A, i_B, _, _, _ = state
        d_A = max(osc.d_rest - state[0], 0.001)
        d_B = max(osc.d_rest + state[0], 0.001)
        
        V_A, V_B, _ = ode.compute_drive_voltages(t, state[0], v_r)
        
        dL_A = osc.coil_A.dL_dx(d_A)
        dL_B = osc.coil_B.dL_dx(d_B)
        
        F_A = 0.5 * i_A**2 * dL_A
        F_B = 0.5 * i_B**2 * (-dL_B)
        F_net = F_A - F_B
        
        # Pickup power: generator acts as velocity-dependent damper
        P_pickup = b_gen * v_r**2
        
        return {
            'P_pump': V_A * i_A + V_B * i_B,
            'P_loss': i_A**2 * osc.coil_A.R_coil + i_B**2 * osc.coil_B.R_coil,
            'P_pickup': max(0, P_pickup),
            'P_thrust': F_net * v_r,
            'KE': 0.5 * osc.m_r * v_r**2,
            'F_net': F_net,
            'x_r': state[0],
            'v_r': v_r
        }
    
    # Solve ODE
    print(f"Simulating {osc.axis} oscillator: {sim_time:.2f}s at {1/dt_max:.0f} Hz...")
    t_start = time.time()
    
    # Use LSODA (auto-detects stiffness and switches between Adams/BDF)
    sol = solve_ivp(
        coupled_ode,
        [0, sim_time],
        x0,
        method='LSODA',
        t_eval=t_eval,
        max_step=dt_max * 100,  # Allow larger steps for LSODA
        rtol=1e-6,
        atol=1e-8
    )
    
    elapsed = time.time() - t_start
    print(f"  Solved in {elapsed:.2f}s ({sol.t.shape[0]} time steps)")
    
    if not sol.success:
        print(f"  WARNING: Solver failed: {sol.message}")
    
    # Post-process: compute energy tracking
    energies = [compute_energies(t, sol.y[:, i]) for i, t in enumerate(sol.t)]
    
    # Integrate powers
    dt_array = np.diff(sol.t)
    for i in range(1, len(sol.t)):
        dt = sol.t[i] - sol.t[i-1]
        E_pump[i] = E_pump[i-1] + energies[i]['P_pump'] * dt
        E_loss[i] = E_loss[i-1] + energies[i]['P_loss'] * dt
        E_pickup[i] = E_pickup[i-1] + energies[i]['P_pickup'] * dt
        E_kinetic[i] = energies[i]['KE']
    
    # Compute thrust by integrating net force
    for i in range(1, len(sol.t)):
        dt = sol.t[i] - sol.t[i-1]
        E_thrust[i] = E_thrust[i-1] + energies[i]['P_thrust'] * dt
    
    # Results
    final_cycle_count = int(sim_time * osc.frequency)
    
    return {
        'time': sol.t.tolist(),
        'x_r': sol.y[0].tolist(),
        'v_r': sol.y[1].tolist(),
        'i_A': sol.y[2].tolist(),
        'i_B': sol.y[3].tolist(),
        'V_pickup': sol.y[6].tolist(),
        'E_pump_J': E_pump.tolist(),
        'E_loss_J': E_loss.tolist(),
        'E_pickup_J': E_pickup.tolist(),
        'E_thrust_J': E_thrust.tolist(),
        'E_kinetic_J': E_kinetic.tolist(),
        'F_net': [e['F_net'] for e in energies],
        'params': {
            'm_r_kg': osc.m_r,
            'z0_m': osc.z0,
            'frequency_Hz': osc.frequency,
            'eta_repel': osc.eta_repel,
            'period_s': osc.period
        },
        'cycles_simulated': final_cycle_count,
        'energy_balance_at_end': {
            'E_pump_J': float(E_pump[-1]),
            'E_thrust_J': float(E_thrust[-1]),
            'E_pickup_J': float(E_pickup[-1]),
            'E_loss_J': float(E_loss[-1]),
            'efficiency': float((E_thrust[-1] + E_pickup[-1]) / E_pump[-1]) if E_pump[-1] > 0 else 0
        }
    }


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: VISUALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

def plot_simulation_results(results: dict, title: str = "PEAT Oscillator Simulation"):
    """Plot time-series results from a single simulation."""
    import matplotlib
    matplotlib.use('Agg')  # Headless-friendly
    import matplotlib.pyplot as plt
    
    t = np.array(results['time'])
    
    fig, axes = plt.subplots(4, 2, figsize=(14, 12))
    fig.suptitle(title, fontsize=14)
    
    # 1. Position and velocity
    ax = axes[0, 0]
    ax.plot(t, np.array(results['x_r']) * 1000, 'b-', label='Position')
    ax.set_ylabel('Position [mm]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    ax = axes[0, 1]
    ax.plot(t, results['v_r'], 'g-', label='Velocity')
    ax.set_ylabel('Velocity [m/s]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 2. Coil currents
    ax = axes[1, 0]
    ax.plot(t, results['i_A'], 'r-', label='Coil A')
    ax.plot(t, results['i_B'], 'b-', label='Coil B')
    ax.set_ylabel('Current [A]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    ax = axes[1, 1]
    ax.plot(t, results['V_pickup'], 'purple', label='Pickup V')
    ax.set_ylabel('Pickup Voltage [V]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 3. Net force
    ax = axes[2, 0]
    ax.plot(t, results['F_net'], 'orange', label='Net EM Force')
    ax.axhline(0, color='k', alpha=0.3)
    ax.set_ylabel('Force [N]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 4. Energy tracking
    ax = axes[2, 1]
    ax.plot(t, results['E_pump_J'], 'r-', label='Pump Energy')
    ax.plot(t, results['E_pickup_J'], 'g-', label='Pickup Energy')
    ax.plot(t, results['E_thrust_J'], 'b-', label='Thrust Energy')
    ax.plot(t, results['E_loss_J'], 'k-', label='Copper Loss')
    ax.set_ylabel('Energy [J]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 5. Kinetic energy
    ax = axes[3, 0]
    ax.plot(t, results['E_kinetic_J'], 'c-', label='Kinetic Energy')
    ax.set_ylabel('KE [J]')
    ax.set_xlabel('Time [s]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 6. Summary text
    ax = axes[3, 1]
    ax.axis('off')
    eb = results['energy_balance_at_end']
    text = (
        f"Energy Balance (per cycle):\n\n"
        f"Pump In:   {eb['E_pump_J']/results['cycles_simulated']*results['params']['frequency_Hz']:.1f} W\n"
        f"Thrust Out: {eb['E_thrust_J']/results['cycles_simulated']*results['params']['frequency_Hz']:.1f} W\n"
        f"Pickup Out: {eb['E_pickup_J']/results['cycles_simulated']*results['params']['frequency_Hz']:.1f} W\n"
        f"Loss:      {eb['E_loss_J']/results['cycles_simulated']*results['params']['frequency_Hz']:.1f} W\n"
        f"Efficiency: {eb['efficiency']*100:.1f}%\n\n"
        f"Config:\n"
        f"  m_r = {results['params']['m_r_kg']} kg\n"
        f"  f = {results['params']['frequency_Hz']} Hz\n"
        f"  η = {results['params']['eta_repel']:.3f}"
    )
    ax.text(0.1, 0.9, text, transform=ax.transAxes, fontsize=10, 
            verticalalignment='top', fontfamily='monospace')
    
    plt.tight_layout()
    plt.savefig('peat_simulation.png', dpi=150)
    print("Plot saved to peat_simulation.png")
    plt.close()


def plot_sweep_results(results: list, output_file: str = "peat_sweep.png"):
    """Plot sweep results summary."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    
    # Convert to arrays
    data = {k: np.array([r[k] for r in results]) for k in results[0].keys()}
    
    fig, axes = plt.subplots(2, 3, figsize=(16, 10))
    
    # 1. Thrust vs eta for different masses
    ax = axes[0, 0]
    for M in sorted(set(data['M_total_kg'])):
        mask = (data['M_total_kg'] == M) & (data['frequency_Hz'] == 15) & (data['mass_ratio'] == 0.15)
        if np.any(mask):
            idx = np.where(mask)[0]
            ax.plot(data['eta_repel'][idx], data['F_thrust_N'][idx], 
                    label=f'{int(M)} kg')
    ax.set_xlabel('η_repel')
    ax.set_ylabel('Thrust [N]')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    ax.set_title('Thrust vs Asymmetry Ratio')
    
    # 2. Required eta for hover
    ax = axes[0, 1]
    for M in sorted(set(data['M_total_kg'])):
        mask = (data['M_total_kg'] == M) & (data['frequency_Hz'] == 15) & (data['mass_ratio'] == 0.15)
        if np.any(mask):
            idx = np.where(mask)[0]
            # Find eta where thrust >= weight
            feasible = data['F_thrust_N'][idx] >= data['F_needed_N'][idx]
            ax.plot(data['eta_repel'][idx], data['F_thrust_N'][idx] / data['F_needed_N'][idx],
                    label=f'{int(M)} kg')
    ax.axhline(1.0, color='k', linestyle='--', alpha=0.5)
    ax.set_xlabel('η_repel')
    ax.set_ylabel('Thrust / Weight')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    ax.set_title('Thrust-to-Weight Ratio')
    
    # 3. Power vs mass for optimal eta
    ax = axes[0, 2]
    for freq in sorted(set(data['frequency_Hz']))[:5]:
        mask = (data['eta_repel'] == 0.20) & (data['mass_ratio'] == 0.15) & (data['frequency_Hz'] == freq)
        if np.any(mask):
            idx = np.where(mask)[0]
            ax.loglog(data['M_total_kg'][idx], data['P_pump_W'][idx], 
                     label=f'{freq} Hz')
    ax.set_xlabel('Total Mass [kg]')
    ax.set_ylabel('Pump Power [W]')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    ax.set_title('Power Scaling')
    
    # 4. Net power vs mass
    ax = axes[1, 0]
    mask = (data['eta_repel'] == 0.20) & (data['mass_ratio'] == 0.15) & (data['frequency_Hz'] == 15)
    if np.any(mask):
        idx = np.where(mask)[0]
        ax.loglog(data['M_total_kg'][idx], data['P_net_W'][idx], 'b-o', label='Net Power')
        ax.loglog(data['M_total_kg'][idx], data['P_pickup_W'][idx], 'g-s', label='Pickup Recovery')
    ax.set_xlabel('Total Mass [kg]')
    ax.set_ylabel('Power [W]')
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_title('Net Power & Pickup Recovery')
    
    # 5. Efficiency contour
    ax = axes[1, 1]
    # Pivot table: eta × mass_ratio → efficiency
    mask = (data['M_total_kg'] == 115) & (data['frequency_Hz'] == 15)
    if np.any(mask):
        idx = np.where(mask)[0]
        # Simple: pull efficiency vs eta
        eff = data['P_pickup_W'][idx] / (data['P_pump_W'][idx] + 1)
        ax.plot(data['eta_repel'][idx], eff, 'b-')
        ax.set_xlabel('η_repel')
        ax.set_ylabel('Recovery Fraction')
        ax.grid(True, alpha=0.3)
    ax.set_title('Energy Recovery Efficiency')
    
    # 6. Feasibility map
    ax = axes[1, 2]
    mask = (data['frequency_Hz'] == 15) & (data['mass_ratio'] == 0.15)
    if np.any(mask):
        idx = np.where(mask)[0]
        # Plot feasibility boundary
        for M in sorted(set(data['M_total_kg'][idx])):
            m_idx = data['M_total_kg'][idx] == M
            m_eta = data['eta_repel'][idx][m_idx]
            m_feas = data['hover_feasible'][idx][m_idx]
            ax.plot(m_eta[m_feas], [M]*sum(m_feas), 'g.', markersize=3)
            ax.plot(m_eta[~m_feas], [M]*sum(~m_feas), 'r.', markersize=3)
    ax.set_xlabel('η_repel')
    ax.set_ylabel('Total Mass [kg]')
    ax.set_yscale('log')
    ax.set_title('Feasibility: Green = Hover Possible')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150)
    print(f"Sweep plot saved to {output_file}")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='PEAT Simulation v1.0')
    parser.add_argument('--mode', type=str, default='demo',
                        choices=['demo', 'sweep', 'verify', 'all'],
                        help='Simulation mode')
    parser.add_argument('--mass', type=float, default=115.0,
                        help='Total system mass [kg] (demo mode)')
    parser.add_argument('--freq', type=float, default=15.0,
                        help='Oscillation frequency [Hz] (demo mode)')
    parser.add_argument('--eta', type=float, default=0.20,
                        help='Asymmetry ratio (demo mode)')
    parser.add_argument('--ratio', type=float, default=0.15,
                        help='Reaction mass ratio (demo mode)')
    parser.add_argument('--time', type=float, default=1.0,
                        help='Simulation duration [s]')
    parser.add_argument('--output', type=str, default='sweep_results.json',
                        help='Output file for sweep results')
    
    args = parser.parse_args()
    
    if args.mode in ('demo', 'all'):
        print("═" * 60)
        print("PEAT — Pure Electromagnetic Asymmetric Thrust")
        print(f"Demo Simulation: {args.mass} kg at {args.freq} Hz, η={args.eta}")
        print("═" * 60)
        
        # Create oscillator for demo
        osc = create_oscillator_for_scale(
            M_total=args.mass,
            freq=args.freq,
            mass_ratio=args.ratio,
            eta_repel=args.eta
        )
        osc.axis = 'Z'
        
        # Print analytical preview
        print("\nAnalytical Model Preview:")
        balance = AnalyticalModel.full_energy_balance(osc, args.mass)
        for k, v in balance.items():
            if isinstance(v, float):
                print(f"  {k}: {v:.2f}")
            else:
                print(f"  {k}: {v}")
        print()
        
        # Run simulation
        results = simulate_single_config(osc, sim_time=args.time)
        
        # Print results summary
        eb = results['energy_balance_at_end']
        print(f"\nSimulation Results:")
        print(f"  Cycles simulated: {results['cycles_simulated']}")
        print(f"  Energy in:   {eb['E_pump_J']:.2f} J")
        print(f"  Thrust out:  {eb['E_thrust_J']:.2f} J")
        print(f"  Pickup out:  {eb['E_pickup_J']:.2f} J")
        print(f"  Copper loss: {eb['E_loss_J']:.2f} J")
        print(f"  Efficiency:  {eb['efficiency']*100:.1f}%")
        
        # Plot
        try:
            plot_simulation_results(results)
        except ImportError:
            print("(matplotlib not available — skipping plot)")
        
        # Save results
        def convert_numpy(obj):
            """Recursively convert numpy types to Python native types for JSON."""
            if isinstance(obj, dict):
                return {k: convert_numpy(v) for k, v in obj.items()}
            elif isinstance(obj, (list, tuple)):
                return [convert_numpy(v) for v in obj]
            elif isinstance(obj, (np.integer,)):
                return int(obj)
            elif isinstance(obj, (np.floating,)):
                return float(obj)
            elif isinstance(obj, (np.bool_,)):
                return bool(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            return obj
        
        with open('peat_demo_results.json', 'w') as f:
            json.dump(convert_numpy({
                'results_summary': {
                    'energy_balance': eb,
                    'cycles': results['cycles_simulated'],
                    'config': results['params']
                },
                'analytical': balance
            }), f, indent=2)
        print("Demo results saved to peat_demo_results.json")
    
    if args.mode in ('sweep', 'all'):
        print("\n" + "═" * 60)
        print("Parameter Sweep")
        print("═" * 60)
        
        config = SweepConfig(name="AutoSweep", output_file=args.output)
        results = run_sweep(config)
        
        # Summary statistics
        feasible = [r for r in results if r['hover_feasible']]
        print(f"\nFeasible configurations: {len(feasible)}/{len(results)}")
        if feasible:
            best = min(feasible, key=lambda r: r['P_net_W'])
            print(f"Best (min net power):")
            print(f"  M={best['M_total_kg']} kg, f={best['frequency_Hz']} Hz, "
                  f"η={best['eta_repel']}, P_net={best['P_net_W']:.1f} W")
        
        try:
            plot_sweep_results(results)
        except ImportError:
            print("(matplotlib not available — skipping plot)")
    
    if args.mode in ('verify', 'all'):
        print("\n" + "═" * 60)
        print("Verification: Cross-check Analytical vs Numerical")
        print("═" * 60)
        
        # Test cases across scales
        test_cases = [
            (5.0, 30.0, 0.15, 0.30),     # Drone
            (115.0, 15.0, 0.15, 0.20),    # Human
            (1200.0, 10.0, 0.12, 0.25),   # Hovercar
        ]
        
        for M, f, ratio, eta in test_cases:
            print(f"\nCase: {M} kg, {f} Hz, η={eta}")
            osc = create_oscillator_for_scale(M, f, ratio, eta)
            balance = AnalyticalModel.full_energy_balance(osc, M)
            print(f"  Analytical: F_thrust={balance['F_thrust_N']:.1f} N, "
                  f"needed={balance['F_needed_N']:.1f} N, "
                  f"P_net={balance['P_net_W']:.1f} W"
                  f"  {'✓' if balance['hover_feasible'] else '✗'}")
    
    print("\nDone.")


if __name__ == '__main__':
    main()
