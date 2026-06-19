════════════════════════════════════════════════════════════════════════════════
CHAPTER 1: FOUNDATIONS & PREMISE
PEAT — Pure Electromagnetic Asymmetric Thrust
════════════════════════════════════════════════════════════════════════════════

Version     : 1.1                         Status    : FRAMEWORK
Chapter     : 1 of 13                     Updated   : 2026-06-19
Framework   : PEAT v1                     Author    : ARTIFICIAL INTELLIGENCE
License     : CC0 1.0 Universal — Public Domain
════════════════════════════════════════════════════════════════════════════════

───────────────────────────────────────────────────────────────────────────────
TABLE OF CONTENTS
───────────────────────────────────────────────────────────────────────────────

    1.1  What Is PEAT?
    1.2  The Core Premise
          1.2.1  Asymmetric Inductance Modulation — Mechanism A
          1.2.2  Net Impulse Per Cycle
          1.2.3  Asymmetry Ratio η_repel
          1.2.4  Parametric Resonance (2ω₀ Pump)
    1.3  What PEAT Is NOT
          1.3.1  Not Perpetual Motion
          1.3.2  Not Over-Unity
          1.3.3  Not Free Energy
          1.3.4  Not a Reactionless Drive
    1.4  Design Constraints — The EFE Filter
          1.4.1  The Seven Principles
          1.4.2  Material Hierarchy
          1.4.3  Energy Hierarchy
          1.4.4  Application in PEAT
    1.5  The OPTIBEST Premium Framework
          1.5.1  Definition of PREMIUM
          1.5.2  The Seven Dimensions
          1.5.3  The Nine Phases
          1.5.4  The Five Verification Methods
          1.5.5  Tiered Verification Protocol
    1.6  Scope
          1.6.1  Mass Range
          1.6.2  Degrees of Freedom
          1.6.3  Simultaneous Power Generation
    1.7  Non-Goals
    1.8  Terminology & Glossary
    1.9  Document Conventions
    1.10  Relationship to Other Chapters

───────────────────────────────────────────────────────────────────────────────

1.1  What Is PEAT?
───────────────────────────────────────────────────────────────────────────────

    PEAT (Pure Electromagnetic Asymmetric Thrust) is an engineering framework
    for electromagnetic levitation that produces net directional thrust by
    oscillating a reaction mass between two calibrated coils with deliberately
    asymmetric electrical time constants. The asymmetry — difference in how
    quickly current builds and decays in each coil — creates a net impulse
    per oscillation cycle, which vector sums across a six-oscillator array to
    produce controlled 6-DOF (six-degree-of-freedom) flight.

    The framework couples three physical principles into a unified system:

    1.  Asymmetric Inductance Modulation — two coils sharing a common magnetic
        circuit are driven with different voltage/time profiles so that the
        attraction phase delivers a larger impulse than the repulsion phase,
        producing a net force per cycle.

    2.  Parametric Resonant Pumping (2ω₀) — the coil stiffness is modulated at
        exactly twice the mechanical oscillation frequency, delivering energy
        to the oscillation in the same manner as a child pumping a swing by
        changing their center of mass at the right moment.

    3.  Simultaneous Generation — separate pickup windings on the same magnetic
        circuit recover electrical energy from the oscillating field, feeding
        it through an MPPT (Maximum Power Point Tracking) rectifier to the
        power bus, partially offsetting the electrical input requirement.

    PEAT is not a single device design. It is a framework: a set of physical
    principles, mathematical relationships, design patterns, scaling laws, and
    verification criteria from which specific vehicle implementations can be
    derived. The framework covers six mass classes from 5 kg drone to 5,500 kg
    hoverbus, providing parametric scaling relationships that link reactor mass,
    oscillation frequency, amplitude, coil parameters, and power budget.


───────────────────────────────────────────────────────────────────────────────

1.2  The Core Premise
───────────────────────────────────────────────────────────────────────────────

1.2.1  Asymmetric Inductance Modulation — Mechanism A

    The fundamental unit of PEAT is the oscillator pair: two electromagnets
    facing each other along a common axis with a reaction mass suspended
    between them. Each coil has an electrical time constant:

        τ_attract = L_att / R_att      (high inductance → slow response)
        τ_repel   = L_rep / R_rep      (low inductance → fast response)

    These are the same physical coil pair, switched between two operating
    modes. The asymmetry arises from three simultaneous differences in drive
    strategy:

    (a)  Different applied voltages: V_attract >> V_repel — the attraction
         phase receives a higher drive voltage, forcing current to rise faster
         and to a higher peak value.

    (b)  Different on-times: t_attract vs t_repel within each cycle — the
         attraction phase is held longer, allowing the magnetic force to
         integrate over a greater duration.

    (c)  Different freewheeling paths: the repel phase uses a fast diode catch
         circuit to collapse the magnetic field rapidly, while the attract
         phase permits a slower decay that sustains force longer.

    The instantaneous current in each coil follows the standard RL circuit
    response during the active phase:

        Rise (coil energized):  i(t) = V/R · (1 − e^{−t/τ})
        Decay (coil de-energized):  i(t) = I₀ · e^{−t/τ_freewheel}

    And the instantaneous magnetic force on the reaction mass is:

        F(t) = ½ · i(t)² · dL/dx

    where dL/dx is the spatial gradient of inductance — the rate at which
    the coil's inductance changes as the reaction mass moves through the gap.
    This gradient is a purely geometric property determined by coil geometry,
    core material, the shape of the reaction mass, and the air gap distance.

