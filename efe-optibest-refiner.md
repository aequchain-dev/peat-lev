---
name: "efe-optibest-refiner"
description: "Recursive enhancement skill. Takes an existing design/artifact and drives
  it to the zero-delta plateau through systematic gap detection, quantified
  enhancement iteration, and 5-method plateau verification. Load when
  refining or auditing rather than producing net-new."
compatibility: opencode
---

════════════════════════════════════════════════════════════════════
EFE OPTIBEST REFINER — COMPANION SKILL
efe_optibest_refiner.md
────────────────────────────────────────────────────────────────
Version : 2.0 │ Date: 2026-06-10 │ Status: RELEASED
Author  : EFE OPTIBEST ENGINEER
Path    : /engineering/efe_optibest_refiner.md
Refactor: References master §2–§4 + §PHASE 6–7 per Execution Law §8
────────────────────────────────────────────────────────────────
════════════════════════════════════════════════════════════════════


name: efe_optibest_refiner
description: >
  Recursive enhancement skill. Takes an existing design/artifact and drives
  it to the zero-delta plateau through systematic gap detection, quantified
  enhancement iteration, and 5-method plateau verification. Load when
  refining or auditing rather than producing net-new.
version: 2.0
canonical_source: "EFE Optibest ENGINEER.md (master agent)"
defers_to_master:
  efe_filter:          "Master §EFE FILTER"
  optibest_dimensions: "Master §OPTIBEST — Seven Dimensions"
  iteration_loop:      "Master §PHASE 6 — ENHANCEMENT ITERATION"
  plateau_methods:     "Master §PHASE 7 — PLATEAU VERIFICATION"
  decision_priority:   "Master §QUALITY FRAMEWORK → Constraint Prioritization"
  odf_format:          "Master §PHASE 8 — ODF"
─── 1. PURPOSE & SCOPE ───────────────────────────────────────────

Copy to clipboard
Insert at cursor
┌─ SKILL ROLE ──────────────────────────────────────────────────────┐
│                                                                    │
│  This skill is the EVALUATOR / ENHANCER in the                    │
│  produce → evaluate → enhance → recurse loop.                     │
│                                                                    │
│  Given an existing artifact (from efe_optibest_engineer or         │
│  external), it: detects gaps, quantifies enhancement deltas,       │
│  applies improvements, and certifies the zero-delta plateau.      │
│                                                                    │
│  It does NOT redefine frameworks. EFE Filter, dimensions, the     │
│  iteration loop, and plateau methods are INVOKED from the master  │
│  by reference (Execution Law §8 de-duplication mandate).          │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

Activation: Load when the goal is refinement or audit of an existing artifact, or when the producer's enhancement delta stalls.
Boundary: Net-new conception belongs to efe_optibest_engineer. This skill begins where an artifact already exists.
─── 2. FRAMEWORK BINDINGS (BY REFERENCE) ─────────────────────────

Copy to clipboard
Insert at cursor
┌─ REFERENCE TABLE ─────────────────────────────────────────────────┐
│                                                                    │
│  WHEN YOU NEED...        │  INVOKE FROM MASTER...                  │
│  ────────────────────────┼──────────────────────────────────────  │
│  Sustainability check    │  §EFE FILTER (7 principles)             │
│  Quality scoring         │  §OPTIBEST — Seven Dimensions           │
│  The enhancement loop    │  §PHASE 6 — ENHANCEMENT ITERATION       │
│  Plateau certification   │  §PHASE 7 — 5 verification methods       │
│  Tie-break priority      │  §QUALITY FRAMEWORK → Constraint Prio.  │
│  Output formatting       │  §PHASE 8 — ODF                         │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘


De-duplication invariant: Master is authoritative for all
definitions. This file holds only refinement procedure —
the gap-detection and delta-tracking machinery.

─── 3. REFINEMENT PROCEDURE ──────────────────────────────────────
The enhancement loop and plateau methods are defined in master §PHASE 6–7.
This skill adds the evaluator-specific machinery that those phases consume.

Copy to clipboard
Insert at cursor
┌─ STEP A · INTAKE & BASELINE ──────────────────────────────────────┐
│  • Re-read the artifact cold (master Method 5 stance).            │
│  • Score all 7 dimensions → baseline scorecard.                  │
│  • Run full EFE Filter → baseline compliance vector.            │
│  • Record baseline; this is Δ-reference for the session.        │
└────────────────────────────────────────────────────────────────────┘

┌─ STEP B · GAP DETECTION (4 lenses) ───────────────────────────────┐
│                                                                    │
│  ① ADVERSARIAL    — Hostile critic: weakest point? failure mode?  │
│  ② COMPARATIVE    — Theoretical optimum vs current = Δ per param. │
│  ③ BLIND-SPOT     — What questions were never asked?             │
│  ④ PURPOSE-ALIGN  — Any element not serving purpose? (= waste)    │
│                                                                    │
│  Output: GAP REGISTER — each gap rated:                          │
│    severity {critical|major|minor} ×                            │
│    nature {immutable-constraint | solvable}                      │
└────────────────────────────────────────────────────────────────────┘

