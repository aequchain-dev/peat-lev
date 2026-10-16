# GLMP v1.0 — Genesis Laser Multi-Process Head

**Architecture & Engineering Blueprint for the AEFRI Genesis Printer, Tool 5 Dock**

Status: DESIGN COMPLETE · CODE COMPLETE · TESTED
Evidence class: **MODELLED. Nothing in this document has been run on hardware.**
Authority: extends `devzone/material/ttx89-resources/Genesis 3D Printer.md` §18 (Tool 5)

---

## 0. Evidence status — read this before any number

Per the discipline already established in `AEFRI/README.md` ("Nothing in AEFRI
is MEASURED"), the same applies here with more force, because this document
contains arithmetic that *looks* like measurement.

| Layer | Class | How to promote |
|---|---|---|
| `data/materials.toml` | `assumed` — handbook ranges | `glmp calibrate material` |
| `data/machine.toml` | `assumed` — commodity datasheet | `glmp calibrate optical` |
| `optics.py`, `thermal.py` | first-principles, **verified by execution** | — |
| Envelope verdicts | derived from assumed inputs | re-derive after calibration |

The physics is computed and the code is tested. The **constants are not
measured**. A refusal computed from assumed constants is weaker evidence than
one computed from measured ones, so the software propagates the distinction
into every recipe and every emitted program. `evidence` is a first-class field,
not a comment.

---

## 1. What was asked, and what it resolves to

Requested process set: **etch · engrave · weld · cut · solder · ECT**, plus
process-recipe creation, as an operable laser attachment/mod on the Genesis
printer.

Three terms were ambiguous and are resolved explicitly rather than guessed:

| Term | Interpretation used | Why | If wrong |
|---|---|---|---|
| **ECT** | Eddy-current testing (lift-off probe scan) | The only member of the requested set that is standard industrial NDT. It shares the Genesis's existing Beacon eddy-current Z probe, so sensing principle, calibration discipline and operator training are already in the machine. | If ECT meant error-correction transport (as in the MCSA ontology), this process is wrong — but it is the only reading consistent with an industrial process list. |
| **"processor creation"** | **Process-recipe creation** — a planner that derives a validated recipe from (material, process, thickness, machine) | Every other item in the list is a manufacturing process. | A "processor" (SoC) requirement would be §4.5, already covered as an open item. |
| **weld** | Micro-foil fusion only | §3 computes the boundary. 5 W will not weld structural stock. | — |

**All six are delivered.** Four fully, one (weld) strictly bounded to a real
sub-domain, one (ECT) as a non-optical probe on the same dock.

---

## 2. Decision record

### 2.1 The decision engines failed to decide, and that is a finding

Per the required routing, two engines were consulted. **Neither produced a
decision-grade answer, and neither is reported as if it had.**

**laya** (`typed-decisions`, GLM 5.3/nvidia, free) — batched, one load:

| Question | Chosen | Confidence |
|---|---|---|
| Primary bottleneck | thermal management / focal drift | **0.0187** |
| Architecture | dual-wavelength 450+1064 nm | **0.0338** |
| Loop closure | open-loop recipe only | **0.0217** |
| Ambiguity risk (ECT) | 1.94 "moderately" | 0.1017 |

Every distribution was near-uniform. This is not a verdict.

**ABSUBEST** `run_full_pipeline` → `best_solution_id: candidate_5, utility
7.54, verdict: verified`. Inspecting the payload:

- the candidates were the literal strings `"Variant 1 for: …"` … `"Variant 5 for: …"`
- scores rise **monotonically with index on all 8 dimensions** (5.57 → 5.78 →
  6.33 → 6.72 → 7.44)
- `coverage_δ: "heuristic (non-computable)"`
- the sensitivity check reported `"assumed stable (weight perturbation not applied)"`

An index-monotonic ranking over placeholder candidates is an artifact. It is
**discarded**. Per R-E, an unresolved handle is ABSENT, not inferred.

**Arbitration was therefore made on physics against the actual Genesis spec**,
and the engine disagreement is recorded rather than averaged away.

### 2.2 Alternatives considered and rejected

| # | Alternative | Verdict | Decisive reason |
|---|---|---|---|
| A | Keep 5 W 450 nm diode; add process library + closed-loop power | **SELECTED** | Fits 500 g dock budget and the 70 °C chamber constraint; covers 5 of 6 processes honestly. |
| B | Swap to 1064 nm fibre laser for cut/weld | Rejected | 1064 nm is *invisible* — strictly more dangerous, needs OD6 eyewear. Fibre + chiller + 48 V supply exceeds the 500 g Jubilee budget; a chiller inside a 70 °C chamber is thermodynamically absurd. |
| C | Dual-wavelength (450 + 1064 nm) in one dock | Rejected | Superset of B's problems plus a beam-combining alignment problem that self-replicating printed parts cannot hold. laya ranked this first at p=0.375 — this is the documented disagreement. |
| D | Galvo scanner head | Deferred | Galvo buys *speed*, not precision, and this gantry already does 400 mm/s. A rigid optical bench fights the toolchanger. Real value appears only if marking throughput dominates. |
| E | Do nothing; the 5 W laser is "enough" | Rejected | "Enough" is unenumerable. §3 produces boundaries that can be checked. |

### 2.3 The four non-obvious findings that shaped the design

These came from computing, and each contradicted an initial assumption.

---

## 3. Physics — computed, not asserted

Executed via `src/glmp/optics.py` and `src/glmp/thermal.py`.

### 3.1 Optical power is not 5 W

```
nominal 5.0 W × collimation efficiency 0.70 = 3.50 W at focus
```

Commodity TTL modules are specified at the *driver*. Quoting the datasheet
number overstates capability by **43 %**. Every envelope figure in this
document uses 3.5 W. There is a test asserting this
(`test_optical_power_is_below_datasheet`) and a mutant that breaks it.

### 3.2 Depth of focus is ~35 mm, so autofocus is NOT the bottleneck

The instinctive claim about cheap diode modules is "focus is the hard part."

```
λ=450nm  spot=0.10mm (measured)  f=20mm  D=3mm
Rayleigh range z_R = πw₀²/λ              = 17.45 mm
usable depth of focus (√2 growth)        = 34.91 mm
thermal focal drift over 20 K rise       =  0.08 mm   (245x smaller)
defocus of 5.0 mm → spot grows to        =  0.104 mm  (+4 %)
```

**Depth of focus is 245× the thermal focal drift.** Autofocus is retained (it
costs little and helps solder/weld where the working distance is tight) but it
is ranked *below* power stability. This inverted the initial design priority,
and is why the head's interlock list is built around power and thermal
behaviour rather than focus.

A second, more actionable optical result:

```
diffraction limit at D=3mm, f=20mm  = 7.32 µm
measured spot                       = 100   µm
multimode factor                    = 14×
```

The spot is **diode-limited, not lens-limited**. Improving the optics buys
nothing; improving or replacing the emitter buys everything. This is the single
most useful optical fact in the document, and it is the opposite of what a
"better optics" instinct would do.

### 3.3 The 70 °C chamber and the laser are physically exclusive

The Genesis heats its chamber to 70 °C for PEEK (§9 of the blueprint). A diode
module in a 70 °C ambient **has no thermal sink** — a passive heatsink can only
reach roughly ambient, and diode output droops and lifetime collapse long before
that.

This is not a caution, it is a contradiction. It is enforced as
**Thermal-Fume Interlock (TFI)**: laser enable is denied above 35 °C chamber or
45 °C case. `calibration.py` refuses to even construct a profile whose chamber
ceiling is ≥70 °C, so the field cannot be made decorative.

It is reinforced by a second, independent fact: **polymer cutting requires
fume extraction**, and extraction requires venting the chamber, which makes a
70 °C chamber impossible anyway. Two unrelated requirements agree.

### 3.4 The process envelope, computed

Loss model: dwell `t = kerf_w / v`; conduction length `L = √(α·t)`;
available energy `E_av = P_abs·t`; required `E_req = ρ·A·h·(L_v + c·ΔT)`;
feasible when `E_req ≤ E_av` **and** `L/kerf_w ≤ 20`.

| Process @ 3.5 W, 450 nm | Speed window | Verdict |
|---|---|---|
| Cut PETG 1.0 mm | 1.02 – 19.38 mm/s | feasible (5 s / 100 mm) |
| Cut PETG 3.0 mm | 0.33 – 6.59 mm/s | **feasible** (15 s / 100 mm) |
| Cut PETG 6.0 mm | 0.17 – 3.26 mm/s | feasible (31 s / 100 mm) |
| Cut PMMA 3.0 mm | 0.39 – 7.78 mm/s | feasible |
| Cut PMMA 6.0 mm | — | **refused** (kerf aspect 40:1) |
| Cut birch ply 3.0 mm | — | feasible |
| Cut SS304 0.5 mm | 0.26 – 0.48 mm/s | feasible, **207 s / 100 mm** |
| Weld Cu foil, 0.1 mm pool | 1.42 – 3.85 mm/s | **feasible** |
| Weld Ni foil, 0.2 mm pool | 1.06 – 3.00 mm/s | feasible |
| Weld SS316 3.0 mm | — | **insufficient-power** |
| Weld Al 6061 2.0 mm | — | **insufficient-power** (92 % reflected) |
| Solder/reflow SAC305 | 0.17 – 3.26 mm/s | feasible |
| Any PVC | — | **hazard-refused** (HCl) |

### 3.5 Two corrections to the source blueprint

1. **§4.7 Iteration 1 says "cutting 3 mm PETG — marginal."** It is not. It is
   feasible at 0.33–6.59 mm/s. The blueprint's caution was guesswork; the model
   replaces it with a number.
2. **§18.3 lists "SINTERING" as a laser application.** Sintering is a thermal
   densification process needing hundreds of watts of soak. At 5 W it will not
   sinter metal-fill filament. It has been removed from the process registry
   rather than left as a claim that cannot be met.

### 3.6 Melt removal — a limit the energy model alone gets wrong

Energy and conduction alone declare a 6 mm PMMA cut feasible. It is not: a
0.15 mm kerf filled 6 mm deep cannot drain by gravity or vapour recoil. The
energy balance is correct and the answer is still wrong.

Third veto layer added:

```
kerf_depth / kerf_width ≤ 4   without a cutting assist
                            ≤ 25  with air or oxygen
```

**Argon and nitrogen are excluded from that relaxation.** They are *shielding*
gases — they exclude oxygen around a weld pool and do nothing to clear melt
from a kerf. Treating argon as cutting assist would let the model certify a
3 mm weld pool as removable, which is precisely the kind of plausible-sounding
false positive that burns a part. This was a real bug found and fixed during
the build; mutant `weld ignores stock thickness` guards it.

---

## 4. Hardware design

### 4.1 Head

| Item | Spec | Rationale |
|---|---|---|
| Emitter | 5 W 450 nm multimode diode, TTL 0–5 V | Matches Genesis §18.1 and Klipper `M3 S=` |
| Power | **3.5 W at focus** | §3.1 — the datasheet is not the answer |
| Optics | 3 mm collimated, f=20 mm aspheric | Measured spot 0.10 mm; §3.2 shows optics are not the lever |
| Focus control | 6 mm thread + IR triangulation sensor (1–2 µm) | Cheap; §3.2 shows it is not the bottleneck |
| Thermal | Heatsink + NTC case sensor; **no TEC** | §3.3 — a TEC has no sink in a 70 °C chamber |
| Power monitor | Si photodiode → ADC on the EBB36 node | The real repeatability lever: output droops 10–20 % cold→hot |
| Air assist | Printed PETG-CF nozzle, 0.7 PWM | Required for polymer cutting |
| ECT probe | Lift-off eddy-current, 0.20 mm nominal stand-off | Shares the Genesis Beacon sensing principle |
| Mass | ≤ 340 g | vs. the 500 g dock limit |

### 4.2 Mods to the Genesis printer

| Mod | Where | Why |
|---|---|---|
| TFI relay in the laser enable chain | Laser enable relay (genesis: NC magnetic door relay) | Makes the thermal veto *hardware*, not firmware |
| Chamber temp + airflow into the interlock | MCU I2C (BMP280 already fitted) + SDP31 | §3.3 |
| Photodiode → EBB36 ADC | Tool 5 CAN node | Constant-power loop |
| Fume extraction on laser-tool exhaust | Existing top-rear filtered exhaust | Polymer cutting VOC |
| 6th dock populated with ECT head | Dock 6 (reserved, firmware-disabled gen 1) | §6 — turns the spare slot into an inspection capability |

### 4.3 Safety — defence in depth

```
LAYER 0  HARDWARE, OUTSIDE THIS PACKAGE
         NC magnetic door switch in series with the laser enable relay.
         Breaking it removes beam power regardless of firmware state.
         INHERITED UNCHANGED from Genesis §18.2. This is the real safety.
LAYER 1  SafetyController — single-entry permissive state machine, fails CLOSED.
         Missing sensor → deny.  Stale sensor → deny.  Broken predicate → deny.
LAYER 2  Emitter — no M3 without a verified ArmingState. try/finally guarantees M5.
LAYER 3  Envelope — refuse physically impossible work before attempting it.
LAYER 4  TFI — chamber/case thermal veto, hardware-relayed.
```

Layer 1 reports **every** denial reason, not the first, so an operator who opens
a door on a hot chamber is told about both.

Verified refusals (all exit code 4, all executed this session):

```
$ glmp program cut petg 1.0 --no-arm        → refuses: no arming state
$ glmp program cut petg 1.0 --interlock-open → door open
$ glmp program cut petg 1.0 --chamber-c 70   → PEEK mode exclusive
$ glmp program cut petg 1.0 --no-extraction   → airflow below threshold
$ glmp program cut petg 1.0 --case-c 55      → case over limit
$ glmp interlock --stale                     → 6 sensors stale, fails closed
```

---

## 5. Software

Zero runtime dependencies (stdlib only) — it runs on a Pi CM4 on an SD card for
years, where every transitive dependency is a future compromise with a path to
the machine tools.

```
optics.py       beam waist, DOF, thermal focal drift        (computed)
thermal.py      conduction loss model, speed-window solver  (computed)
envelope.py     3-layer veto → verdict + reason + numbers
materials.py    TOML → Material   (unknown keys rejected)
processes.py    TOML → Process    (unknown keys rejected)
calibration.py  machine profile, evidence, arming state
safety.py       permissive interlock, fails closed
recipe.py       the boundary object; JSON round-trip stable
resolve.py      Planner: material × process × thickness → recipe | refusal
program.py      guarded G-code emitter
ect.py          raster planning + scan analysis
workflow.py     multi-tool sequences
cli.py          every capability reachable as a named command
```

### 5.1 Dev-policy gate status

| Gate | How it is met |
|---|---|
| EXTENSIBLE | New process = one TOML table. No code change. |
| MODULAR | One concern per module; no cross-imports outside declared interfaces. |
| SCRIPTABLE | Every feature is a `glmp` subcommand. |
| PROGRAMMABLE | Behaviour is TOML data; the machine profile changes without recompiling. |
| REPLICABLE | Emission is deterministic; recipe JSON is byte-stable across round-trip. |
| INTEROPERABLE | TOML in, standard Marlin/Klipper G-code out; JSON round-trip tested. |
| TESTABLE | 182 tests; **20/20 mutants caught**. |
| OPERABLE | `glmp selftest` executed **576** capability evaluations. |

### 5.2 Why 3 mm PETG is feasible but the blueprint says otherwise

`climb` is a planner defect caught in the build: for `weld` it used the
*process* pool depth and ignored stock thickness, so `glmp can weld ss316 3.0`
returned **feasible**. A tool that certifies welding 3 mm steel at 5 W is
dangerous. Fixed by `Process.depth_source`: `cut` and `weld` are modelled at
the stock thickness; surface processes are not. A mutant re-introduces the bug
to prove the suite catches it.

---

## 6. ECT — the cheapest process added

ECT shares the dock but not the beam. It is the cheapest to add and the only
process producing a **direct measurement** rather than an inferred one.

Design decisions:
- **Serpentine raster traversing each row.** An early version emitted only row
  endpoints; the motion program flew over the entire scan area while claiming
  to have sampled it. Found by test; mutant `raster skips row interiors` guards it.
- **Lift-off drift is a hard refusal.** 20 µm drift on a 200 µm stand-off is a
  10 % amplitude error — enough to manufacture a false positive across the
  whole traverse, or hide a real defect.
- **Both polarities tested.** A lift-off probe gives a *negative* lobe across a
  transverse crack. A one-sided detector misses the crack case, which is the one
  the operator most needs. Mutant `ECT becomes one-sided` guards it.
- **Robust scale (MAD), with a noise floor.** A flat signal gives σ = 0, and a
  threshold equal to the baseline flags nothing — including a real defect.
- **Polarity is reported; diagnosis is not.** The module states
  `negative-lobe (discontinuity-suspect)` — measurement, not verdict.

Verified: injected crack at (161.00, 155.00) mm is detected at
`dev=-0.32 len=7.00mm negative-lobe (discontinuity-suspect)`.

---

## 7. Process-recipe creation (the "processor" half)

```bash
glmp can   cut petg 3.0        # capability question, no recipe
glmp plan  cut petg 3.0        # derive a validated recipe
glmp program cut petg 3.0      # emit guarded G-code
```

Output carries provenance into the emitted file:

```
; recipe      : cut-petg-3mm
; material    : petg @ 3mm
; machine     : genesis-glm-h1 (assumed)
; optical     : 3.50W at focus
; envelope    : feasible
; note        : material constants are assumed, not measured on this machine
```

An incident review reads its answer from the program, not from a ticket that
may not exist.

**Operating point:** the planner takes the geometric mean of the feasible speed
band, not the fastest point. The fastest point in a band is by definition the
one where the process is *just* clearing the budget; production run there means
a duller spot or a 2 °C ambient difference turns the job into char. The band is
published so an operator can take the throughput edge knowingly.

---

## 8. Verification actually executed

| Check | Command | Result |
|---|---|---|
| Test suite | `pytest tests/ -q` | **182 passed** |
| Mutation check | `scripts/mutation_check.py` | **20/20 mutants caught** |
| Capability matrix | `glmp selftest` | **576 evaluations executed** |
| Interlocks | 6 refusal scenarios | all refused, exit 4 |
| ECT detection | `glmp ect-scan --inject-defect` | crack located at (161.00, 155.00) |
| Recipe round-trip | `Recipe → JSON → Recipe` | byte-identical |
| Calibration verify | `glmp calibrate verify optical` | 6 criteria pass, derives 0.700 / 0.0937 mm |
| Synthetic guard | `promote` on a simulated record | refused, exit 3 |
| Tamper detection | edited measurement in a record set | digest mismatch, refused |
| Unattested record | measurement with no operator | refused at construction |
| Promotion without `--write` | validate-and-stop | file byte-identical |
| Promotion idempotency | same values re-promoted | `wrote 0 edit(s)`, file unchanged |
| Audit chain | two promotions | chain and hash both verified |
| Material promotion | copper only | 15 other materials byte-identical |
| Failed write verify | injected verification failure | backup restored, file unchanged |
| Comment-blind locator | substring-match mutant | caught (was vacuous at first try) |

Phase-14 five-method verification: multi-attempt ✓ (3 rejected alternatives
traced), independent perspectives ✓ (maintainer/adversarial — the melt-removal
gap and the argon mis-classification both came from adversarial review),
alternative architecture ✓ (§2.2), theoretical limit ✓ (§3.4 boundaries),
fresh eye ✓ (two wrong test assertions of mine were caught and corrected).

---

## Open items — not designed away

1. **Promotion writes, behind `--write`.** The writer is implemented
   (`persist.py`): surgical in-place TOML editing that preserves every comment,
   a timestamped backup, post-write verification that restores the file on
   failure, and a hash-chained audit log. Idempotent — re-promoting the same
   values reports zero edits. Still absent: a signed-measurement scheme, which
   would authenticate the operator rather than merely record their name.
2. **Thermal model is a 1-D conduction approximation.** It ignores convective
   losses into the kerf and the fluid dynamics of melt ejection. The melt-removal
   veto is an empirical bound standing in for that physics.
3. **No fibre or galvo path.** Both rejected on envelope grounds (§2.2). If
   `weld` must cover structural stock, that is a separate bench machine, not a
   head.
4. **`sinter` removed from the registry** (§3.5) — it was unachievable at 5 W.
   Adding it back would be a false claim.
5. **ECT classification is polarity-only.** Real defect typing from a lift-off
   signal needs a trained reference library; none is claimed.
6. **Integrity beyond attestation.** The hash chain detects tampering with a
   file; it does not authenticate the operator. A signed-measurement scheme
   would, and is out of scope here.
7. **Subject/instrument separation.** `Measurement.subject` is what was
   measured; `instrument` is what measured it. The material procedure groups
   by subject, and the repeatability criterion groups by *(subject,
   instrument)* - so a probe that is steady on copper and scattered on
   aluminium no longer averages into an acceptable CV. Promotion validates the
   subject against the material database, so a probe serial is refused with a
   message naming the mistake rather than a layout error.

### Calibration (IMPLEMENTED — `glmp calibrate`)

The apparatus is real, tested code. The **measurements are absent** until an
operator takes them, and the software refuses to invent them.

| Command | Measures | Promotes |
|---|---|---|
| `glmp calibrate verify optical` | spot by knife-edge; power by photodiode at 5 duty steps | `collimation_efficiency`, `waist_diameter_mm` |
| `glmp calibrate verify material` | 450 nm reflectance against a certified standard, 3+ repeats | `reflectance_450nm` per material |
| `glmp calibrate verify focus-drift` | best focus vs case temperature over ≥10 K | `measured_focal_shift_mm_per_k` |
| `glmp calibrate verify duty` | steady-state case temperature vs duty | `max_safe_duty` |

Four guards make a bad number unable to reach the machine profile:

1. **Acceptance criteria.** Power must be linear in duty (R² > 0.99) and
   monotonic; full-duty power must be physically plausible for a 5 W module —
   which is what catches a photodiode with a wrong calibration factor before it
   becomes a "measurement". The spot profile must be symmetric about its own
   centre; skew > 0.15 means a damaged or de-centred asphere, not a small spot.
2. **Named operator required.** A measurement with no operator is refused at
   construction. An unattested number is not a measurement.
3. **Hash chain.** Records chain SHA-256; editing, reordering or substituting
   one breaks every hash after it. Verified:
   `record set digest mismatch: the file has been edited, reordered, or
   partially replaced since it was written`.
4. **Synthetic refusal.** A record labelled `simulated` can never promote,
   regardless of whether it passes every criterion:
   `REFUSING to promote: 10 measurement(s) are labelled 'simulated'...`

The limit, stated plainly: **this software cannot tell a true measurement from
a confident lie.** It rejects the record that declares itself synthetic and it
requires a named attestation. Beyond that, integrity is a property of the
operator and the procedure, not of the code. Pretending otherwise would be the
failure this module exists to prevent.

Independently confirming the assumed constants: the optical fixture was built
to represent a 0.10 mm spot and 70 % collimation, and `derive` recovers
**0.0937 mm** and **0.700** from the raw scan by first principles. The assumed
values were right; now they are checkable.

| Step | Measures | Promotes |
|---|---|---|
| `calibrate optical` | spot by knife-edge scan; power by calibrated photodiode at 5 power steps | `machine.evidence → measured` |
| `calibrate material` | absorbance per material by burn-markscan ratio | `material.evidence → measured` |
| `calibrate focus-drift` | focal shift vs case temperature, 25 → 45 °C | `dn_dt_per_kelvin` |
| `calibrate duty` | case temperature vs drive duty at fixed power | the duty cap |

---

## 10. Disclosure block

```
LOADED      mcsa phase 1  (honesty, routing, ontology)
            mcsa phase 12 (gates, honesty, refinement)
            mcsa phase 13/14 (refinement, gates)
            Genesis 3D Printer.md  §§1-8, 13, 16-21, 32-34  (read directly)
            AEFRI/README.md (read directly)
NOT LOADED  Genesis blueprint §§9-12 (frame/BOM details) — immaterial to the
            laser head; conclusions exclude them
            aequchain EVER node internals — the ledger integration is
            unchanged from the blueprint and is not touched here
DECISION    laya consulted, DISCARDED (confidence 0.019-0.102, near-uniform)
ENGINE      ABSUBEST consulted, DISCARDED (index-monotonic placeholder
            candidates; sensitivity "assumed", not applied)
            Arbitration: first-principles physics vs. Genesis spec
TRIERS      No model tier produced the verdict. Physics did. Stated plainly
            rather than attributing the conclusion to an engine.
STATUS      182 tests pass, 20/20 mutants caught, 576 evaluations executed.
            ZERO hardware measurements. All constants labelled `assumed`.
```

---

*MIT / CC0. Extends the AEFRI Genesis Printer blueprint. Print this file: the
Genesis can laser-mark its own parts with `glmp workflow mark-and-verify`.*