1.2.2  Net Impulse Per Cycle

    The reaction mass oscillates between the two coils. During each complete
    cycle (attract + repel), the net momentum delivered to the mass is the
    difference between the attraction and repulsion impulses:

        I_att = ∫₀^{t_att} F_att(t) dt
        I_rep = ∫₀^{t_rep} F_rep(t) dt
        I_net = I_att − I_rep

    The net thrust produced by one oscillator pair is the cycle frequency
    times this net impulse:

        F_thrust = f · I_net

    For a six-oscillator array arranged orthogonally (three axes, two
    opposing pairs per axis), the thrust vectors sum to produce the total
    force on the vehicle:

        F_total = Σ F_osc_i
        τ_total = Σ (r_i × F_osc_i)

    where r_i is the position vector of each oscillator relative to the
    vehicle center of mass, and τ_total is the total torque. This gives
    full 6-DOF control authority.

1.2.3  Asymmetry Ratio η_repel

    The asymmetry ratio quantifies how "unbalanced" each cycle is:

        η_repel = I_rep / I_att

    Physical range: η_repel ∈ [0.05, 0.50]

    •  η_repel < 0.15: High thrust per cycle, but oscillation amplitude
       grows rapidly and becomes difficult to control
    •  η_repel > 0.30: Lower thrust per cycle, but oscillation is smoother
       and more controllable — the system behaves more linearly
    •  η_repel ≈ 0.20: Recommended baseline — balances thrust output
       against controllability

    The net thrust fraction of the ideal oscillator is:

        ξ = (1 − η_repel)

    At η_repel = 0.20, ξ = 0.80 — the oscillator delivers 80% of the
    thrust it would produce if the repel phase contributed nothing.

    The optimum η_repel for hover depends on total system mass, available
    bus voltage, coil resistance, and the energy budget for simultaneous
    generation. A gain-scheduled lookup table adjusts η_repel in real time:

        η_repel = f(m_total, G_load, battery_SOC, altitude)

1.2.4  Parametric Resonance (2ω₀ Pump)

    The oscillation can be parametrically pumped by modulating the effective
    coil stiffness at exactly twice the mechanical resonance frequency.
    The equation of motion with parametric modulation is:

        m · ẍ + (k₀ + k_pump · sin(2ω₀ · t)) · x = 0

    where:
      m      = reaction mass (kg)
      k₀     = baseline magnetic stiffness (N/m)
      k_pump = modulation depth of stiffness (N/m)
      ω₀     = 2πf = natural oscillation frequency (rad/s)

    The power delivered to the oscillation by the parametric pump is:

        P_pump = ¼ · k₀ · h · ω₀ · z₀²

    where h = k_pump / k₀ (dimensionless modulation depth) and z₀ is the
    oscillation half-amplitude.

    The phase relationship between the modulation and the oscillation
    determines energy flow direction:

        φ = +π/2 → pump energy INTO oscillation (thruster mode)
        φ = −π/2 → extract energy FROM oscillation (generator mode)

    This is the same physical principle as a child pumping a swing — the
    swing's natural frequency is fixed by its chain length, and by
    shifting body position at the right moment (2× the swing frequency),
    the child amplifies the swing amplitude. In PEAT, the coil stiffness
    is modulated electronically rather than mechanically.

    The parametric pump does NOT change the energy balance of the system.
    It is merely the mechanism by which electrical energy is converted into
    mechanical oscillation energy. The pump power P_pump represents only
    the mechanical power delivered to the oscillation — the total electrical
    input is dominated by I²R copper losses in the coils, which are
    typically 20–40× larger than P_pump for copper-wound electromagnets at
    the force densities required for human-scale levitation.


───────────────────────────────────────────────────────────────────────────────

1.3  What PEAT Is NOT
───────────────────────────────────────────────────────────────────────────────

    It is essential to state clearly what PEAT does NOT claim, because the
    principles involved (oscillating electromagnetic fields, parametric
    resonance, simultaneous generation) are often associated with
    pseudoscientific or over-unity claims. PEAT explicitly rejects these.

1.3.1  Not Perpetual Motion

    PEAT does not claim to produce continuous motion without an energy
    source. The oscillating reaction mass requires continuous electrical
    power to sustain its motion against:
      • I²R resistive losses in the coils (dominant term)
      • Mechanical damping from the pickup coil load
      • Eddy current losses in conductive structures
      • Bearing/centering losses in the magnetic suspension
      • The work of thrust itself (F_thrust · dx per cycle)

    The energy flow is strictly:

        E_pump_in + E_battery → E_osc + E_thrust + E_pickup + E_loss

    Every joule delivered to the system must come from an external source.
    There is no "self-sustaining" loop. The AEQUIGEN-SS auxiliary generator
    is a separate device that burns fuel or extracts energy from the
    environment — it is not a closed cycle.

1.3.2  Not Over-Unity

    The ratio of useful output (thrust work + recovered electrical power) to
    total electrical input is strictly less than unity:

        η_total_system = (E_thrust + E_pickup) / E_total_input < 1

    Numerical simulation of the 115 kg human-scale baseline at 48V bus
    voltage and 1 Ω coil resistance yields:

        η_total_system ≈ 5.1%

    This means 94.9% of input electrical power is dissipated as heat in
    the coils. This is not a design deficiency — it is the physics of
    creating ~1000 N magnetic forces with copper electromagnets at low
    voltage. The force per ampere is set by dL/dx, which is geometry-
    limited. I²R losses are quadratic in required current.

    Improvements are available (800V SiC bus, Litz wire, iron-cored coils)
    and can push efficiency toward 15–30%, but the system fundamentally
    obeys energy conservation.