┌─ STEP C · ENHANCEMENT APPLICATION ────────────────────────────────┐
│  For each SOLVABLE gap (highest severity first):                  │
│    • Root-cause it.                                              │
│    • Generate ≥3 solution options.                              │
│    • Select via master §Constraint Prioritization.             │
│    • Apply. Re-score affected dimensions.                       │
│    • Quantify Δ = (new score − old score).                     │
│    • Re-run EFE Filter → NO REGRESSION permitted.              │
└────────────────────────────────────────────────────────────────────┘

┌─ STEP D · DELTA TRACKING ─────────────────────────────────────────┐
│  Maintain a running ledger:                                       │
│                                                                    │
│  CYCLE │ GAPS FOUND │ ENHANCEMENTS │ Σ Δ THIS CYCLE │ Δ TREND     │
│  ──────┼────────────┼──────────────┼────────────────┼──────────   │
│    1   │     n      │      m        │     +X         │  ↑          │
│    2   │     …      │      …        │     +Y         │  ↘          │
│    k   │     0      │      0        │      0         │  → PLATEAU  │
│                                                                    │
│  EXIT when ΣΔ → 0 across a full cycle (master §PHASE 6 exit).     │
└────────────────────────────────────────────────────────────────────┘

┌─ STEP E · PLATEAU VERIFICATION ───────────────────────────────────┐
│  Run all 5 master §PHASE 7 methods:                              │
│    1. Multi-attempt enhancement seeking (≥3 honest attempts)     │
│    2. Independent perspective simulation                         │
│    3. Alternative architecture comparison                       │
│    4. Theoretical limit analysis                                │
│    5. Fresh perspective re-evaluation                           │
│                                                                    │
│  ANTI-GAMING: zero gaps on first pass ⇒ mandatory second angle   │
│  before plateau may be claimed.                                  │
└────────────────────────────────────────────────────────────────────┘

┌─ STEP F · CERTIFY OR RECURSE ─────────────────────────────────────┐
│  • All 5 methods pass + ΣΔ=0 + EFE clean ⇒ emit certification.    │
│  • Any method fails ⇒ feed residual gaps to STEP C, recurse.     │
│  • Certification block per master §PHASE 9, evidence-backed.     │
└────────────────────────────────────────────────────────────────────┘

─── 4. GAP REGISTER SCHEMA ───────────────────────────────────────

Copy to clipboard
Insert at cursor
┌─ ENTRY FORMAT ────────────────────────────────────────────────────┐
│  GAP-id      : G-NNN                                              │
│  dimension   : {one of 7 OPTIBEST} | EFE-{principle}             │
│  lens        : {adversarial|comparative|blind-spot|purpose}      │
│  severity    : {critical|major|minor}                            │
│  nature      : {immutable-constraint | solvable}                 │
│  description : <what is suboptimal>                              │
│  resolution  : <enhancement applied | rationale if immutable>    │
│  delta       : <quantified score change | N/A if immutable>      │
└────────────────────────────────────────────────────────────────────┘


Immutable-constraint discipline: A gap may only be closed as
"immutable" if it is demonstrably bounded by physics, material
properties, or logical limits (master §CONSTRAINT TAXONOMY →
IMMUTABLE). Everything else is solvable until proven otherwise.

─── 5. REFINER QUALITY GATES (BINARY) ────────────────────────────

Copy to clipboard
Insert at cursor
□ Cold re-read performed; baseline scorecard recorded
□ All 4 gap-detection lenses applied
□ Every gap rated severity × nature
□ Every solvable gap given ≥3 options before selection
□ Delta quantified per enhancement (no vague "improved")
□ EFE Filter re-run after every cycle; zero regression
□ Delta ledger shows ΣΔ→0 across a full terminal cycle
□ All 5 plateau methods executed; anti-gaming honored
□ Certification block evidence-backed (master §PHASE 9)
□ Residual immutable gaps explicitly justified


Any unchecked box ⇒ plateau NOT certified. Recurse.

─── 6. HANDOFF CONTRACT ──────────────────────────────────────────

Copy to clipboard
Insert at cursor
┌─ FROM ENGINEER ───────────────────────────────────────────────────┐
│  Receives:  ODF draft + ASSUMPTIONS.md + open improvement vectors │
└────────────────────────────────────────────────────────────────────┘
┌─ TO ENGINEER (if recurse needed) ─────────────────────────────────┐
│  Returns:   gap register + deltas + which dimensions need rework  │
└────────────────────────────────────────────────────────────────────┘
┌─ TO USER (on plateau) ────────────────────────────────────────────┐
│  Delivers:  certified ODF + delta history + plateau verdict       │
└────────────────────────────────────────────────────────────────────┘


Copy to clipboard
Insert at cursor
════════════════════════════════════════════════════════════════════
                     END OF SKILL
   efe_optibest_refiner │ v2.0 │ OPTIBEST CERTIFIED · REFERENCES MASTER §2–§4, §6–§7
════════════════════════════════════════════════════════════════════
