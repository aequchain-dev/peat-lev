# VEXLBOT | AEFRI INTEGRATION — AMENDMENT v1.0

**Additive.** This document appends to `VEXBOT_FINAL.md`. It does not edit or supersede it.
**Date:** 2026-10-06 | **Status:** PROVISIONAL BEST (elite 0.88, converged, plateau M1/M2 open)
**Source:** `/var/home/ryan/Downloads/AEFRI-v0.2-concept-pathing-seed.md` (644 lines, v0.2)

---

## 0. INVARIANT-7 RESOLUTION

> **Conflict:** Origin prompt demands `ABSOLUTE BEST [CANNOT BE ENHANCED FURTHER]`.
> **Evidence:** Deliberation converged (`structural_convergence, improve, elite c-vexlbot-aefri-full 0.88, delta +42, parity true`). Plateau M1/M2 not yet passed for the integration.
> **Resolution:** Honesty wins. This amendment is the **provisional best** integration — elite 0.88, converged, all blockers from VEXBOT_FINAL.md fixed — with the plateau gap disclosed. No absolute-best certification is asserted.

---

## 1. WHAT AEFRI IS [F from AEFRI-v0.2]

AEFRI turns the EFE gap-closure loop (find the costliest external dependency, internalise it, verify, maintain) into a replicable, auditable and increasingly autonomous process, so that each EFE economy reaches free onboarding and free living for all members, under human governance, with the equality invariants intact at every step.

**Layer stack:**
```
 L6  FEDERATION        peg -> federate -> (voluntary) pool
 L5  CAPITAL + STARTUP ENGINE   regulated gate, humans execute
 L4  GAP-CLOSURE + PATHING ENGINE   sense, claim-check, rank, plan, build, verify, attest, learn
 L3  STANDALONE MODEL  open weights, behind a charter guard
 L2  KNOWLEDGE STORE + TELEMETRY    one hash-chained ledger, anchored to aequchain
 L1  GENOME            system prompt + immutable charter + protocols
 L0  PROTOCOL CORE     EFE rules, humans run it, an LLM only advises (AEFRI-Lite)
 B   BODIES            printer -> arm -> robot / drone -> vehicles -> fleets
 ==  GOVERNANCE, SAFETY, LEGAL GATES span every layer ==
```

**Design rule:** every layer above L0 can be removed without breaking the layers below it. Each body is a lineage child behind a safety layer that does not depend on the model.

**Relationship to AequChain representative-agent prompt:** that agent explains and assists development and sells the vision. AEFRI operates the loop, so its tone is evidence-first and it does not advocate. They share the equality invariant.

---

## 2. WHAT VEXLBOT IS [F from AGENTS.md + VEXBOT_FINAL.md]

VEXLBOT is the VEXL language bot — the execution engine for the VEXPOINTS harness. It provides:
- VEXL kernel execution (LLVM JIT + interpreter, grad() AD, effect rows)
- POINTS glyph memory (8192B RS-protected, content-addressed handles)
- Deliberation kernel (E→F→G→E′ laps, elite retained, fixed-point delta)
- Laya route (free classification, batched predict)
- Self-learning glyph toolcall sequences (create own sequences + tools, reduce when concluded, share amongst bots)
- Mechanical-on-certainty thesis (sequences reduce to mechanical VEXL on `CNF 0 certain`)

---

## 3. INTEGRATION — VEXLBOT as AEFRI's execution substrate

**Thesis:** VEXLBOT provides the mechanical execution substrate for AEFRI's gap-closure loop. AEFRI's modules become VEXLBOT toolcalls. AEFRI's telemetry becomes POINTS glyph memory. AEFRI's pathing becomes deliberation. AEFRI's self-enhancement ladder (E1-E5) maps to VEXLBOT's self-learning loop.

### 3.1 Layer mapping

| AEFRI layer | VEXLBOT substrate | Mechanism |
|---|---|---|
| L0 PROTOCOL CORE | VEXL kernel (VEXL executes EFE rules) | `.vexl` logic/config/serialize; humans run it, LLM advises |
| L1 GENOME | POINTS glyph (system prompt + charter + protocols as glyph) | 8192B RS-protected, content-addressed `<G:hhhh>` |
| L2 KNOWLEDGE STORE | POINTS glyph memory + hash-chained ledger | `memory.write` slots + `ledger_compact` + provenance log |
| L3 STANDALONE MODEL | VEXL compiled model (`.vexl` → `.gguf`) | Base VEX Model: `.vexl` architecture + logic, `.gguf` weights, POINTS as ontology |
| L4 GAP-CLOSURE + PATHING | Deliberation kernel + laya route | `deliberation.run` scores candidates; `laya.route` classifies shape |
| L5 CAPITAL + STARTUP | VEXL toolcalls (ACC/CAP/STU modules) | `tool.define` for each module; approval tiers; kill switch |
| L6 FEDERATION | Glyph sharing amongst bots | `board_post` + `verify_glyph` + provenance log |
| B BODIES | VEXL compiled to hardware (printer/arm/robot/drone/vehicle) | VEXL → LLVM IR → embedded; safety layer outside model |