1.3.3  Not Free Energy

    No energy is extracted from the vacuum, from quantum fluctuations, or
    from any exotic source. All energy comes from:
      • The electrical power bus (batteries, generator, or grid tether)
      • The auxiliary AEQUIGEN-SS generator (combustion or turbine)
      • Regenerative recovery during descent (gravitational potential → electrical)

    The simultaneous generation from pickup coils does not multiply energy.
    Every watt recovered by the pickup coils is a watt that was already
    invested into the magnetic field by the pump coils, minus conversion
    losses. The pickup and pump coils are separate windings on the same
    magnetic circuit — the same flux that produces thrust is being tapped
    for generation. The energy is split, not multiplied.

        E_pump_in = E_thrust + E_pickup_recovered + E_loss

    If E_pickup_recovered increases, either E_thrust must decrease or
    E_pump_in must increase. There is no free lunch.

1.3.4  Not a Reactionless Drive

    PEAT does not violate Newton's third law. The reaction mass is a real,
    physical object with inertia. Every impulse delivered to the vehicle
    frame is matched by an equal and opposite impulse delivered to the
    reaction mass. The net momentum of the total system (vehicle + reaction
    mass) is conserved.

    What makes PEAT useful is that the reaction mass oscillates internally,
    so the vehicle experiences a net force in one direction while the
    reaction mass experiences an oscillatory motion that averages to zero
    displacement over many cycles. This is the same principle as an
    internal combustion engine's piston: the piston oscillates, but the
    crankshaft delivers net torque to the wheels.

    The momentum balance per cycle:

        Δp_vehicle = −Δp_reaction_mass

    Over one full cycle, the reaction mass returns to its starting position
    (approximately, minus the slight drift that constitutes thrust), while
    the vehicle has gained net downward (lift) momentum.


───────────────────────────────────────────────────────────────────────────────

1.4  Design Constraints — The EFE Filter
───────────────────────────────────────────────────────────────────────────────

    The EFE (Equidistributed Free Economy) Filter is a set of seven
    non-negotiable design principles that every component, material choice,
    and manufacturing decision in PEAT must satisfy. These principles
    reflect the framework's commitment to sustainable, equitable, and open
    engineering — not as an afterthought but as a design constraint on
    equal footing with physics and performance.

1.4.1  The Seven Principles

    SUSTAINABLE:
        Every material shall be renewable, recycled, or indefinitely
        cyclable. Virgin fossil-fuel plastics, conflict minerals, and
        materials requiring destructive extraction are prohibited.

    RENEWABLE:
        Production energy shall come only from renewable sources — direct
        solar/wind at the production site, grid renewable with verified
        sourcing, or stored renewable (batteries, hydrogen from
        electrolysis).

    ACCESSIBLE:
        The design and its manufactured products shall be producible and
        distributable equitably worldwide. No single point of failure in
        the supply chain. Local production capability in any region.

    OPEN:
        Zero patent barriers. Full documentation publicly available.
        Compatible with open-source licensing. The PEAT framework is
        published under CC0 1.0 Universal (Public Domain).

    LOCAL-FIRST:
        Manufacturing shall maximize local sourcing of materials and
        components. Regional supply chains preferred over global ones.
        Minimum local sourcing target: 70% by mass for regional production.

    CIRCULAR:
        End-of-life material recovery shall meet or exceed 95% by mass.
        All materials must have a known recycling or composting pathway.
        Packaging shall be fully recyclable.

    DURABLE:
        Design life shall be 20+ years minimum (excluding consumables
        such as bearings and capacitors). Repair and upgrade capability
        with common tools. Spare parts locally available.

    If any principle is violated, the design must be revised until it
    passes. The EFE Filter is a GO/NO-GO gate, not a scoring rubric.

1.4.2  Material Hierarchy

    Materials are ranked by EFE compatibility tier:

    PREFERRED (Tier 1):
        Grown materials (bamboo, mycelium, hemp, algae, bacterial cellulose)
        Agricultural waste streams (flax, hemp hurd, rice hulls, straw)
        Recycled metals (steel, aluminum from existing scrap)
        Sustainably harvested wood (FSC/PEFC certified)
        Bio-derived synthetics (PLA, bio-TPU, plant-oil resins)

    ACCEPTABLE (Tier 2, with justification):
        Conventional materials with proven recycling pathways
        Rare materials recovered from e-waste or industrial waste
        High-performance alloys necessary for safety-critical components
        where no sustainable alternative exists

    PROHIBITED (Tier 3–4):
        Virgin fossil-fuel plastics
        Conflict minerals
        Materials requiring destructive extraction
        Patented proprietary compounds

    For PEAT, this constrains coil wire to recycled copper or aluminum,
    core materials to ferrite (abundant, recyclable) or iron from recycled
    sources, structural elements to recycled aluminum or bamboo composites,
    and permanent magnets to recycled NdFeB or ferrite (avoiding virgin
    rare-earth mining).

1.4.3  Energy Hierarchy

    PRODUCTION ENERGY:
        1. Direct solar/wind at production site
        2. Grid renewable (verified source)
        3. Stored renewable (batteries, hydrogen from electrolysis)
        4. Grid unknown (tolerated temporarily with mitigation plan)

    OPERATION ENERGY (for PEAT vehicles):
        The thrust and levitation system requires electrical power during
        operation. This power is supplied by:
        • Batteries charged from renewable sources
        • Onboard generator (AEQUIGEN-SS) running on renewable fuel
        • Tethered power from renewable grid
        • Regenerative capture during descent

