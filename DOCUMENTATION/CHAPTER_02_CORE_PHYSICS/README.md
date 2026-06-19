# CHAPTER 2: CORE PHYSICS

## Pure Electromagnetic Asymmetric Thrust — Complete Physical Basis

**Version:** 1.0 &nbsp;|&nbsp; **Status:** FRAMEWORK &nbsp;|&nbsp; **System:** PEAT v1

---

# Table of Contents

1. [Electromagnetic Theory](#1-electromagnetic-theory)
2. [Inductance Modulation — The L(x) Model](#2-inductance-modulation--the-lx-model)
3. [Coil Force Equation](#3-coil-force-equation)
4. [Asymmetric Push-Pull Mechanism](#4-asymmetric-push-pull-mechanism)
5. [Parametric Resonance at 2ω₀](#5-parametric-resonance-at-2%cf%89%e2%82%80)
6. [6-DOF Extension](#6-6-dof-extension)
7. [Generator Physics — Pickup Coils](#7-generator-physics--pickup-coils)
8. [Simultaneous Generation — AFPM Model](#8-simultaneous-generation--afpm-model)
9. [Energy Conservation — Power Balance Accounting](#9-energy-conservation--power-balance-accounting)
10. [Nomenclature](#10-nomenclature)

---

# 1. Electromagnetic Theory

## 1.1 Governing Maxwell's Equations

The PEAT mechanism operates entirely within classical electromagnetism. The relevant subset of Maxwell's equations in differential form:

$$
\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}
\qquad\text{(Faraday's Law)}
$$

$$
\nabla \times \mathbf{H} = \mathbf{J} + \frac{\partial \mathbf{D}}{\partial t}
\qquad\text{(Ampere's Law with Maxwell's correction)}
$$

$$
\nabla \cdot \mathbf{B} = 0
\qquad\text{(Gauss's Law for Magnetism)}
$$

where $\mathbf{E}$ is electric field, $\mathbf{B}$ is magnetic flux density, $\mathbf{H}$ is magnetic field intensity, $\mathbf{J}$ is current density, and $\mathbf{D}$ is electric displacement field.

For the quasistatic regime that dominates PEAT operation (oscillation frequencies 8--50 Hz, well below RF), the displacement current term $\partial \mathbf{D}/\partial t$ is negligible compared to conduction currents $\mathbf{J}$, and Ampere's Law reduces to:

$$
\nabla \times \mathbf{H} \approx \mathbf{J}
$$

This is the **magnetostatic approximation** — at any instant, the magnetic field is determined by the instantaneous current distribution, with propagation delays ($\sim$ns at laboratory scale) being irrelevant.

## 1.2 Magnetic Field of a Solenoid

A coil of $N$ turns, length $\ell$, and radius $a$, carrying current $i$, produces an on-axis magnetic field:

$$
B_z(z) = \frac{\mu_0 N i}{2\ell}\left[ \frac{z + \ell/2}{\sqrt{a^2 + (z + \ell/2)^2}} - \frac{z - \ell/2}{\sqrt{a^2 + (z - \ell/2)^2}} \right]
$$

At the center of a long solenoid ($\ell \gg a$), this simplifies to the familiar form:

$$
B_{\text{center}} = \frac{\mu_0 N i}{\ell} = \mu_0 n i
$$

where $n = N/\ell$ is the turn density.

**Importance for PEAT:** The magnetic field interacts with the reaction mass (a ferromagnetic or conducting body). When the reaction mass is a ferromagnetic material (e.g., iron, steel), it becomes magnetized by the coil field, creating an effective magnetic dipole $\mathbf{m}$ that experiences force:

$$
\mathbf{F} = \nabla(\mathbf{m} \cdot \mathbf{B})
$$

For a linear, unsaturated ferromagnetic material with susceptibility $\chi_m$, the magnetization is $\mathbf{M} = \chi_m \mathbf{H}$, and the induced dipole moment scales as $\mathbf{m} \propto \chi_m V \mathbf{H}$, where $V$ is the reaction mass volume.

## 1.3 Coil Inductance — Physical Origin

The self-inductance of a coil is defined by the flux linkage per unit current:

$$
L = \frac{N\Phi}{i} = \frac{N}{i}\iint_S \mathbf{B} \cdot d\mathbf{A}
$$

For a coil in free space, $L$ depends only on geometry (number of turns, cross-sectional area, length). However, when a ferromagnetic reaction mass is present near the coil, the magnetic circuit changes dramatically:

- The reaction mass provides a **low-reluctance path** for magnetic flux
- Flux is concentrated through the reaction mass, increasing the total flux linkage
- The effective inductance **increases** as the reaction mass approaches

This position-dependent inductance $L(x)$ is the **foundational physical mechanism** of PEAT. Without it, the force equation (Section 3) would yield zero net force.

---

# 2. Inductance Modulation — The L(x) Model

## 2.1 Position-Dependent Inductance

When a ferromagnetic reaction mass is at distance $x$ from the coil face, the magnetic circuit consists of:

1. **Core path:** flux through the coil's own core (if present)
2. **Gap path:** flux crossing the air gap to the reaction mass
3. **Reaction mass path:** flux through the mass itself
4. **Return path:** flux completing the circuit back to the coil

The total reluctance $\mathcal{R}_{\text{total}}(x)$ is the sum of these path reluctances. Since the gap reluctance varies with $x$, the total inductance is:

$$
L(x) = \frac{N^2}{\mathcal{R}_{\text{total}}(x)}
$$

## 2.2 The Lorentzian Inductance-Distance Function

Through empirical measurement and physical reasoning, the distance-dependent inductance is well-modeled by a Lorentzian (Cauchy) function:

$$
\boxed{ L(x) = L_{\infty} + \frac{L_{\text{close}} - L_{\infty}}{1 + (x/d_{\text{ref}})^2} }
$$

where:

| Symbol | Meaning |
|--------|---------|
| $L_{\infty}$ | Inductance when reaction mass is at infinite distance (free-space coil inductance) |
| $L_{\text{close}}$ | Inductance when reaction mass is in contact with coil face ($x \to 0$) |
| $d_{\text{ref}}$ | Characteristic distance at which the inductance variation reaches half its maximum |
| $x$ | Distance from coil face to the nearest surface of the reaction mass |

**Physical justification:** The Lorentzian form arises from the overlap integral of the coil's field distribution (which falls off approximately as $1/(1 + (x/a)^2)$ for a finite coil) with the reaction mass volume. While a pure $1/x$ dependence might be expected for a point dipole interacting with a coil, the finite geometry of both coil and reaction mass regularizes the singularity, producing the smooth Lorentzian.

**Properties of the L(x) function:**

- $L(0) = L_{\text{close}}$ — maximum inductance at closest approach
- $L(\infty) = L_{\infty}$ — asymptotic minimum at large distance
- $L(d_{\text{ref}}) = L_{\infty} + (L_{\text{close}} - L_{\infty})/2$ — half-maximum point
- Smooth, monotonic decreasing with $x$
- Infinitely differentiable

### Implementation Reference

From `peat_sim_v2.py` (CoilParams class):

```python
def inductance(self, x: float) -> float:
    L_variation = (self.L_close - self.L_inf) / (1.0 + (x / self.d_ref)**2)
    return self.L_inf + L_variation
```

## 2.3 The Inductance Gradient — dL/dx

The force produced by the coil depends on the **gradient** of inductance with respect to position, not the absolute value. Differentiating the Lorentzian:

$$
\boxed{ \frac{dL}{dx} = -\frac{2 (L_{\text{close}} - L_{\infty}) \, x}{d_{\text{ref}}^2 \left(1 + (x/d_{\text{ref}})^2\right)^2} }
$$

**Physical interpretation:**
- For $x > 0$ (mass approaching the coil), $dL/dx$ is **negative** — inductance decreases as the mass moves away from the coil
- The gradient magnitude peaks at $x = d_{\text{ref}}/\sqrt{3}$, then falls to zero at both $x=0$ and $x \to \infty$
- The maximum gradient magnitude is:

$$
\left|\frac{dL}{dx}\right|_{\text{max}} = \frac{3\sqrt{3}}{8} \frac{L_{\text{close}} - L_{\infty}}{d_{\text{ref}}}
\approx 0.65 \frac{L_{\text{close}} - L_{\infty}}{d_{\text{ref}}}
$$

### Implementation Reference

From `peat_sim_v2.py` (CoilParams class):

```python
def dL_dx(self, x: float) -> float:
    denom = (1.0 + (x / self.d_ref)**2)**2
    return -2.0 * (self.L_close - self.L_inf) * x / (self.d_ref**2 * denom)
```

## 2.4 Typical Parameter Values

For the 115 kg human-scale baseline (PEAT_MASTER v1.1):

| Parameter | Value | Notes |
|-----------|-------|-------|
| $L_{\infty}$ | 0.1 H | Free-air coil inductance |
| $L_{\text{close}}$ | 0.4 H | 4× increase from reaction mass proximity |
| $d_{\text{ref}}$ | 0.01 m | Characteristic length (~coil radius) |
| $\max\|dL/dx\|$ | ~19.5 H/m | At $x \approx 0.0058$ m |

---

# 3. Coil Force Equation

## 3.1 Energy Method Derivation

The force on a magnetic system can be derived from energy conservation. For a system of $n$ coils carrying currents $i_j$, the total magnetic energy stored is:

$$
W_m = \frac{1}{2} \sum_{j=1}^{n} \sum_{k=1}^{n} L_{jk} \, i_j \, i_k
$$

For a single coil ($n=1$), this reduces to:

$$
W_m = \frac{1}{2} L(x) \, i^2
$$

The mechanical force in the $x$-direction is the negative gradient of stored energy with respect to displacement, holding current **constant**:

$$
F = -\left.\frac{\partial W_m}{\partial x}\right|_{i=\text{const}}
= -\frac{1}{2} i^2 \frac{dL}{dx}
$$

However, the sign convention matters. The quantity $dL/dx$ is negative when the mass approaches the coil (inductance increases as $x$ decreases). To express force in the physically intuitive direction (positive = attraction toward the coil), we define:

$$
\boxed{ F_{\text{mag}} = \frac{1}{2} \, i^2 \, \frac{dL}{dx} }
$$

where now $dL/dx$ carries its sign from the $L(x)$ derivative. Since $dL/dx$ is **negative** for $x > 0$, $F_{\text{mag}}$ is negative, meaning the force pulls the mass toward the coil (decreasing $x$).

**Key insight:** The force is proportional to $i^2$, not $i$. This means:
- Force is always **attractive** (pulling the mass toward the coil) regardless of current direction
- To achieve repulsion, a second coil on the opposite side must be energized
- The quadratic dependence on current creates inherent nonlinearity

## 3.2 Circuit Equation

The coil is an RL circuit with variable inductance. The voltage across the coil is:

$$
V = iR + \frac{d}{dt}(L i) = iR + L\frac{di}{dt} + i\frac{dL}{dt}
$$

Using the chain rule, $dL/dt = (dL/dx) \cdot (dx/dt) = (dL/dx) \cdot v$, we obtain:

$$
\boxed{ V = iR + L\frac{di}{dt} + i\,v\,\frac{dL}{dx} }
$$

The three terms represent:
1. **$iR$** — Resistive voltage drop (Ohm's law)
2. **$L \, di/dt$** — Inductive voltage (self-inductance)
3. **$i \, v \, dL/dx$** — **Back-EMF** or motion-induced voltage (coupling term)

The back-EMF term is the mechanism by which mechanical motion affects the electrical circuit, and vice versa. It represents the conversion of mechanical energy to electrical energy (generator mode) or electrical energy to mechanical energy (motor mode).

## 3.3 Current Dynamics

From the circuit equation, the current derivative is:

$$
\frac{di}{dt} = \frac{1}{L(x)}\left(V - iR - i\,v\,\frac{dL}{dx}\right)
$$

This is the key equation that couples the electrical and mechanical subsystems. It is implemented in `peat_sim_v2.py` as:

```python
def current_derivative(self, i, V_applied, L, dLdx, v):
    back_emf = v * i * dLdx
    di_dt = (V_applied - i * R_eff - back_emf) / L
    return di_dt
```

## 3.4 Complete Coil Force in System Context

For a single oscillator pair (two coils A and B, on opposite sides of the reaction mass), the net electromagnetic force on the reaction mass is:

$$
F_{\text{EM,net}} = \frac{1}{2} i_A^2 \frac{dL_A}{dx_A} - \frac{1}{2} i_B^2 \frac{dL_B}{dx_B}
$$

where $x_A = d_{\text{rest}} - x_r$ and $x_B = d_{\text{rest}} + x_r$, with $x_r$ being the reaction mass displacement from center (positive toward coil A) and $d_{\text{rest}}$ the rest gap to each coil face.

---

# 4. Asymmetric Push-Pull Mechanism

## 4.1 The Core Concept

The asymmetric push-pull mechanism generates **net impulse per cycle** by deliberately creating asymmetric force profiles during the attraction and repulsion phases of each oscillation cycle.

Consider a reaction mass oscillating between two electromagnets (coils A and B). A complete cycle consists of four phases:

```
Phase      | Duration        | Coil A | Coil B | Effect on Mass
-----------|-----------------|--------|--------|----------------
ATTRACT    | t_attract       | ON     | OFF    | Pulled toward A (+x)
COAST      | t_coast1        | OFF    | OFF    | Free coasting
REPEL      | t_repel         | OFF    | ON     | Pulled toward B (-x)
COAST      | t_coast2        | OFF    | OFF    | Free coasting
```

**The asymmetry arises from differences in current rise/fall times** caused by the position-dependent inductance $L(x)$.

## 4.2 L/R Time Constant Asymmetry

When the reaction mass is **close** to a coil, the inductance is high ($L \approx L_{\text{close}}$), and the electrical time constant is:

$$
\tau_{\text{close}} = \frac{L_{\text{close}}}{R}
$$

When the mass is **far** from a coil, the inductance is low ($L \approx L_{\infty}$), and the time constant is:

$$
\tau_{\text{far}} = \frac{L_{\infty}}{R}
$$

Since $L_{\text{close}} \gg L_{\infty}$, we have $\tau_{\text{close}} \gg \tau_{\text{far}}$.

**Attraction phase:** When the mass is at its furthest point from coil A (ready to be attracted), coil A has low inductance → fast current rise → high force builds quickly.

**Repulsion phase:** When the mass is close to coil B (ready to be repelled), coil B has high inductance → slow current rise → force builds slowly.

Additionally, **voltage asymmetry** can be applied — a higher bus voltage during attraction (e.g., full $V_{\text{bus}}$) versus a reduced voltage during repulsion (e.g., $V_{\text{bus}} \times V_{\text{repel\_frac}}$ where $V_{\text{repel\_frac}} \approx 0.3$).

The combined effect: the attraction impulse dominates over the repulsion impulse, producing **net thrust** on the reaction mass. By Newton's third law, an equal and opposite impulse is delivered to the frame (vehicle), producing propulsion.

## 4.3 Current Waveform Model

For a voltage-source drive with applied voltage $V_0$ and series resistance $R$, the current rise follows:

$$
i(t) = \frac{V_0}{R}\left(1 - e^{-t/\tau}\right)
$$

where $\tau = L/R$. At the end of the drive pulse ($t = t_{\text{on}}$), the current is:

$$
i_{\text{peak}} = \frac{V_0}{R}\left(1 - e^{-t_{\text{on}}/\tau}\right)
$$

During freewheeling (coast phase), current decays through a diode path:

$$
i(t) = i_{\text{peak}} \, e^{-t/\tau_{\text{freewheel}}}
$$

where $\tau_{\text{freewheel}}$ is typically larger than $\tau$ (different circuit path, often involving a higher-resistance or slower decay path to extend the force tail).

## 4.4 Impulse Per Cycle

The impulse delivered during a phase is the time integral of force:

$$
I_{\text{attract}} = \int_0^{t_{\text{attract}}} \frac{1}{2} i_A(t)^2 \frac{dL}{dx}(x_A(t)) \, dt
$$

$$
I_{\text{repel}} = \int_0^{t_{\text{repel}}} \frac{1}{2} i_B(t)^2 \frac{dL}{dx}(x_B(t)) \, dt
$$

The **net impulse per cycle** is:

$$
\boxed{ I_{\text{net}} = I_{\text{attract}} - I_{\text{repel}} }
$$

And the **net thrust** (force) from this oscillator pair is:

$$
\boxed{ F_{\text{thrust}} = f \cdot I_{\text{net}} }
$$

where $f$ is the cycle frequency.

## 4.5 Asymmetry Ratio

The asymmetry ratio quantifies the degree of imbalance:

$$
\boxed{ \eta_{\text{repel}} = \frac{I_{\text{repel}}}{I_{\text{attract}}} }
$$

Physical range: $\eta_{\text{repel}} \in [0.05, 0.50]$

- $\eta_{\text{repel}} \to 0$: Pure attraction — maximum thrust per cycle, but oscillation amplitude grows uncontrollably
- $\eta_{\text{repel}} \to 1$: Symmetric — zero net thrust, no propulsion
- $\eta_{\text{repel}} \approx 0.20$: Recommended baseline — balances thrust vs. control

The **net thrust fraction** is:

$$
\xi = 1 - \eta_{\text{repel}}
$$

At $\eta_{\text{repel}} = 0.20$, $\xi = 0.80$, meaning 80% of the ideal oscillator thrust is achieved.

## 4.6 Analytical Thrust Model

From `peat_sim_v2.py` (AnalyticalModel class):

```python
def thrust_per_oscillator(m_r, f, z0, eta_repel):
    omega_0 = 2.0 * np.pi * f
    v_peak = omega_0 * z0
    xi = 1.0 - eta_repel
    return 2.0 * xi * f * m_r * v_peak
```

In equation form:

$$
F_{\text{thrust}} = 2 \xi f m_r v_{\text{peak}} = 2 (1 - \eta_{\text{repel}}) f m_r \omega_0 z_0
$$

The factor of 2 arises because two impulses occur per cycle (one per coil direction).

---

# 5. Parametric Resonance at 2ω₀

## 5.1 Parametric Pumping Principle

Parametric resonance occurs when a parameter of an oscillatory system is modulated at **twice the natural frequency**. Unlike forced resonance (where an external force directly drives the oscillation), parametric resonance involves modulating a system property (stiffness, inductance, capacitance) to inject energy.

The classic example is a swing: instead of pushing the swing (forced resonance), you stand on the swing and rhythmically crouch and stand (modulating your center of mass — effectively changing the pendulum length at $2\omega_0$).

## 5.2 The Mathieu Equation

For PEAT, the stiffness of the magnetic suspension is modulated at $2\omega_0$. The equation of motion becomes:

$$
\boxed{ m \ddot{x} + \left(k_0 + k_{\text{pump}} \sin(2\omega_0 t + \phi)\right) x = 0 }
$$

Dividing by $m$ and defining $\omega_0^2 = k_0/m$ and $h = k_{\text{pump}}/k_0$ (modulation depth):

$$
\ddot{x} + \omega_0^2 \left(1 + h \sin(2\omega_0 t + \phi)\right) x = 0
$$

This is a form of **Mathieu's equation**, which exhibits parametric resonance when the modulation frequency is $2\omega_0/n$ for integer $n$. The $n=1$ case ($2\omega_0$ modulation) is the strongest.

## 5.3 Stability and Growth

The solution to the Mathieu equation shows regions of exponential growth (instability) separated by regions of stability. In the ($h$, $\omega_{\text{pump}}/\omega_0$) plane, these are the **Arnold tongues** or **Ince-Strutt diagram**.

For small modulation depth $h \ll 1$ at $\omega_{\text{pump}} = 2\omega_0$, the amplitude growth rate is:

$$
\gamma \approx \frac{h \omega_0}{4}
$$

The oscillation amplitude grows as $e^{\gamma t}$ until nonlinearities or losses saturate the growth.

## 5.4 Power Flow and Phase Dependence

The key parameter for practical application is the **phase** of the modulation relative to the oscillation:

| Phase $\phi$ | Effect |
|:---:|---|
| $+\pi/2$ | Energy flows **into** oscillation (amplification — thruster mode) |
| $-\pi/2$ | Energy flows **out of** oscillation (damping — generator mode) |

The power injected (or extracted) by parametric pumping is:

$$
\boxed{ P_{\text{pump}} = \frac{1}{4} k_0 \, h \, \omega_0 \, z_0^2 }
$$

where $z_0$ is the oscillation half-amplitude and $k_0 = m_r \omega_0^2$ is the effective stiffness.

### Implementation Reference

From `peat_sim_v2.py`:

```python
def pump_power_parametric(k0, h, omega_0, z0):
    k0 = m_r * omega_0**2
    return 0.25 * k0 * h * omega_0 * z0**2
```

## 5.5 Parametric Enhancement of Asymmetry

In PEAT, parametric pumping **enhances** the natural asymmetry. The parametric modulation adds an extra energy injection mechanism that:

1. **Maintains oscillation amplitude** against damping and thrust extraction
2. **Allows phase control** — switching between thruster mode and generator mode by adjusting the pump phase
3. **Enables synchronization** — a phase-locked loop (PLL) tracks the oscillation phase and locks the pump phase to maintain optimal energy transfer

The pump modulation is applied to the drive voltage:

```python
pump_signal = h * np.sin(omega_pump * t + phi)
V_A *= (1.0 + pump_signal)
```

This amplitude-modulates the coil voltage at $2\omega_0$, pumping energy into (or extracting from) the oscillation.

## 5.6 Phase-Locked Loop Requirement

For reliable parametric pumping, the pump phase must be locked to the oscillation phase with <5° electrical accuracy. At $2\omega_0 = 30$ Hz (for a 15 Hz oscillation), 5° electrical corresponds to:

$$
\Delta t = \frac{5^\circ}{360^\circ} \cdot \frac{1}{30\,\text{Hz}} \approx 0.46\,\text{ms}
$$

Achievable with a 10 kHz sensor measurement rate and Kalman-filtered PLL.

---

# 6. 6-DOF Extension

## 6.1 From 1-DOF Oscillator to 3D Array

A single oscillator pair produces thrust along one axis. For full rigid-body control (6 degrees of freedom), three orthogonal pairs are required:

| Pair | Axis | Primary Function | Attitude Control |
|:----:|:----:|:----------------:|:----------------:|
| Z+, Z− | Vertical (z) | Lift/thrust against gravity | Yaw |
| X+, X− | Longitudinal (x) | Forward/backward | Roll |
| Y+, Y− | Lateral (y) | Left/right | Pitch |

## 6.2 Six-Oscillator Layout

The six oscillators are arranged physically around the vehicle frame:

```
┌─ TOP VIEW ────────┐    ┌─ SIDE VIEW ────────┐
│  Y−          Y+    │    │  Z+                │
│    ●         ●     │    │    ●               │
│                    │    │         ○ frame    │
│  X−●  frame ●X+   │    │  X−●──○──●X+      │
│                    │    │         ○          │
│  Z−          Z+    │    │    ●               │
│    ●         ●     │    │  Z−                │
└────────────────────┘    └────────────────────┘
```

Each pair can be independently controlled:
- **Amplitude ratio** → translation force magnitude
- **Differential amplitude across pair** → moment (rotation)
- **Phase offset between pairs** → coordinated maneuvers

## 6.3 Coupled Dynamics

The full system state has 34 variables (from `peat_sim_v2.py`):

| Component | Variables | Count |
|-----------|-----------|:-----:|
| Z oscillator | $x_r, v_r, i_A, i_B, X_f, V_f, V_{\text{pickup}}$ | 7 |
| X oscillator | $x_r, v_r, i_A, i_B, X_f, V_f, V_{\text{pickup}}$ | 7 |
| Y oscillator | $x_r, v_r, i_A, i_B, X_f, V_f, V_{\text{pickup}}$ | 7 |
| Frame position | $p_x, p_y, p_z$ | 3 |
| Frame velocity | $v_x, v_y, v_z$ | 3 |
| Attitude (quaternion) | $q_w, q_x, q_y, q_z$ | 4 |
| Body angular rates | $\omega_x, \omega_y, \omega_z$ | 3 |
| **Total** | | **34** |

## 6.4 Torque Generation

Torque is produced through **differential activation** of oscillators on opposite sides of the frame. For an oscillator pair offset from the center of mass by lever arm $r$:

$$
\tau_x = r\,(F_{Y+} - F_{Y-}) \quad\text{(Roll)}
$$
$$
\tau_y = -r\,(F_{X+} - F_{X-}) \quad\text{(Pitch)}
$$
$$
\tau_z = r\,(F_{Z+\text{diff}} - F_{Z-\text{diff}}) \quad\text{(Yaw — uses differential Z pairs)}
$$

The allocation from desired force/torque vector $\mathbf{F}_{\text{desired}} = [F_x, F_y, F_z, \tau_x, \tau_y, \tau_z]^T$ to individual coil currents uses the **pseudoinverse** of the actuation matrix:

$$
\mathbf{i} = \mathbf{A}^+ \mathbf{F}_{\text{desired}}
$$

where $\mathbf{A}$ is the $6 \times N$ actuation matrix (geometry-dependent), and $\mathbf{A}^+$ is its Moore-Penrose pseudoinverse.

## 6.5 Mass Allocation

Each axis carries a different fraction of the total reaction mass, optimized for the mission profile:

| Axis | Mass Fraction | Rationale |
|:----:|:-------------:|-----------|
| Z (lift) | 50% | Must overcome gravity |
| X (longitudinal) | 30% | Forward propulsion |
| Y (lateral) | 20% | Maneuvering only |

Total reaction mass is typically 10–15% of vehicle mass at scale.

---

# 7. Generator Physics — Pickup Coils

## 7.1 Principle of Operation

The pickup coils are separate windings sharing the same magnetic circuit as the pump coils. As the reaction mass oscillates, it modulates the magnetic flux through these coils, inducing a voltage via Faraday's Law:

$$
V_{\text{pickup}} = -N_{\text{pickup}} \frac{d\Phi}{dt}
$$

The flux through the pickup coil depends on the reaction mass position. For a linearized model around the rest position:

$$
\Phi(t) \approx \Phi_0 \left(1 + \frac{x_r(t)}{d_{\text{rest}}}\right)
$$

where $\Phi_0 = B \cdot A_{\text{core}}$ is the quiescent flux, $B$ is the magnetic field in the gap, $A_{\text{core}}$ is the core cross-sectional area, and $d_{\text{rest}}$ is the rest gap.

The induced voltage is then:

$$
\boxed{ V_{\text{pickup}} = N_{\text{pickup}} \cdot B \cdot A_{\text{core}} \cdot \frac{v_r}{d_{\text{rest}}} }
$$

where $v_r = dx_r/dt$ is the reaction mass velocity.

### Implementation Reference

From `peat_sim_v2.py`:

```python
def get_pickup_voltage(self, v_r, x_r):
    N = self.p.N_pickup
    B = self.p.pickup_field_B
    A = self.p.pickup_core_area
    d = max(self.p.d_rest, 0.001)
    return N * B * A * v_r / d
```

## 7.2 Generator as Electromagnetic Damper

When the pickup coil drives a load resistance $R_{\text{load}}$, the resulting current produces a magnetic field that opposes the motion (Lenz's Law). This interaction is mechanically equivalent to a **velocity-dependent damper**.

The generator damping coefficient is derived from power balance:

$$
P_{\text{mechanical}} = F_{\text{gen}} \cdot v_r = b_{\text{gen}} \cdot v_r^2
$$
$$
P_{\text{electrical}} = \frac{V_{\text{pickup}}^2}{R_{\text{load}}}
$$

Equating:

$$
b_{\text{gen}} \, v_r^2 = \frac{(N B A \, v_r / d_{\text{rest}})^2}{R_{\text{load}}}
$$

$$
\boxed{ b_{\text{gen}} = \left(\frac{N_{\text{pickup}} \cdot B \cdot A_{\text{core}}}{d_{\text{rest}}}\right)^2 \frac{1}{R_{\text{load}}} }
$$

The generator force is then:

$$
F_{\text{gen}} = -b_{\text{gen}} \, v_r
$$

### Implementation Reference

From `peat_sim_v2.py`:

```python
def generator_damping(self):
    N = self.p.N_pickup
    B = self.p.pickup_field_B
    A = self.p.pickup_core_area
    d = max(self.p.d_rest, 0.001)
    R = max(self.p.R_pickup_load, 0.001)
    return (N * B * A / d)**2 / R
```

## 7.3 Power Extraction

For a sinusoidal oscillation $x_r(t) = z_0 \sin(\omega_0 t)$ with velocity $v_r(t) = \omega_0 z_0 \cos(\omega_0 t)$, the RMS velocity is:

$$
v_{\text{rms}} = \frac{\omega_0 z_0}{\sqrt{2}}
$$

The average power extracted by the pickup coil is:

$$
\boxed{ P_{\text{pickup}} = b_{\text{gen}} \, v_{\text{rms}}^2 = \frac{1}{2} b_{\text{gen}} \, \omega_0^2 z_0^2 }
$$

### Analytical Model

From `peat_sim_v2.py`:

```python
def pickup_power_available_from_params(params):
    N = params.N_pickup
    B = params.pickup_field_B
    A = params.pickup_core_area
    d = max(params.d_rest, 0.001)
    R = max(params.R_pickup_load, 0.001)
    b_gen = (N * B * A / d)**2 / R
    omega_0 = 2.0 * np.pi * params.frequency
    v_rms = omega_0 * params.z0 / np.sqrt(2.0)
    return b_gen * v_rms**2
```

## 7.4 Load Modulation (MPPT)

The effective load resistance $R_{\text{load}}$ can be adjusted in real-time (via a DC-DC converter or PWM rectifier) to implement Maximum Power Point Tracking (MPPT). The generator damping $b_{\text{gen}}$ is inversely proportional to $R_{\text{load}}$, so:

- Lower $R_{\text{load}}$ → higher damping → more power extraction, but greater suppression of oscillation
- Higher $R_{\text{load}}$ → lower damping → less power extraction, oscillation amplitude maintained

The MPPT algorithm adjusts $R_{\text{load}}$ to maximize $P_{\text{pickup}}$ while keeping oscillation amplitude within bounds.

---

# 8. Simultaneous Generation — AFPM Model

## 8.1 Axial Flux Permanent Magnet Generator

The AFPM (Axial Flux Permanent Magnet) generator is a **separate** power generation system, not the pickup coils. It converts mechanical rotation into electrical power to supply the system's net energy deficit.

**Construction:**
- **Rotor:** Disk with permanent magnets (NdFeB N52) arranged in alternating polarity
- **Stator:** Planar coils on a stationary disk, with axial flux paths through the air gap

**Output power (scaled):**

$$
P_{\text{AFPM}} = \eta_{\text{gen}} \cdot \tau_{\text{shaft}} \cdot \omega_{\text{rotor}}
$$

where $\tau_{\text{shaft}}$ is mechanical input torque, $\omega_{\text{rotor}}$ is rotational speed, and $\eta_{\text{gen}}$ is generator efficiency (typically 85–95%).

## 8.2 Simultaneous Generation Concept

The same oscillation that produces thrust also induces voltage in **both** the pump and pickup coils. This is not a violation of physics — it is simply a shared magnetic circuit with multiple windings, analogous to a transformer:

```
Electrical Analogy:
  Primary winding   = pump coil (energy in)
  Secondary winding = pickup coil (energy out)
  Moving core       = oscillating reaction mass
```

**Key physics constraints:**
1. The flux is shared — energy extracted by pickup coils directly reduces the energy available for thrust
2. The pickup load appears as additional damping on the oscillation
3. The pump must replenish this extracted energy plus all losses

## 8.3 Unified Oscillator Energy Flow

```
E_pump_in ──→ oscillation energy E_osc
                 ├──→ E_thrust  (net momentum to frame)
                 ├──→ E_pickup  (recovered electrical energy)
                 ├──→ E_loss    (copper losses, eddy currents, etc.)
                 └──→ E_remain  (sustains oscillation amplitude)
```

Steady-state condition:

$$
\boxed{ E_{\text{pump,in}} = E_{\text{thrust}} + E_{\text{pickup}} + E_{\text{loss}} }
$$

## 8.4 Practical Generation Efficiency

When the pickup coil drives a load, the damping force extracts mechanical power from the oscillation. The system is governed by the coupled ODE:

$$
m_r \ddot{x}_r = F_{\text{EM}} - b_{\text{damping}} \dot{x}_r - b_{\text{gen}} \dot{x}_r - k_{\text{susp}} x_r
$$

The net power balance requires the parametric pump to inject enough energy to counter all damping terms. The generator damping $b_{\text{gen}}$ adds directly to the loss budget.

**Numerical simulation findings (115 kg baseline):**
- Pickup recovery: ~60 W (0.06% of 100.7 kW total electrical input)
- Practical upper bound: 5–10% of total electrical input
- The weak coupling arises because the reaction mass magnetic field is shared; the pump coils must dominate to produce thrust

---

# 9. Energy Conservation — Power Balance Accounting

## 9.1 Why This Is Not Over-Unity

PEAT is **not** a perpetual motion machine. Every energy conversion channel is accounted for, and the net power balance is strictly conservative. Here is the complete accounting:

**Inputs:**
- $P_{\text{electrical}}$ — Electrical power from bus (battery/generator)
- $P_{\text{pump}}$ — Parametric pump power delivered to oscillation (subset of electrical input)

**Outputs (useful):**
- $P_{\text{thrust}}$ — Mechanical power delivered to frame as thrust
- $P_{\text{pickup}}$ — Electrical power recovered from pickup coils

**Losses (dissipated):**
- $P_{\text{copper}}$ — I²R resistive losses in all coil windings
- $P_{\text{eddy}}$ — Eddy current losses in core materials
- $P_{\text{switching}}$ — SiC MOSFET switching losses
- $P_{\text{bearing}}$ — Mechanical bearing/magnetic suspension losses
- $P_{\text{hysteresis}}$ — Magnetic hysteresis in core materials

**Steady-state energy conservation (per second = power):**

$$
\boxed{ P_{\text{electrical,in}} = P_{\text{thrust}} + P_{\text{pickup}} + P_{\text{copper}} + P_{\text{eddy}} + P_{\text{switching}} + P_{\text{bearing}} + P_{\text{hysteresis}} }
$$

## 9.2 Dominant Loss Mechanism: I²R Copper Loss

For copper-wound electromagnets at typical force densities, the I²R loss dominates all other terms:

$$
P_{\text{copper}} = I_{\text{rms}}^2 R_{\text{coil}}
$$

With peak currents of 50+ A and coil resistance ~1 Ω, the instantaneous copper loss can reach 2.5 kW per coil. Over a full cycle with two coils active ~60% of the time:

$$
P_{\text{copper,total}} \approx 2 \times 0.6 \times (50\,\text{A})^2 \times 1\,\Omega \approx 3\,\text{kW}
$$

For the numerical baseline (115 kg, 15 Hz, $\eta = 0.20$, 1 Ω coils, 48V bus):

| Power Component | Value | Fraction of Input |
|:----------------|:-----:|:-----------------:|
| Total electrical input | 100.7 kW | 100% |
| Copper loss | 99.7 kW | 99.0% |
| Thrust power | 5.1 kW | 5.1% |
| Pickup recovery | 60 W | 0.06% |
| Net deficit (must be supplied externally) | ~95.6 kW | ~94.9% |

## 9.3 The Parametric Pump Formula Clarification

The formula $P_{\text{pump}} = \frac{1}{4} k_0 h \omega_0 z_0^2$ gives only the **mechanical power delivered to the oscillation**, not the total electrical input. For the 115 kg baseline:

- Mechanical oscillation power: ~2.7 kW (from parametric pump formula)
- Total electrical input: ~100.7 kW (from full circuit simulation)

The ratio reveals: only **~2.7%** of the electrical input goes into the oscillation itself. The remaining 97.3% is dissipated as I²R heat in creating the magnetic field that produces the force.

This is **not** a design flaw — it is the fundamental physics of creating large magnetic forces with copper electromagnets. The force per ampere is set by $dL/dx$, which is limited by geometry and core material properties.

## 9.4 Efficiency Improvement Levers

| Lever | Mechanism | Potential Improvement |
|:------|:----------|:--------------------:|
| Higher bus voltage | Same power at lower current → $P = I^2R$ drops quadratically | 16× (48V → 800V) |
| Litz wire / thicker gauge | Lower resistance per meter | 2–5× |
| Higher $dL/dx$ (iron core) | More force per ampere → lower required current | 2–10× |
| Cryogenic copper (77K) | Cu resistivity drops 6× at liquid nitrogen temperature | ~6× |
| Higher frequency | More cycles/second for same amplitude | 1–2× |
| Superconducting coils | $R \approx 0$, but cryo system mass is prohibitive | ~100× (but impractical) |
| Optimized waveform | Shorter high-current pulses → lower RMS current | 1.5–2× |

Practical near-term target with 800V SiC bus, Litz wire, iron-cored coils, and optimized pulse shaping: **15–30% system efficiency**, bringing 100 kW → 15–30 kW for equivalent thrust.

## 9.5 Full Energy Balance Equation

For a complete oscillator cycle (period $T = 1/f$):

**Energy in:**
$$
E_{\text{in}} = \int_0^T \left( V_A(t) i_A(t) + V_B(t) i_B(t) \right) dt
$$

**Energy out (thrust):**
$$
E_{\text{thrust}} = \int_0^T F_{\text{net}}(t) \cdot v_r(t) \, dt
$$

**Energy out (pickup):**
$$
E_{\text{pickup}} = \int_0^T \frac{V_{\text{pickup}}(t)^2}{R_{\text{load}}} \, dt
$$

**Energy dissipated:**
$$
E_{\text{loss}} = \int_0^T \left( i_A(t)^2 R_A + i_B(t)^2 R_B \right) dt + E_{\text{eddy}} + E_{\text{switching}} + E_{\text{bearing}}
$$

**Verification condition (energy closure):**
$$
\boxed{ \left| E_{\text{in}} - E_{\text{thrust}} - E_{\text{pickup}} - E_{\text{loss}} - \Delta E_{\text{osc}} \right| < \varepsilon }
$$

where $\Delta E_{\text{osc}} = \frac{1}{2} m_r(v_{r,T}^2 - v_{r,0}^2)$ is the change in oscillation kinetic energy over the cycle, and $\varepsilon$ is the numerical tolerance.

Numerical simulations in `peat_sim_v2.py` verify this closure to within **<2%** for the coupled ODE integrator.

## 9.6 Net Power Requirement

The system requires an external power source to supply the net deficit:

$$
P_{\text{net}} = P_{\text{electrical,in}} - P_{\text{pickup}} = f \left( E_{\text{in}} - E_{\text{pickup}} \right)
$$

In the AFPM-based self-powering scheme:
- The AFPM generator provides the bulk of $P_{\text{net}}$
- The pickup coils supplement with recovered oscillation power
- A battery/capacitor buffer handles transient loads

---

# 10. Nomenclature

| Symbol | Description | Units |
|--------|-------------|:-----:|
| $\mathbf{B}$ | Magnetic flux density | T |
| $\mathbf{H}$ | Magnetic field intensity | A/m |
| $\mathbf{E}$ | Electric field | V/m |
| $\mathbf{J}$ | Current density | A/m² |
| $\Phi$ | Magnetic flux | Wb |
| $L(x)$ | Position-dependent inductance | H |
| $L_{\infty}$ | Inductance at infinite distance | H |
| $L_{\text{close}}$ | Inductance at closest approach | H |
| $d_{\text{ref}}$ | Characteristic inductance length | m |
| $d_{\text{rest}}$ | Rest gap to coil face | m |
| $dL/dx$ | Inductance gradient | H/m |
| $i$ | Coil current | A |
| $R$ | Coil resistance | Ω |
| $V$ | Applied voltage | V |
| $N$ | Number of turns | — |
| $m_r$ | Reaction mass | kg |
| $x_r$ | Reaction mass displacement | m |
| $v_r$ | Reaction mass velocity | m/s |
| $z_0$ | Oscillation half-amplitude | m |
| $f$ | Cycle frequency | Hz |
| $\omega_0 = 2\pi f$ | Angular frequency | rad/s |
| $\tau = L/R$ | Electrical time constant | s |
| $F_{\text{mag}}$ | Electromagnetic force | N |
| $I_{\text{net}}$ | Net impulse per cycle | N·s |
| $F_{\text{thrust}}$ | Net thrust | N |
| $\eta_{\text{repel}}$ | Asymmetry ratio | — |
| $\xi = 1 - \eta_{\text{repel}}$ | Net thrust fraction | — |
| $k_0 = m_r \omega_0^2$ | Equivalent stiffness | N/m |
| $h$ | Parametric modulation depth | — |
| $\phi$ | Parametric pump phase | rad |
| $P_{\text{pump}}$ | Parametric pump power | W |
| $b_{\text{gen}}$ | Generator damping coefficient | N·s/m |
| $b_{\text{damping}}$ | Mechanical damping coefficient | N·s/m |
| $M_{\text{total}}$ | Total system mass | kg |
| $A_{\text{core}}$ | Core cross-sectional area | m² |
| $\mu_0$ | Permeability of free space | H/m |

---

## References

1. **PEAT_MASTER.md** — Sections 2, 5 (Core Physics, Energy Balance), `/var/home/ryan/Documents/projects/peat-lev/`
2. **levitation_framework.md** — Sections 2, 7 (Physical Principle, Power Generation), `/var/home/ryan/Documents/projects/peat-lev/framework/`
3. **peat_sim_v2.py** — `CoilParams`, `OscillatorParams`, `SingleOscillatorODE`, `AnalyticalModel`, `/var/home/ryan/Documents/projects/peat-lev/simulation/`
4. **Mathieu, É.** "Mémoire sur le mouvement vibratoire d'une membrane de forme elliptique," *Journal de Mathématiques Pures et Appliquées*, 1868.
5. **Landau, L.D. and Lifshitz, E.M.** *Mechanics*, 3rd ed., §27 (Parametric Resonance), Butterworth-Heinemann, 1976.
6. **Griffiths, D.J.** *Introduction to Electrodynamics*, 4th ed., Cambridge University Press, 2017.
7. **Fitzgerald, A.E., Kingsley, C., and Umans, S.D.** *Electric Machinery*, 6th ed., McGraw-Hill, 2003.
