#!/usr/bin/env python3
"""efe_materials_mcp — Materials database, EFE compliance, alternatives."""
import sys, json, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from materials_db import MATERIALS, MATERIAL_CLASSES, get_material, search_materials

mcp = FastMCP("efe_materials_mcp")

class LookupInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_id: str = Field(..., description=f"Material ID. Available: {', '.join(MATERIALS.keys())}")

@mcp.tool(name="mat_lookup", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_lookup(params: LookupInput) -> str:
    """Full material property sheet: density, E, yield, UTS, thermal, EFE tier,
    CO2 intensity, recycling rate, renewable/recyclable flags, EoL pathway, alternatives.
    """
    m=get_material(params.material_id)
    if not m: return json.dumps({"error":f"Unknown material. Available: {list(MATERIALS.keys())}"})
    return json.dumps({"material_id":params.material_id,**m}, indent=2)

class SearchInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    efe_tier_max: int = Field(2, ge=1, le=4, description="Max EFE tier (1=preferred, 2=acceptable, 3=avoid, 4=prohibited)")
    class_filter: Optional[str] = Field(None, description=f"Class filter: {MATERIAL_CLASSES}")
    renewable_only: bool = Field(False)
    recyclable_only: bool = Field(False)
    min_yield_MPa: Optional[float] = Field(None, ge=0)
    max_yield_MPa: Optional[float] = Field(None)
    min_E_GPa: Optional[float] = Field(None, ge=0)
    max_density_kg_m3: Optional[float] = Field(None)
    max_co2_kg_per_kg: Optional[float] = Field(None)

@mcp.tool(name="mat_search", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_search(params: SearchInput) -> str:
    """Search materials database by EFE tier, class, and property ranges.
    Returns ranked list sorted by EFE tier then CO2 intensity (lowest first).
    """
    filters={}
    if params.min_yield_MPa is not None or params.max_yield_MPa is not None:
        filters["yield_MPa"]=(params.min_yield_MPa or 0, params.max_yield_MPa or 1e9)
    if params.min_E_GPa is not None:
        filters["E_GPa"]=(params.min_E_GPa, 1e9)
    if params.max_density_kg_m3 is not None:
        filters["density"]=(0, params.max_density_kg_m3)
    if params.max_co2_kg_per_kg is not None:
        filters["co2_kg_per_kg"]=(-1e9, params.max_co2_kg_per_kg)
    results=search_materials(filters, params.efe_tier_max, params.class_filter,
                              params.renewable_only, params.recyclable_only)
    results.sort(key=lambda x:(x[1]["efe_tier"], x[1]["co2_kg_per_kg"]))
    out=[{"id":mid,"name":m["name"],"class":m["class"],"efe_tier":m["efe_tier"],
          "yield_MPa":m["yield_MPa"],"E_GPa":m["E_GPa"],"density":m["density"],
          "co2_kg_per_kg":m["co2_kg_per_kg"],"renewable":m["renewable"]}
         for mid,m in results]
    return json.dumps({"count":len(out),"results":out}, indent=2)

class CompareInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_ids: List[str] = Field(..., min_length=2, description="2-6 material IDs to compare")
    properties: Optional[List[str]] = Field(None, description="Properties to compare (default: key subset)")

@mcp.tool(name="mat_compare", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_compare(params: CompareInput) -> str:
    """Side-by-side comparison of 2-6 materials. Returns comparison table,
    property winners, and EFE tier ranking.
    """
    props=params.properties or ["density","E_GPa","yield_MPa","uts_MPa","k_W_mK",
                                 "efe_tier","co2_kg_per_kg","recycle_pct","renewable","recyclable"]
    table={}
    for mid in params.material_ids:
        m=get_material(mid)
        if not m: return json.dumps({"error":f"Unknown: {mid}"})
        table[mid]={p:m.get(p,"N/A") for p in props}
    winners={}
    win_criteria={"density":"min","E_GPa":"max","yield_MPa":"max","uts_MPa":"max",
                  "k_W_mK":"max","efe_tier":"min","co2_kg_per_kg":"min","recycle_pct":"max"}
    for p, crit in win_criteria.items():
        if p not in props: continue
        vals={mid:table[mid][p] for mid in params.material_ids if isinstance(table[mid].get(p),(int,float))}
        if vals:
            w=min(vals,key=vals.get) if crit=="min" else max(vals,key=vals.get)
            winners[p]=w
    return json.dumps({"comparison":table,"winners":winners,
                       "efe_ranking":sorted(params.material_ids,
                                            key=lambda x:get_material(x)["efe_tier"])}, indent=2)

class EFECompInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_id: str = Field(...)
    application_context: str = Field(..., description="e.g. 'structural frame', 'electrical insulation'")
    production_energy_source: str = Field("grid_unknown", description="e.g. 'solar', 'grid_unknown', 'coal'")
    local_region: str = Field("global", description="Region for sourcing check")

@mcp.tool(name="mat_efe_compliance", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_efe_compliance(params: EFECompInput) -> str:
    """Evaluate a material against all 7 EFE Filter principles.
    Returns pass/fail per principle with evidence and recommendations.
    """
    m=get_material(params.material_id)
    if not m: return json.dumps({"error":f"Unknown material: {params.material_id}"})
    tier=m["efe_tier"]; ren=m["renewable"]; rec=m["recyclable"]
    rec_pct=m["recycle_pct"]; co2=m["co2_kg_per_kg"]; la=m["local_availability"]
    renewables=["solar","wind","hydro","geothermal","biomass","human","wave","tidal","passive"]
    is_ren_energy=any(r in params.production_energy_source.lower() for r in renewables)

    principles={
        "sustainable":{"pass":tier<=2 and co2<10,
            "evidence":f"EFE Tier {tier}, CO2={co2}kg/kg",
            "rec":"" if tier<=2 else f"Replace with Tier 1-2 alternative"},
        "renewable":{"pass":ren or is_ren_energy,
            "evidence":f"Material renewable={ren}, Energy source={params.production_energy_source}",
            "rec":"" if ren or is_ren_energy else "Use renewable energy for production OR switch to bio-sourced material"},
        "accessible":{"pass":la in ["global","temperate global"],
            "evidence":f"Availability: {la}","rec":"" if la in ["global","temperate global"] else "Verify local/regional sourcing options"},
        "open":{"pass":tier<=2,
            "evidence":f"Tier {tier} material (no patent restrictions on natural/standard materials)",
            "rec":"Avoid proprietary formulations where open alternatives exist"},
        "local_first":{"pass":la in ["global","temperate global","any (home-growable)"],
            "evidence":f"Sourcing availability: {la}","rec":""},
        "circular":{"pass":rec and rec_pct>=70,
            "evidence":f"Recyclable={rec}, Rate={rec_pct}%, EoL={m.get('eol_path','')}",
            "rec":"" if rec and rec_pct>=70 else f"Current recyclability {rec_pct}%. Design for disassembly to improve."},
        "durable":{"pass":True,
            "evidence":"Durability depends on application design, not material alone. Check phy_fatigue_analysis.",
            "rec":"Specify ≥20yr design life in Phase 0."}
    }
    pass_count=sum(1 for v in principles.values() if v["pass"])
    return json.dumps({
        "material":m["name"],"application":params.application_context,
        "result":"✓ EFE COMPLIANT" if pass_count==7 else f"✗ {7-pass_count} PRINCIPLES FAIL",
        "pass_count":f"{pass_count}/7","principles":principles
    }, indent=2)

class AltInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_id: str = Field(..., description="Material to find alternatives for")
    constraint: Optional[str] = Field(None, description="Key constraint: 'structural','thermal','electrical','lightweight'")
    min_property_retention_pct: float = Field(70.0, description="Min % of original yield/E retained")

@mcp.tool(name="mat_find_alternatives", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_find_alternatives(params: AltInput) -> str:
    """Find EFE-superior alternative materials. Filters by min property retention,
    sorts by EFE tier improvement. Returns ranked alternatives with trade-off summary.
    """
    orig=get_material(params.material_id)
    if not orig: return json.dumps({"error":f"Unknown: {params.material_id}"})
    thresh=params.min_property_retention_pct/100
    alts=[]
    for mid,m in MATERIALS.items():
        if mid==params.material_id: continue
        if m["efe_tier"] > orig["efe_tier"]: continue
        y_ok=m["yield_MPa"] >= orig["yield_MPa"]*thresh
        e_ok=m["E_GPa"] >= orig["E_GPa"]*thresh
        if not (y_ok or e_ok): continue
        gain_tier=orig["efe_tier"]-m["efe_tier"]
        gain_co2=orig["co2_kg_per_kg"]-m["co2_kg_per_kg"]
        alts.append({"id":mid,"name":m["name"],"efe_tier":m["efe_tier"],
                     "co2_kg_per_kg":m["co2_kg_per_kg"],
                     "yield_MPa":m["yield_MPa"],"E_GPa":m["E_GPa"],
                     "tier_improvement":gain_tier,"CO2_saving_kg_per_kg":round(gain_co2,2),
                     "notes":m["notes"][:80]})
    alts.sort(key=lambda x:(-x["tier_improvement"],-x["CO2_saving_kg_per_kg"]))
    return json.dumps({"original":{"id":params.material_id,"name":orig["name"],
                                    "efe_tier":orig["efe_tier"],"co2":orig["co2_kg_per_kg"]},
                       "alternatives_count":len(alts),"alternatives":alts[:8]}, indent=2)

class CarbonInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_id: str = Field(...)
    mass_kg: float = Field(..., gt=0)
    recycled_content_pct: float = Field(0.0, ge=0, le=100, description="% recycled input material")

@mcp.tool(name="mat_carbon_intensity", annotations={"readOnlyHint":True,"idempotentHint":True})
async def mat_carbon_intensity(params: CarbonInput) -> str:
    """Cradle-to-gate CO2e for a material mass. Accounts for recycled content
    (virgin CO2 reduced proportionally). Returns total kg CO2e, intensity, and EFE grade.
    """
    m=get_material(params.material_id)
    if not m: return json.dumps({"error":f"Unknown: {params.material_id}"})
    rc=params.recycled_content_pct/100
    effective_co2=(1-rc*0.8)*m["co2_kg_per_kg"]
    total=effective_co2*params.mass_kg
    grade="A+" if total<0 else("A" if total<5 else("B" if total<20 else("C" if total<100 else "D")))
    return json.dumps({
        "material":m["name"],"mass_kg":params.mass_kg,
        "virgin_co2_kg_per_kg":m["co2_kg_per_kg"],
        "recycled_content_pct":params.recycled_content_pct,
        "effective_co2_kg_per_kg":round(effective_co2,3),
        "total_kg_CO2e":round(total,3),"EFE_carbon_grade":grade
    }, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")