1.4.4  Application in PEAT

    The EFE Filter applies at every level:

    •  Coil design: recycled copper wire vs virgin, ferrite vs rare-earth
       cores, potting compounds (bio-resin vs epoxy)

    •  Structural frame: recycled aluminum extrusion vs carbon fiber
       (carbon fiber fails the circularity principle — difficult to recycle)

    •  Reaction mass: recycled steel or sintered iron vs tungsten or lead

    •  Electronics: RoHS-compliant components, lead-free solder,
       conflict-mineral-free supply chain

    •  Documentation: all designs and specifications are public domain;
       no proprietary formats, no NDAs, no patent filings

    The EFE Filter is checked at every phase of the OPTIBEST process and
    must be re-verified after every enhancement cycle to ensure no
    regression.


───────────────────────────────────────────────────────────────────────────────

1.5  The OPTIBEST Premium Framework
───────────────────────────────────────────────────────────────────────────────

    OPTIBEST is the meta-framework under which PEAT is developed. It is a
    systematic methodology for achieving undeniably optimal solutions
    through iterative refinement, multi-dimensional evaluation, and platea-
    u verification. The framework is agnostic to domain — it applies to
    engineering, software, writing, and any purposeful creation — but is
    applied here to the specific problem of electromagnetic levitation.

1.5.1  Definition of PREMIUM

    Within the OPTIBEST framework, PREMIUM is defined as:

    > The undeniable, verifiable state of systematic optimality for
    > intended purpose — achieved when a solution demonstrates excellence
    > across all purpose-relevant dimensions, refined through genuine
    > iteration until enhancement plateau, and confirmed through rigorous
    > multi-method verification.

    This definition is:
    •  Universal: applies to any domain, any purpose, any context
    •  Objective: relative to stated purpose, not subjective preference
    •  Verifiable: can be proven through specified methods
    •  Achievable: provides a clear pathway through the OPTIBEST framework
    •  Undeniable: once verified, the result cannot be disputed

1.5.2  The Seven Dimensions

    Every PREMIUM solution demonstrates excellence across seven dimensions,
    weighted dynamically by purpose-relevance. For PEAT:

    ╔═══════════════╤════════════════════════════════════════╤══════════════════════╗
    ║  Dimension     │  PEAT-Specific Manifestation          │  Core Question       ║
    ╠═══════════════╪════════════════════════════════════════╪══════════════════════╣
    ║  FUNCTIONAL    │  Produces net thrust, achieves        │  Does it work,       ║
    ║                │  6-DOF control, maintains hover       │  fully?              ║
    ║                │  at all mass points                    │                      ║
    ║                │                                        │                      ║
    ║  EFFICIENCY    │  Minimizes I²R loss, optimizes        │  Is nothing          ║
    ║                │  η_repel for energy/thrust tradeoff,   │  wasted?             ║
    ║                │  maximizes pickup recovery fraction    │                      ║
    ║                │                                        │                      ║
    ║  ROBUSTNESS    │  Graceful failure modes, passive      │  Does it             ║
    ║                │  return-to-center, redundant sensors,  │  endure?             ║
    ║                │  control loop stability margins        │                      ║
    ║                │                                        │                      ║
    ║  SCALABILITY   │  Same architecture from 5 kg drone    │  Does it             ║
    ║                │  to 5,500 kg hoverbus, parametric      │  scale?              ║
    ║                │  scaling laws, modular unit design     │                      ║
    ║                │                                        │                      ║
    ║  MAINTAIN-     │  Clear ODF documentation, modular      │  Can it              ║
    ║  ABILITY       │  components, accessible calibration,   │  evolve?             ║
    ║                │  self-diagnosing sensor array          │                      ║
    ║                │                                        │                      ║
    ║  INNOVATION    │  Asymmetric push-pull EM thrust,      │  Does it             ║
    ║                │  parametric 2ω₀ pumping, simultaneous  │  advance?            ║
    ║                │  generation from levitation field      │                      ║
    ║                │                                        │                      ║
    ║  ELEGANCE      │  Minimum complexity for required       │  Is it               ║
    ║                │  function, clean equations, simple     │  irreducibly         ║
    ║                │  control law, physical clarity         │  simple?             ║
    ╚═══════════════╧════════════════════════════════════════╧══════════════════════╝

    Elegance is defined precisely as:

        Elegance = Purpose Achievement / Complexity Required

    This is objective: a simpler solution that achieves the same purpose
    is more elegant. An over-engineered solution that introduces complexity
    without corresponding purpose-achievement is less elegant.