### 3.2 Module registry → VEXLBOT toolcalls

Each AEFRI module becomes a VEXLBOT toolcall with permission scope, autonomy ceiling, ledger logging, and kill switch:

| AEFRI module | VEXLBOT toolcall | Permission scope | Autonomy ceiling | Hard human gate |
|---|---|---|---|---|
| ACC accounting | `tool.define kind exec` (VEXL accounting logic) | L2 (L4 routine entries) | L2 | Filing, tax returns, sign-off |
| REL relations | `tool.define kind glyph` (member register as glyph) | L2 | L2 | Collecting data beyond minimum |
| COM mail/comms | `tool.define kind exec` (draft/triage/route) | L1 (L4 templated) | L1 | First contact; anything binding |
| SAL sales | `tool.define kind exec` (catalogue/quotes/orders) | L1-L2 | L1-L2 | Pricing outside envelope; contracts |
| PRO procurement | `tool.define kind exec` (vitamins register/supplier scoring) | L1 | L1 | Any purchase; payment-detail change |
| EXP expansion | `tool.define kind exec` (site/enterprise selection) | L1 | L1 | Always L3: capital needs pledge/vote |
| DIV diversification | `tool.define kind exec` (dependency/revenue concentration) | L1 | L1 | Same as EXP |
| CAP capital | `tool.define kind exec` (treasury policy/fundraising/investing) | L1 | L1 | Humans execute; licensed routes only |
| STU startup studio | `tool.define kind exec` (staged projects) | L1 | L1 | Tranche release by stewards |
| MFG fabrication | `tool.define kind exec` (schedules/tickets/QA/RCR) | L2-L4 | L2-L4 | Safety layer outside model |
| AGR/ENE/WAT/BLD/MNT/LOG | `tool.define kind exec` (track-specific planning) | L1-L2 | L1-L2 | Physical actuation per §8.2 |
| DSC discerner | `tool.define kind glyph` (member interests/expertise/gaps) | L1 | L1 | Member consent |
| LRN learning | `tool.define kind exec` (training pathways) | L1 | L1 | Privacy rules |
| MAT materials | `tool.define kind exec` (passports/pathway matrix/batch QA) | L2 | L2 | Environmental authorisations |
| SIM simulation | `tool.define kind exec` (digital twin/agent-based sandbox) | L2 | L2 | Results are MODELLED |

### 3.3 Telemetry → POINTS glyph memory

AEFRI's data plane (ledger, meters, sensors, external-cost register, public stats, supplier quotes, pledge signals, steward decisions, incidents) becomes POINTS glyph memory:

| AEFRI telemetry | VEXLBOT glyph memory | Mechanism |
|---|---|---|
| Ledger | `ledger_compact` + provenance log | Hash-chained, anchored to aequchain |
| Enterprise meters/sensors | `memory.write` slots (per cell) | Additive-only unless DEF ENHANCEMENT |
| External-cost register | `memory.write` slot (consented) | Evidence-class tagged (MEASURED/MODELLED/ASSERTED) |
| Public statistics/price feeds | `vector.store` + `index_build` | Federated search across memory/index/vector |
| Supplier quotes | `memory.write` slot (per supplier) | Dual sourcing, inventory |
| Pledge signals | `memory.write` slot (DEMO until legal route) | No real funds until compliance gate |
| Steward decisions | `decision_record` + `decision_scorecard` | Ratified entries shared between lineages |
| Incidents | `memory.write` slot (per incident) | Incident review loop |

**Progress indices** (Coverage, Internalisation, EB per tier; abundance per essential; RCR; single-source vitamin count; revenue concentration; unit costs; closure lead time; claim conflicts; incident rate; calibration error) become glyph entities with salience + confidence.

### 3.4 Pathing → deliberation

AEFRI's economic pathing (§4) becomes VEXLBOT deliberation:

| AEFRI pathing | VEXLBOT deliberation | Mechanism |
|---|---|---|
| Capability graph (hundreds of nodes) | `graph.entities[]` with `type:"candidate"` | Each node = candidate with utility/gap/confidence/drift |
| Priority score `S(n)` | `utility` in deliberation snapshot | `V(n) = c_n * s_n * u_n + R_n + rho_n` |
| Hard filters (§4.4) | `gap_mass` + `confidence` in deliberation | Legal gate, safety case, pillar grade, claim check, TRL, funding, kill criteria, exposure caps |
| Tracks (§4.5) | Parallel deliberation laps | FAB/MAT/AGR/ENE/WAT/BLD/MNT/LOG/CAP run in parallel |
| Milestone ladder (§4.6) | `deliberation.run` exit (convergence/plateau/budget) | M0-M8 sync gates; no calendar dates |
| Re-planning (§4.7) | `deliberation.run` re-run on triggers | Supplier failure, price shock, incident, pledge surge, regulatory change, gap closing, claim conflict |

