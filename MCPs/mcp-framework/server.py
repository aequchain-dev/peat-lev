#!/usr/bin/env python3
"""efe_framework_mcp — EFE Filter, OPTIBEST scoring, FMEA, gap detection,
plateau verification, constraint classification, project certification."""
import sys, json
sys.path.insert(0, "/var/home/ryan/.local/share/efe-mcps/shared")
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any, Literal

mcp = FastMCP("efe_framework_mcp")

class EFEFilterInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_efe_tiers: List[int] = Field(..., description="EFE tier of each material used (1-4)")
    energy_source: str = Field(..., description="Production energy: solar/wind/hydro/grid_renewable/grid_unknown/coal/gas")
    operation_energy: str = Field("passive", description="Operation energy: passive/human/solar/grid_renewable/grid_unknown")
    is_patent_free: bool = Field(..., description="No patent barriers to manufacture/use")
    is_open_documentation: bool = Field(True, description="Full documentation publicly available")
    local_sourcing_percent: float = Field(..., ge=0, le=100, description="% materials/components locally/regionally sourced")
    eol_recovery_percent: float = Field(..., ge=0, le=100, description="% mass recovered at end-of-life")
    has_hazardous_waste: bool = Field(False, description="Production generates hazardous waste")
    design_life_years: float = Field(..., gt=0, description="Target design life (years)")
    is_repairable: bool = Field(True, description="Can be repaired with common tools")
    is_upgradeable: bool = Field(True, description="Modular/upgradeable without full redesign")
    is_globally_deployable: bool = Field(..., description="Can be built/used anywhere without import dependency")