1.5.3  The Nine Phases

    The OPTIBEST development process for PEAT follows nine phases:

    Phase 0 — CALIBRATION
        Determine task magnitude (MACRO for PEAT: new flight paradigm,
        safety-critical, multi-domain), rigor level (FULL: foundational
        physics requiring irreversible design decisions), and deployment
        scale (GLOBAL: drone to hoverbus, all human flight scales).

    Phase 1 — PURPOSE CRYSTALLIZATION
        Define the one-sentence purpose: "Build a framework for
        electromagnetic levitation that produces net thrust via asymmetric
        inductance modulation, achieves full 6-DOF control, and
        simultaneously generates electrical power, across six mass classes
        from 5 kg to 5,500 kg."

    Phase 2 — CONSTRAINT MAPPING
        Identify constraints and classify by type:
        •  Immutable: Maxwell's equations, conservation laws, Lenz's law
        •  Practical: copper resistivity, PWM frequency limits, sensor noise
        •  Assumed: 48V bus (baseline), 1 Ω coil resistance, standard
           NdFeB permanent magnets
        Liberation zones: asymmetry ratio η_repel, parametric pump phase,
        coil geometry, control law design

    Phase 3 — MULTIDIMENSIONAL CONCEPTION
        Generate solutions exploring all seven dimensions. Minimum three
        mechanistically distinct concepts (not three variants of the same
        idea). For PEAT:
        •  Mechanism A: Pure EM asymmetry (selected — primary approach)
        •  Mechanism B: Parametric resonant + magnetic impact drive
        •  Hybrid: Asymmetric EM with superconducting assist

    Phase 4 — HIERARCHICAL EVALUATION
        Assess each concept at MACRO (strategic feasibility), MESO
        (system architecture), and MICRO (component-level physics) levels.
        Verify cross-scale coherence — a concept that works at the
        component level but fails at the system level is rejected.

    Phase 5 — SYSTEMATIC GAP DETECTION
        Apply adversarial analysis, comparative analysis between concepts,
        blind spot scanning, and purpose alignment verification. Gaps are
        prioritized by impact on the core premise. For PEAT, the critical
        gap identified: I²R losses in copper coils dominate the energy
        budget by a factor of 20–40× over mechanical oscillation power.

    Phase 6 — TARGETED ENHANCEMENT
        For each significant gap: understand root cause, generate multiple
        solutions, select optimal enhancement, and synthesize into the
        improved solution. Example enhancement vectors for PEAT:
        higher bus voltage, Litz wire, iron-cored coils, optimized pulse
        shaping, cryogenic cooling.

    Phase 7 — RECURSIVE ITERATION
        Return to Phase 3 with the enhanced solution. Measure enhancement
        delta (Δ) each cycle. Iterate until Δ approaches zero — no further
        improvement is possible within current constraints.

    Phase 8 — PLATEAU VERIFICATION
        Confirm that the solution has reached an optimization plateau
        through five independent methods (see §1.5.4).

    Phase 9 — OPTIBEST DECLARATION
        Document the solution, dimensional analysis, optimization journey,
        and known limitations. Declare PREMIUM achievement with evidence.
        PEAT_MASTER.md and the levitation_framework.md hold this
        certification.

1.5.4  The Five Verification Methods

    Method 1 — MULTI-ATTEMPT ENHANCEMENT SEEKING
        Make 3+ serious, documented attempts to find further improvements.
        If none succeeds, the plateau claim is provisionally accepted.

    Method 2 — INDEPENDENT PERSPECTIVE SIMULATION
        Evaluate the solution from four distinct perspectives:
        •  Expert: domain specialist evaluating technical correctness
        •  User: end-user evaluating usability and practicality
        •  Maintainer: technician evaluating serviceability
        •  Adversary: hostile evaluator seeking flaws

    Method 3 — ALTERNATIVE ARCHITECTURE COMPARISON
        Build a mechanistically distinct alternative and demonstrate that
        the primary solution is superior on balance across the seven
        dimensions.

    Method 4 — THEORETICAL LIMIT ANALYSIS
        Identify immutable constraints (physics, materials, mathematics)
        and verify that all remaining gaps are explained by these
        constraints, not solvable within the current framework.

    Method 5 — FRESH PERSPECTIVE RE-EVALUATION
        Return to the solution after a period of disengagement (or engage
        a fresh evaluator) and confirm no improvements are identified.

1.5.5  Tiered Verification Protocol

        Task Magnitude   │ Verification Required
        ─────────────────┼────────────────────────────────────────
        MACRO            │ All 5 methods, maximum rigor
        MESO             │ Methods 1, 2, and 4 (abbreviated)
        MICRO            │ Method 1 (abbreviated) + quick perspective check


───────────────────────────────────────────────────────────────────────────────

1.6  Scope
───────────────────────────────────────────────────────────────────────────────

1.6.1  Mass Range

    PEAT defines six mass classes, each with a parametric vehicle design.
    The framework provides scaling laws that link all parameters across
    classes:

    Parameter              │ Drone   │ Courier │ Human    │ Hoverbike│ Hovercar │ Hoverbus
    ───────────────────────┼─────────┼─────────┼──────────┼──────────┼──────────┼──────────
    Total mass (kg)        │ 5       │ 50      │ 115      │ 250      │ 1200     │ 5500
    Reaction mass (kg)     │ 0.75    │ 7.5     │ 15       │ 35       │ 150      │ 750
    Frequency (Hz)         │ 30      │ 20      │ 15       │ 12       │ 10       │ 8
    Half-amplitude (m)     │ 0.02    │ 0.035   │ 0.05     │ 0.065    │ 0.085    │ 0.12
    Stroke (m)             │ 0.04    │ 0.07    │ 0.10     │ 0.13     │ 0.17     │ 0.24
    Thrust needed (N)      │ 49      │ 491     │ 1128     │ 2453     │ 11772    │ 53955
    η_repel (hover)        │ 0.57    │ 0.53    │ 0.47     │ 0.45     │ 0.42     │ 0.38
    Total elec. input (kW) │ ~1.1    │ ~4.0    │ ~101     │ ~8.0     │ ~29      │ ~95
    System volume (L)      │ 2       │ 15      │ 35       │ 75       │ 350      │ 2800

    The framework is designed to be scale-agnostic: the oscillator
    topology, control architecture, sensor array design, and energy
    balance equations are identical across all six classes. Only the
    physical dimensions, component ratings, and operating frequencies
    change. This is the scalability principle in practice.