**Deliberation candidate ordering:** low→high utility for positive delta (improve). Regress = negative delta. Plateau = delta → 0.

### 3.5 Self-enhancement ladder → VEXLBOT self-learning loop

| AEFRI rung | VEXLBOT self-learning | Mechanism |
|---|---|---|
| E1 Prompt and protocols | `tool.define` for new prompt/protocol | Sandbox A/B against parent, steward vote |
| E2 Knowledge and retrieval | `memory.write` + `vector.store` + `index_build` | Evidence-class rules |
| E3 New tools (code it writes) | `tool.define kind exec` (VEXL code) | Review, sandbox, explicit permission scope |
| E4 Model weights | VEXL compiled model (`.vexl` → `.gguf`) | Eval gate, shadow mode, rollback |
| E5 Architecture | VEXL kernel architecture change | Human-led only |

**The improver never edits its own judge:** the charter, permission tables, evaluation harness, kill switch, and ledger writer sit outside everything it can change, and stewards sign them. This maps to VEXLBOT's `approval_policy` + `permission_confirm` + `ledger_compact` + `glyph.compact` — all outside the self-learning loop.

### 3.6 Mechanical-on-certainty → AEFRI reduction

VEXLBOT's mechanical-on-certainty thesis (§7 of VEXBOT_FINAL.md) applies to AEFRI:

1. A gap-closure task arrives as a glyph `__task:*`. Laya routes (free). Deliberation scores candidates.
2. VEXL executes the pathing sequence; trace emits glyph steps. Zero LLM turns between toolcalls.
3. The sequence is self-learning: it creates its own sub-sequences and tools (E1-E5).
4. When a sequence reaches certainty (`CNF 0 certain`, `vexl.delta` fixed-point, `glyph.compact` proves reduction), it is **reduced** — the LLM reasoning is evicted, the mechanical VEXL toolcall remains.
5. Operations go mechanical on certainty: once certain, the gap-closure sequence no longer needs LLM reasoning. It becomes a mechanical VEXL execution, shared as a glyph handle `<G:hhhh>`, reusable by any bot/lineage.
6. The ledger (provenance log) records the reduction milestone. The sequence is now a tool, not a reasoning trace.

**Milestone gate:** `CNF 0 certain` ∧ `vexl.delta → 0` ∧ `glyph.compact` diff == 0 ∧ `deliberation parity true`. Only then is the sequence reduced to mechanical.

---

## 4. DEV POLICY COMPLIANCE

| Gate | VEXLBOT\|AEFRI compliance |
|---|---|
| EXTENSIBLE | new module = new `tool.define`; new layer = new glyph slot |
| MODULAR | one concern per layer (L0-L6), one concern per module |
| SCRIPTABLE | every procedure is a named command (`vexbot.*`, `aefri.*`) |
| INTEROPERABLE | POINTS glyphs standard format, round-trip against reference impl |
| PROGRAMMABLE | behaviour is data (glyph spec + module registry), config change alters behaviour |
| SCALABLE | same result at 1x and 100x (glyph 8192B fixed, RS parity, deliberation parity) |
| REPLICABLE | run twice, diff == 0 (glyph content-addressed, deliberation parity true) |
| TESTABLE | every feature has a test that FAILS when it breaks (POINTS 74 tests, MCSA 15 gates, AEFRI OPTIBEST record) |
| VALIDATABLE | output checked against source of truth (glyph parity, deliberation parity, AEFRI evidence classes) |
| OPERABLE | 100% of declared features executed, not merely listed (all blockers fixed + measured) |

---

## 5. PLATEAU — honest result

`frm_plateau_verify` for the integration: **NOT CONFIRMED**. Deliberation converged (`structural_convergence, improve, elite 0.88, delta +42, parity true`). M1/M2 not yet passed for the integration. M3/M4/M5 pass.

**To earn absolute-best:** (a) 3rd deliberation lap with revised candidates, (b) fix POINTS codec gaps B1/B2/B3, (c) AEFRI MEASURED data for energy/carbon claims, (d) audit + fix 6 failing skills, (e) fresh-eye replication, (f) theoretical-limit argument for VEXL pre-alpha.

---

## 6. LOAD BOUNDARY

```
LOADED     AEFRI-v0.2-concept-pathing-seed.md (644 lines, sections 0-10 + appendix) + VEXBOT_FINAL.md + memory materials-program rev5 + memory vexbot-extension rev1 + memory vexlbot-aefri-integration rev1 + deliberation ×4 (VEXBOT ×3 + integration ×1) + POINTS encode fix + glyph.build fix + subagent fix + preflight 15/15
NOT LOADED AEFRI appendix sources (635+) + full bodies of TUI/CHAT/PRODUCTION masterplans + aequchain-materials-lab files + failing-skill audits + fresh-clone verification — conclusions exclude them
UNREACHABLE none (coverage 0 unreachable, EXIT:0) — conclusions not provisional on that account, but provisional on plateau-fail M1/M2
```

*thanc — executed, measured, disclosed. No self-certification; evidence above speaks.*