@mcp.tool(name="frm_efe_filter", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_efe_filter(params: EFEFilterInput) -> str:
    """Evaluate design against all 7 EFE Filter principles."""
    ren_sources={"solar","wind","hydro","geothermal","biomass","wave","tidal","passive","human","grid_renewable"}
    es=params.energy_source.lower(); oe=params.operation_energy.lower()
    principles={
        "1_SUSTAINABLE":{"pass":max(params.material_efe_tiers or [4])<=2 and not params.has_hazardous_waste,
            "evidence":f"Max material tier={max(params.material_efe_tiers or [4])}, hazardous_waste={params.has_hazardous_waste}",
            "action":"Replace Tier 3-4 materials with Tier 1-2. Eliminate hazardous waste." if max(params.material_efe_tiers or [4])>2 else "PASS"},
        "2_RENEWABLE":{"pass":any(s in es for s in ren_sources) and any(s in oe for s in ren_sources),
            "evidence":f"Production energy: {params.energy_source}, Operation energy: {params.operation_energy}",
            "action":"Switch to renewable production energy (solar/wind/hydro). Design for passive operation." if not any(s in es for s in ren_sources) else "PASS"},
        "3_ACCESSIBLE":{"pass":params.is_globally_deployable,
            "evidence":f"Globally deployable: {params.is_globally_deployable}",
            "action":"Redesign for local manufacturing; remove import-only dependencies." if not params.is_globally_deployable else "PASS"},
        "4_OPEN":{"pass":params.is_patent_free and params.is_open_documentation,
            "evidence":f"Patent-free: {params.is_patent_free}, Open docs: {params.is_open_documentation}",
            "action":"Remove patent dependencies. Publish full technical documentation CC-BY-SA." if not (params.is_patent_free and params.is_open_documentation) else "PASS"},
        "5_LOCAL_FIRST":{"pass":params.local_sourcing_percent >= 50.0,
            "evidence":f"Local sourcing: {params.local_sourcing_percent}%",
            "action":f"Increase local sourcing to ≥50%. Currently {params.local_sourcing_percent}%. Identify regional alternatives." if params.local_sourcing_percent<50 else "PASS"},
        "6_CIRCULAR":{"pass":params.eol_recovery_percent >= 95.0,
            "evidence":f"EoL recovery: {params.eol_recovery_percent}%",
            "action":f"Design for ≥95% recovery. Currently {params.eol_recovery_percent}%. Use mono-materials, reversible fasteners, separation aids." if params.eol_recovery_percent<95 else "PASS"},
        "7_DURABLE":{"pass":params.design_life_years >= 20.0 and params.is_repairable and params.is_upgradeable,
            "evidence":f"Design life: {params.design_life_years}yr, Repairable: {params.is_repairable}, Upgradeable: {params.is_upgradeable}",
            "action":"Extend design life to ≥20yr. Ensure repairability (common tools). Add modular upgrade path." if params.design_life_years<20 else "PASS"}
    }
    passed=[k for k,v in principles.items() if v["pass"]]
    failed=[k for k,v in principles.items() if not v["pass"]]
    return json.dumps({"declaration":"✓ EFE FILTER PASSED — ALL 7 PRINCIPLES" if not failed else f"✗ EFE FILTER FAILED — {len(failed)} PRINCIPLES",
        "pass_count":f"{len(passed)}/7","failed_principles":failed,"principles":principles,
        "next_step":"Proceed to OPTIBEST dimension scoring." if not failed else "REDESIGN required before PREMIUM certification."}, indent=2)

class DimScoreInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    dimension: Literal["functional","efficiency","robustness","scalability","maintainability","innovation","elegance"] = Field(...)
    evidence_items: List[str] = Field(..., description="List of evidence statements")
    known_gaps: List[str] = Field(default_factory=list)
    measurements: Optional[Dict[str, Any]] = Field(None)

RUBRIC={0:"ABSENT — dimension not addressed at all",1:"DEFICIENT — addressed; known failures remain unresolved",2:"ADEQUATE — meets minimum; gaps identified and listed",3:"STRONG — meets all requirements; minor enhancement vectors remain",4:"EXCELLENT — no known enhancement vector; not yet plateau-verified",5:"PREMIUM — plateau-verified; remaining gaps proven immutable by physics/logic"}

@mcp.tool(name="frm_optibest_score", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_optibest_score(params: DimScoreInput) -> str:
    evidence_count=len(params.evidence_items); gap_count=len(params.known_gaps); has_measurements=bool(params.measurements)
    if evidence_count==0: score=0
    elif gap_count>=3 or evidence_count<2: score=1
    elif gap_count>=1 and not has_measurements: score=2
    elif gap_count>=1 and has_measurements: score=3
    elif gap_count==0 and has_measurements: score=4
    else: score=4
    note_5="Score 5 (PREMIUM) requires explicit plateau verification via frm_plateau_verify."
    enhancement_to_next={0:"Address this dimension at all — define success criteria and metrics.",1:"Resolve all known failures. Achieve 100% pass on success criteria.",2:"Add quantitative measurements. Reduce gap count to 0.",3:"Eliminate all remaining gaps. Add quantitative evidence for each claim.",4:"Run frm_plateau_verify (5 methods). If all pass, score = 5.",5:"PREMIUM achieved. No further action required."}
    return json.dumps({"dimension":params.dimension,"score":score,"label":RUBRIC[score],"evidence_count":evidence_count,"gap_count":gap_count,"has_measurements":has_measurements,"enhancement_to_next":enhancement_to_next[score],"note":note_5 if score==4 else ""}, indent=2)

class FMEAItem(BaseModel):
    component: str; failure_mode: str; effect: str
    S: int = Field(..., ge=1, le=10)
    O: int = Field(..., ge=1, le=10)
    D: int = Field(..., ge=1, le=10)
    current_mitigation: Optional[str] = Field(None)

class FMEAInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    items: List[FMEAItem] = Field(...)
    rpn_threshold: int = Field(100)

@mcp.tool(name="frm_fmea_calculate", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_fmea_calculate(params: FMEAInput) -> str:
    results=[]; critical=[]
    for item in params.items:
        rpn=item.S*item.O*item.D
        flag_rpn=rpn>params.rpn_threshold; flag_sev=item.S>=9
        needs=flag_rpn or flag_sev
        entry={"component":item.component,"failure_mode":item.failure_mode,"effect":item.effect,"S":item.S,"O":item.O,"D":item.D,"RPN":rpn,"flag_RPN_exceeds_threshold":flag_rpn,"flag_severity_9plus":flag_sev,"MITIGATION_REQUIRED":needs,"current_mitigation":item.current_mitigation or "None"}
        results.append(entry)
        if needs: critical.append(f"{item.component}/{item.failure_mode} (RPN={rpn})")
    results.sort(key=lambda x:-x["RPN"])
    passed=sum(1 for r in results if not r["MITIGATION_REQUIRED"])
    return json.dumps({"total_items":len(results),"threshold":params.rpn_threshold,"mitigation_required_count":len(critical),"passed_count":passed,"critical_items":critical,"fmea_status":"CLOSED (no open critical items)" if not critical else f"OPEN — {len(critical)} items require mitigation","sorted_by_RPN":results}, indent=2)

class ConstraintItem(BaseModel):
    constraint: str
    stated_type: str = Field("unknown")
    justification: Optional[str] = Field(None)

class ConstraintInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    constraints: List[ConstraintItem]

CONSTRAINT_KEYWORDS={"immutable":["physics","thermodynamics","conservation","speed of light","quantum","entropy","second law","first law","cannot exceed","fundamental limit","information theory"],"regulatory":["ISO","ASME","ASTM","EN","DIN","NEMA","IEC","regulation","code","standard","certification","law","legal","safety code","required by"],"practical":["current technology","budget","schedule","available tooling","skill level","manufacturing capability","lead time","supply chain"],"preferential":["aesthetic","color","brand","feels","looks","preference","style"],"negotiable":["sequencing","tooling choice","vendor","detail","implementation"]}

@mcp.tool(name="frm_constraint_classify", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_constraint_classify(params: ConstraintInput) -> str:
    results=[]
    for c in params.constraints:
        text=c.constraint.lower(); detected="NEGOTIABLE"
        for ctype, keywords in CONSTRAINT_KEYWORDS.items():
            if any(kw in text for kw in keywords): detected=ctype.upper(); break
        is_assumed_flag=(c.stated_type.lower()=="immutable" and detected not in ["IMMUTABLE","REGULATORY"])
        results.append({"constraint":c.constraint,"classified_as":detected,"ASSUMED_FLAG":is_assumed_flag,"challenge":f"Verify: is this truly {detected}? If ASSUMED, redesign to overcome." if is_assumed_flag else "","justification":c.justification})
    immutable=[r for r in results if r["classified_as"]=="IMMUTABLE"]
    assumed=[r for r in results if r["ASSUMED_FLAG"]]
    return json.dumps({"total":len(results),"immutable_count":len(immutable),"assumed_flags":len(assumed),"results":results,"note":"ASSUMED constraints are your biggest opportunity for innovation."}, indent=2)

class GapInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    phase: int = Field(..., ge=0, le=9)
    design_summary: str = Field(...)
    claimed_strengths: List[str] = Field(...)
    known_weaknesses: List[str] = Field(default_factory=list)
    dimension_scores: Optional[Dict[str,int]] = Field(None)

@mcp.tool(name="frm_gap_detect", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_gap_detect(params: GapInput) -> str:
    gaps=[]
    for strength in params.claimed_strengths:
        s=strength.lower()
        if "safe" in s or "robust" in s: gaps.append({"type":"adversarial","gap":f"Claimed '{strength}' — verify with FMEA. Has FMEA been completed with RPN<100 for all modes?","impact":"HIGH"})
        if "efficient" in s: gaps.append({"type":"adversarial","gap":f"Claimed '{strength}' — quantify: efficient by what metric vs theoretical max? What is the gap to theoretical optimum?","impact":"MEDIUM"})
        if "sustainable" in s or "efe" in s: gaps.append({"type":"adversarial","gap":f"Claimed '{strength}' — has EFE Filter been run with evidence? EoL recovery ≥95%? Design life ≥20yr?","impact":"HIGH"})
        if "simple" in s or "elegant" in s: gaps.append({"type":"adversarial","gap":f"Claimed '{strength}' — can any component be eliminated without losing function? Elegance=Purpose/Complexity, has complexity been minimised?","impact":"MEDIUM"})
    for dim,score in (params.dimension_scores or {}).items():
        if score<4: gaps.append({"type":"comparative","gap":f"{dim.upper()} score={score}/5: gap to PREMIUM. Enhancement vectors exist.","impact":"HIGH" if score<3 else "MEDIUM"})
    phase_checks={0:["Is purpose crystallised in one precise sentence?","Are success criteria quantifiable?"],1:["Have all failure modes been inventoried?","Are accessibility requirements defined?"],2:["Have ≥3 fundamentally different concepts been compared?","Has biomimicry been explored?"],3:["Has FMEA been completed?","Has every material been EFE-checked?"],4:["Is there a distributed manufacturing plan?","Is there a QC protocol?"],5:["Is EoL recovery ≥95% verified?","Is repair procedure documented?"],6:["Is enhancement delta quantified in SI units?","Are all 4 gap protocols applied?"],7:["Have all 5 plateau verification methods been applied?","Anti-gaming check complete?"],8:["Are all 9 ODF sections present?","Is traceability matrix closed?"],9:["Is certification evidence in measurements, not assertions?","Are limitations documented?"]}
    for check in phase_checks.get(params.phase, []): gaps.append({"type":"blind_spot","gap":f"Phase {params.phase} check: {check}","impact":"HIGH"})
    if not params.known_weaknesses and not gaps: gaps.append({"type":"anti_gaming","gap":"Zero gaps found on first pass — MANDATORY: run second-angle analysis. No design is perfect on first review.","impact":"CRITICAL"})
    gaps.sort(key=lambda g:{"CRITICAL":0,"HIGH":1,"MEDIUM":2,"LOW":3}.get(g["impact"],4))
    return json.dumps({"phase":params.phase,"total_gaps":len(gaps),"high_plus":sum(1 for g in gaps if g["impact"] in ["CRITICAL","HIGH"]),"gaps":gaps,"anti_gaming_note":"If first pass yields zero gaps, mandatory second-angle analysis required before claiming plateau."}, indent=2)

class DeltaInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    iteration_number: int = Field(..., ge=1)
    enhancements: List[Dict[str,Any]] = Field(...)

@mcp.tool(name="frm_enhancement_delta", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_enhancement_delta(params: DeltaInput) -> str:
    deltas=[]; total_improvements=0
    for e in params.enhancements:
        before=e.get("before",0); after=e.get("after",0); unit=e.get("unit",""); direction=e.get("direction","decrease")
        change=after-before
        improved=(change<0 and direction=="decrease") or (change>0 and direction=="increase")
        pct=abs(change/before*100) if before!=0 else 0
        if improved: total_improvements+=1
        deltas.append({"parameter":e.get("parameter"),"before":before,"after":after,"unit":unit,"change":round(change,6),"change_pct":round(pct,1),"improved":improved,"direction_required":direction})
    approaching_zero=total_improvements==0
    return json.dumps({"iteration":params.iteration_number,"enhancements_count":len(deltas),"improvements_achieved":total_improvements,"delta_items":deltas,"delta_approaching_zero":approaching_zero,"verdict":"Delta → 0 confirmed. Proceed to Phase 7 plateau verification." if approaching_zero else f"{total_improvements} improvements found. Continue iteration."}, indent=2)

class PlateauInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    iteration_count: int = Field(..., ge=1)
    final_delta_approaching_zero: bool = Field(...)
    m1_multi_attempt_results: List[str] = Field(..., min_length=3)
    m2_expert_perspective_ok: bool = Field(...)
    m2_user_perspective_ok: bool = Field(...)
    m2_maintainer_perspective_ok: bool = Field(...)
    m2_adversary_found_gap: bool = Field(...)
    m3_alternative_architecture_tried: bool = Field(...)
    m3_alternative_inferior: bool = Field(...)
    m4_gaps_explained_by_immutable_constraints: bool = Field(...)
    m4_immutable_constraint_list: List[str] = Field(...)
    m5_fresh_perspective_confirms_no_improvement: bool = Field(...)
    anti_gaming_second_angle_completed: bool = Field(...)

@mcp.tool(name="frm_plateau_verify", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_plateau_verify(params: PlateauInput) -> str:
    m1_pass=len(params.m1_multi_attempt_results)>=3 and all("no improvement" in r.lower() or "failed" in r.lower() or "rejected" in r.lower() for r in params.m1_multi_attempt_results)
    m2_pass=params.m2_expert_perspective_ok and params.m2_user_perspective_ok and params.m2_maintainer_perspective_ok and not params.m2_adversary_found_gap
    m3_pass=params.m3_alternative_architecture_tried and params.m3_alternative_inferior
    m4_pass=params.m4_gaps_explained_by_immutable_constraints and len(params.m4_immutable_constraint_list)>0
    m5_pass=params.m5_fresh_perspective_confirms_no_improvement
    anti_ok=params.anti_gaming_second_angle_completed
    methods={"M1_multi_attempt_enhancement":m1_pass,"M2_independent_perspectives":m2_pass,"M3_alternative_architecture":m3_pass,"M4_theoretical_limit":m4_pass,"M5_fresh_perspective":m5_pass}
    all_pass=all(methods.values()) and anti_ok and params.final_delta_approaching_zero
    failing=[k for k,v in methods.items() if not v]
    if not anti_ok: failing.append("ANTI_GAMING_SECOND_ANGLE_NOT_COMPLETED")
    return json.dumps({"plateau_status":"✓ PLATEAU VERIFIED — PROCEED TO CERTIFICATION" if all_pass else "✗ PLATEAU NOT CONFIRMED","iterations_completed":params.iteration_count,"methods":methods,"anti_gaming_complete":anti_ok,"all_pass":all_pass,"failing_methods":failing,"next_step":"Run frm_optibest_certify" if all_pass else f"Address failing methods: {failing}"}, indent=2)

class CalibInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    task_description: str = Field(...)
    deployment_scale: Literal["household","community","regional","global","infrastructure"] = Field(...)
    irreversible: bool = Field(False); safety_critical: bool = Field(False)
    estimated_hours: Optional[float] = Field(None)

@mcp.tool(name="frm_dual_axis_calibrate", annotations={"readOnlyHint":True,"idempotentHint":True})
async def frm_dual_axis_calibrate(params: CalibInput) -> str:
    h=params.estimated_hours or 0
    if h<1: mag="MICRO"
    elif h<8: mag="MESO"
    elif h<40: mag="STANDARD"
    elif h<160: mag="COMPLEX"
    else: mag="MACRO"
    scale_weight={"household":1,"community":2,"regional":3,"global":4,"infrastructure":5}
    mag_weight={"MICRO":1,"MESO":2,"STANDARD":3,"COMPLEX":4,"MACRO":5}
    combined=max(scale_weight[params.deployment_scale], mag_weight[mag])
    rigor=("MICRO_LITE" if combined<=1 else("STANDARD" if combined<=3 else("FULL" if combined<=4 else"ULTRA")))
    if params.safety_critical or params.irreversible: rigor="FULL" if rigor!="ULTRA" else "ULTRA"
    iter_targets={"MICRO_LITE":"1-2","STANDARD":"2-5","FULL":"5-10","ULTRA":"10+"}
    phases_req={"MICRO_LITE":"Phases 0,1,3,6,8","STANDARD":"All 9 phases","FULL":"All 9 + full 5-method verification","ULTRA":"All 9 + adversarial stress + theoretical limit"}
    return json.dumps({"task":params.task_description[:80],"magnitude":mag,"scale":params.deployment_scale,"rigor":rigor,"iteration_target":iter_targets[rigor],"phases_required":phases_req[rigor],"safety_critical":params.safety_critical,"irreversible":params.irreversible}, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")