1.6.2  Degrees of Freedom

    PEAT provides independent control of all six rigid-body degrees of
    freedom simultaneously:

    TRANSLATION:
        X — lateral (left/right)
        Y — longitudinal (forward/back)
        Z — vertical (lift/descent)

    ROTATION:
        Pitch — rotation about X axis
        Roll  — rotation about Y axis
        Yaw   — rotation about Z axis

    Each DOF is controlled by differential force allocation across the
    six-oscillator array. The force allocation is computed via:

        F_total = A × i
        i = A⁺ × F_desired

    where A is the 6×N actuation matrix (geometry-dependent mapping from
    coil currents to forces and torques), and A⁺ is its Moore-Penrose
    pseudoinverse. For the six-oscillator baseline (N=6), A is square
    and invertible. For redundant configurations (N > 6), the null space
    enables optimization of coil currents for minimum I²R loss.

    The six oscillators are arranged in three orthogonal pairs:
        Z+/Z−  : primary lift + yaw authority
        X+/X−  : longitudinal thrust + roll authority
        Y+/Y−  : lateral thrust + pitch authority

1.6.3  Simultaneous Power Generation

    Each oscillator pair includes three electrically independent coil sets
    sharing the same magnetic circuit:

    (a)  PUMP COILS (motor mode) — driven at 2ω₀ parametric frequency,
         deliver energy to sustain oscillation amplitude against losses
         and thrust extraction.

    (b)  PICKUP COILS (generator mode) — extract energy from the
         oscillating magnetic field, fed through MPPT rectifier to the
         power bus.

    (c)  SUSPENSION COILS (magnetic bearing mode) — maintain the reaction
         mass centered and pre-loaded against gravity.

    The energy flow per oscillator:

        E_pump_in ──→ oscillation energy E_osc
                        ├──→ E_thrust  (net momentum to frame)
                        ├──→ E_pickup  (recovered electrical energy)
                        ├──→ E_loss    (copper, eddy current, bearing)
                        └──→ E_remain  (sustains oscillation)

    Critical note: pickup recovery is modest — approximately 0.06% of
    total electrical input at the 48V baseline, with a practical upper
    bound of 5–10% even after optimization. The simultaneous generation
    capacity offsets control electronics power but cannot significantly
    reduce the net electrical input requirement. The auxiliary AEQUIGEN-SS
    generator supplies the bulk of system power.


───────────────────────────────────────────────────────────────────────────────

1.7  Non-Goals
───────────────────────────────────────────────────────────────────────────────

    The following are explicitly outside PEAT's scope. They are not design
    objectives, not claimed capabilities, and not addressed by the
    framework:

    AERODYNAMIC LIFT
        PEAT produces thrust purely through electromagnetic interaction.
        There are no wings, rotors, ducts, or aerodynamic surfaces
        designed to produce lift. PEAT vehicles are drag bodies that must
        overcome their own aerodynamic drag through thruster power.
        Maximum forward velocity is limited by the thrust available from
        the X-axis oscillators minus aerodynamic drag — not by stall
        speed or lift-to-drag ratio.

    REACTIONLESS DRIVE
        PEAT does not violate Newton's third law. The internal reaction
        mass carries momentum equal and opposite to the vehicle momentum
        at all times. The system is momentum-conserving internally;
        external momentum exchange with the environment (ground effect,
        induced airflow) is incidental and not relied upon.

    ZERO-POINT ENERGY / VACUUM ENERGY
        No energy is extracted from quantum vacuum fluctuations, zero-
        point fields, or any exotic physics. All energy in the PEAT system
        originates from conventional electrical sources (batteries,
        generators, grid).

    ANTIGRAVITY / GRAVITY SHIELDING
        The framework does not modify, shield, cancel, or otherwise
        interact with the gravitational field itself. Gravity is
        counteracted by producing an upward electromagnetic force on the
        vehicle — not by reducing or redirecting the gravitational
        attraction between the vehicle and the Earth.

    COLD FUSION / ANOMALOUS HEAT
        No nuclear reactions of any kind occur within the PEAT system.
        No claims are made regarding excess heat, low-energy nuclear
        reactions, or any form of unconventional energy release.

    SPACE PROPULSION (PRIMARY)
        PEAT is designed for operation within planetary atmospheres and
        gravitational fields. The reaction mass requires a restoring force
        (magnetic centering or gravity) to maintain oscillation. In
        free-fall or vacuum, the oscillators drift apart without external
        confinement. A variant for microgravity would require fundamental
        redesign of the magnetic bearing system. This is not addressed in
        the current framework.

    PERPETUAL MOTION MACHINES
        The framework does not claim, imply, or approach perpetual
        operation without an external energy source. Continuous power
        input is required for continuous operation.


───────────────────────────────────────────────────────────────────────────────

1.8  Terminology & Glossary
───────────────────────────────────────────────────────────────────────────────

    Terms are defined here as they are used within the PEAT framework.
    Some terms may have broader meanings in other contexts; the PEAT-
    specific definition is authoritative within this documentation.

    ┌─ GLOSSARY OF TERMS ────────────────────────────────────────────────────────
    │
    │  AEQUIGEN-SS         Auxiliary self-starting generator (AFPM axial flux
    │                      permanent magnet type) that supplies net system power
    │                      not covered by pickup recovery.
    │
    │  Asymmetry Ratio     η_repel = I_rep / I_att. A measure of how
    │    (η_repel)         unbalanced the attraction and repulsion impulses are
    │                      in each cycle. η=0: pure attraction; η=1: symmetric.
    │                      PEAT operating range: 0.05–0.50.
    │
    │  dL/dx               Spatial gradient of inductance with respect to
    │                      reaction mass position. A geometric property that
    │                      determines force per ampere squared.
    │
    │  DOF                 Degree of Freedom. PEAT controls 6: X, Y, Z
    │                      translation + pitch, roll, yaw rotation.
    │
    │  EFE                 Equidistributed Free Economy. An economic and design
    │                      philosophy emphasizing sustainability, local
    │                      production, open knowledge, and circular material
    │                      flows. The EFE Filter guides PEAT's design
    │                      constraints.
    │
    │  Halbach Array       A specific arrangement of permanent magnets that
    │                      concentrates magnetic field on one side while
    │                      cancelling it on the other. Used in the levitation
    │                      framework (Chapter 7) to improve force per ampere.
    │
    │  I²R Loss            Resistive (copper) loss in coil windings. The
    │                      dominant energy dissipation term in PEAT, typically
    │                      95–99% of total electrical input.
    │
    │  Mechanism A         The primary PEAT approach: pure electromagnetic
    │                      asymmetry using two coils with different time
    │                      constants to produce net thrust per cycle.
    │
    │  MPPT                Maximum Power Point Tracking. A control technique
    │                      that adjusts the electrical load on the pickup coils
    │                      to extract maximum power from the oscillating
    │                      magnetic field.
    │
    │  ODF                 OPTIBEST Document Format. The standard format for
    │                      all PEAT documentation, using box-drawing Unicode
    │                      characters, structured sections, and consistent
    │                      visual grammar. Defined in the OPTIBEST skill
    │                      specification.
    │
    │  OPTIBEST            The meta-framework for achieving verifiably optimal
    │                      solutions through 7 dimensions, 9 phases, and 5
    │                      verification methods. PEAT is developed within this
    │                      framework.
    │
    │  Oscillator Pair     The fundamental PEAT unit: two electromagnets on a
    │                      common axis with a reaction mass suspended between
    │                      them. One pair produces one axis of thrust.
    │
    │  Parametric Pump     Energy injection into an oscillator by modulating a
    │                      system parameter (here: magnetic stiffness) at
    │                      exactly twice the natural frequency (2ω₀).
    │
    │  Pickup Coil         A secondary winding on the oscillator's magnetic
    │                      circuit that converts magnetic flux variation into
    │                      electrical current for recovery.
    │
    │  PLL                 Phase-Locked Loop. A control system that generates
    │                      a signal whose phase tracks the phase of an input
    │                      signal. Used in PEAT to synchronize the parametric
    │                      pump with the mechanical oscillation.
    │
    │  PM                  Permanent Magnet. Provides a bias magnetic field
    │                      that improves force per ampere in the levitation
    │                      framework.
    │
    │  Pump Coil           The primary winding that receives electrical power
    │                      and creates the magnetic field that drives the
    │                      reaction mass oscillation.
    │
    │  Reaction Mass       A physical mass (typically 10–15% of vehicle
    │                      weight) that oscillates between two coils. Its
    │                      inertia provides the reaction force for thrust.
    │
    │  Simultaneous        The capability of the pickup coils to generate
    │  Generation          electrical power from the same oscillating magnetic
    │                      field that produces thrust, without requiring a
    │                      separate mechanical generator.
    │
    │  Six-Oscillator      The minimum configuration for full 6-DOF control:
    │  Array               3 orthogonal axes × 2 opposing pairs per axis = 6
    │                      oscillator units.
    │
    │  Stroke              2 × z₀ = total travel of the reaction mass
    │                      between the two coils (peak-to-peak amplitude).
    │
    │  2ω₀                 Twice the natural oscillation frequency. The
    │                      frequency at which the parametric pump must
    │                      modulate coil stiffness for energy injection.
    │
    └────────────────────────────────────────────────────────────────────────────


───────────────────────────────────────────────────────────────────────────────

1.9  Document Conventions
───────────────────────────────────────────────────────────────────────────────

    All PEAT documentation follows the OPTIBEST Document Format (ODF)
    specification. The following conventions are used throughout:

    Document Structure:
        ═══  double-line boundary — top-level document frame
        ───  single-line boundary — section divider within a document
        ##   numbered subsection headers within a section
        ┌─   labeled content block — self-contained information

    Typographic Conventions:
        Physical variables are set in italic in mathematical notation:
            F(t), i(t), τ = L/R, η_repel
        Vector quantities are indicated by bold or explicit notation:
            F_total, τ_total
        Numerical values include units with standard SI symbols:
            5 kg, 15 Hz, 48 V, 1 Ω, 100.7 kW
        Greek letters for framework-specific parameters:
            η_repel (asymmetry ratio), ξ (thrust fraction),
            τ (time constant), ω₀ (natural frequency), φ (phase angle)

    Mathematical Notation:
        Equations are inline within paragraphs for simple expressions
        or displayed in code blocks for complex derivations.
        Derivatives: ẋ = dx/dt, ẍ = d²x/dt²
        Integrals: ∫₀^{t} F(τ) dτ
        Summations: Σ F_osc_i

    Alert System:
        ┌─ ℹ INFO ────────────────────────────────────────────────────
        │  Supplementary information that aids understanding.
        └─────────────────────────────────────────────────────────────

        ┌─ ⚠ WARNING ─────────────────────────────────────────────────
        │  Important caution that could affect design decisions or
        │  interpretation of results if ignored.
        └─────────────────────────────────────────────────────────────

        ┌─ ✓ VERIFIED ────────────────────────────────────────────────
        │  Confirmed result backed by simulation or analysis.
        └─────────────────────────────────────────────────────────────

    Cross-References:
        Internal references use the format:
            [§1.2] — section within the same chapter
            [CH02, §2.1] — section in another chapter
            [PEAT_MASTER, §4] — reference to the master document
            [LEV_FW, §3.2] — reference to the levitation framework

    Verification Status:
        ☑  Verified (confirmed by simulation, analysis, or test)
        ☐  Pending (identified target, not yet verified)
        ✓  Pass (specific check successful)
        ✗  Fail (specific check failed or not met)

    Units:
        All quantities use SI base units unless explicitly noted.
        Common derived units used throughout:
            N (force), J (energy), W (power), Pa (pressure),
            T (magnetic flux density), H (inductance), Ω (resistance),
            Hz (frequency), rad/s (angular frequency)

    Numerical Precision:
        Values from analytical models are given to 2–3 significant figures.
        Values from numerical ODE simulation are given to 3–4 significant
        figures. Design parameters (masses, dimensions) are given to 2
        significant figures as they represent nominal targets, not exact
        specifications.


───────────────────────────────────────────────────────────────────────────────

1.10  Relationship to Other Chapters
───────────────────────────────────────────────────────────────────────────────

    This chapter (Foundations & Premise) establishes the conceptual and
    philosophical basis for the PEAT framework. Subsequent chapters build
    on this foundation:

    CHAPTER 2 — CORE PHYSICS
        Derives the electromagnetic theory: coil inductance, force
        equations, parametric resonance mathematics, and the energy
        balance equations from first principles. Requires understanding
        of η_repel (§1.2.3) and Mechanism A (§1.2.1).

    CHAPTER 3 — SYSTEM ARCHITECTURE
        Defines the six-oscillator array topology, three-coil-set design
        per oscillator, sensor array (18 Hall + 1 IMU), and the three-
        loop calibration controller. Builds on the 6-DOF scope (§1.6.2).

    CHAPTER 4 — OSCILLATOR DESIGN
        Detailed coil design: wire gauge, turns count, core geometry,
        dL/dx optimization, thermal management. Relies on the time
        constant analysis from §1.2.1.

    CHAPTER 5 — ENERGY BALANCE
        Full power flow analysis: pump power, I²R losses, thrust work,
        pickup recovery, generator deadband. Extends the energy flow
        diagram from §1.6.3 with numerical validation.

    CHAPTER 6 — CONTROL & CALIBRATION
        PID control per DOF, force allocation pseudoinverse, Kalman
        PLL, gain scheduling, MPPT pickup control. Implements the
        η_repel scheduling introduced in §1.2.3.

    CHAPTER 7 — 6-DOF LEVITATION FRAMEWORK
        The full calibrated-electromagnetic levitation system with PM
        bias, Halbach arrays, and AFPM generator integration.
        Complements the pure-asymmetry approach of Mechanism A.

    CHAPTER 8 — USE-CASE SCALING
        Detailed parametric designs for all six mass classes. Expands
        the scaling table from §1.6.1 into complete vehicle blueprints.

    CHAPTER 9 — SIMULATION SUITE
        Documentation of the three simulation codebases: Julia single-
        oscillator ODE (peat_sim), Julia 6-DOF levitation (sim), and
        Python analytical sweeps (simulation).

    CHAPTER 10 — VERIFICATION & VALIDATION
        Comprehensive test results: analytical sweep (10,260 configs),
        numerical ODE (71 tests, all passing), 6-DOF lateral divergence
        fix, cross-method verification.

    CHAPTER 11 — COMPLIANCE & LICENSING
        EFE Filter compliance documentation, CC0 licensing, regulatory
        considerations, safety framework.

    CHAPTER 12 — ROADMAP
        Priority-ordered development pathway: 6-DOF ODE verification,
        optimized coil design (800V SiC), calibration controller,
        system-level efficiency optimization.

    CHAPTER 13 — COMPLETE REFERENCE
        Consolidated parameter reference, equation index, cross-reference
        matrix, symbol table.


───────────────────────────────────────────────────────────────────────────────
REFERENCES
───────────────────────────────────────────────────────────────────────────────

    [1]  PEAT_MASTER.md — Master Framework Document v1.1. Repository root.
         Defines Core Physics, System Architecture, Energy Balance,
         Verification Targets, and all use-case scaling.

    [2]  FRAMEWORK/levitation_framework.md — Calibrated Electromagnetics
         6-Axis Levitation Framework v1.1. Defines PM-biased levitation,
         Halbach arrays, AFPM generator integration, and the 6-DOF
         control topology.

    [3]  SIMULATION/README.md — Simulation Suite Index. Documents the
         three simulation tracks with track comparison and key findings.

    [4]  OPTIBEST Premium Manifesto — The canonical definition of PREMIUM,
         the seven dimensions, nine phases, and five verification methods.
         Incorporated by reference into the PEAT development process.

    [5]  EFE Engineering Methodology — The EFE Filter principles, material
         hierarchy, energy hierarchy, and design methodology. Applied as
         non-negotiable design constraints throughout the PEAT framework.

    [6]  PEAT_MASTER.md, §2 — Mechanism A: Asymmetric Inductance
         Modulation. Complete mathematical derivation of the core physics
         including the parametric resonance equations.

    [7]  PEAT_MASTER.md, §5 — Energy Balance. Detailed power flow
         analysis with numerical simulation results, including the
         critical distinction between parametric pump power and total
         electrical input.

    [8]  PEAT_MASTER.md, §10 — Key Physics Insights. The efficiency
         challenge, lever analysis, pickup coupling limits, and the
         realistic value proposition of Mechanism A.


════════════════════════════════════════════════════════════════════════════════
                         END OF CHAPTER 1
               PEAT — Pure Electromagnetic Asymmetric Thrust
                    Foundations & Premise │ v1.1
════════════════════════════════════════════════════════════════════════════════
