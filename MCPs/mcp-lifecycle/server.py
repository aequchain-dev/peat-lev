#!/usr/bin/env python3
"""efe_lifecycle_mcp — LCA, circularity, durability, repair index, carbon budget."""
import sys, json, math, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Dict, Optional, Literal
from materials_db import get_material

mcp = FastMCP("efe_lifecycle_mcp")

ENERGY_CO2 = {
    "solar_pv": 0.020, "wind": 0.011, "hydro": 0.024, "nuclear": 0.012,
    "grid_renewable": 0.050, "grid_eu_average": 0.256, "grid_za": 0.780,
    "grid_us": 0.386, "grid_unknown": 0.450, "coal": 0.820, "gas": 0.490,
    "diesel_gen": 0.720, "biomass": 0.230
}

class LCAInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    product_name: str = Field(...)
    material_breakdown: List[Dict] = Field(...)
    manufacturing_energy_kWh: float = Field(..., ge=0)
    manufacturing_energy_source: str = Field("grid_unknown")
    transport_distance_km: float = Field(0.0, ge=0)
    transport_mass_kg: float = Field(0.0, ge=0)
    use_energy_kWh_per_year: float = Field(0.0, ge=0)
    use_energy_source: str = Field("grid_unknown")
    design_life_years: float = Field(20.0, gt=0)
    eol_recovery_pct: float = Field(80.0, ge=0, le=100)

@mcp.tool(name="lca_quick", annotations={"readOnlyHint":True,"idempotentHint":True})
async def lca_quick(params: LCAInput) -> str:
    mat_co2=0.0; total_mass=0; mat_detail=[]
    for entry in params.material_breakdown:
        mid=entry.get("material_id"); mass=float(entry.get("mass_kg",0)); rc=float(entry.get("recycled_content_pct",0))/100
        m=get_material(mid)
        base_co2 = m["co2_kg_per_kg"] if m else 2.0
        eff_co2=(1-rc*0.8)*base_co2*mass
        mat_co2+=eff_co2; total_mass+=mass
        mat_detail.append({"material_id":mid,"mass_kg":mass,"kg_CO2e":round(eff_co2,2)})
    mfg_factor=ENERGY_CO2.get(params.manufacturing_energy_source,0.45)
    mfg_co2=params.manufacturing_energy_kWh*mfg_factor
    trans_co2=params.transport_distance_km*params.transport_mass_kg*0.062/1000
    use_factor=ENERGY_CO2.get(params.use_energy_source,0.45)
    use_co2=params.use_energy_kWh_per_year*params.design_life_years*use_factor
    avg_mat_co2=mat_co2/total_mass if total_mass>0 else 2.0
    eol_credit=(params.eol_recovery_pct/100)*total_mass*avg_mat_co2*0.5
    net_eol=trans_co2*0.1 - eol_credit
    total=mat_co2+mfg_co2+trans_co2+use_co2+net_eol
    per_year=total/params.design_life_years
    grade="A+" if total<0 else("A" if per_year<5 else("B" if per_year<20 else("C" if per_year<100 else "D")))
    efe_pass=total<0 or (per_year<50 and params.eol_recovery_pct>=90)
    return json.dumps({"product":params.product_name,"design_life_years":params.design_life_years,
        "stages_kg_CO2e":{"materials":round(mat_co2,2),"manufacturing":round(mfg_co2,2),"transport":round(trans_co2,2),"use_phase":round(use_co2,2),"end_of_life":round(net_eol,2)},
        "total_kg_CO2e":round(total,2),"per_year_kg_CO2e":round(per_year,2),"per_kg_product_CO2e":round(total/total_mass,3) if total_mass>0 else None,
        "material_breakdown":mat_detail,"carbon_grade":grade,"EFE_carbon_pass":efe_pass}, indent=2)

class CircularityInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    bom_items: List[Dict] = Field(...)
    hazardous_waste_kg: float = Field(0.0, ge=0)
    packaging_mass_kg: float = Field(0.0, ge=0)
    packaging_recyclable: bool = Field(True)

@mcp.tool(name="lca_circularity", annotations={"readOnlyHint":True,"idempotentHint":True})
async def lca_circularity(params: CircularityInput) -> str:
    total=sum(i["mass_kg"] for i in params.bom_items)+params.packaging_mass_kg
    rec_mass=0; haz_mass=params.hazardous_waste_kg
    for item in params.bom_items:
        m=get_material(item.get("material_id",""))
        is_rec=item.get("recyclable", m["recyclable"] if m else False)
        if is_rec: rec_mass+=item["mass_kg"]
    if params.packaging_recyclable: rec_mass+=params.packaging_mass_kg
    rec_pct=rec_mass/total*100 if total>0 else 0
    haz_pct=haz_mass/total*100 if total>0 else 0
    efe_circ_pass=rec_pct>=95 and haz_pct==0
    score=min(100, rec_pct*(1-haz_pct/100))
    return json.dumps({"total_mass_kg":round(total,3),"recyclable_mass_kg":round(rec_mass,3),"recyclable_pct":round(rec_pct,1),"hazardous_pct":round(haz_pct,2),"circular_score_0_100":round(score,1),"EFE_circular_pass":efe_circ_pass,"gap": "PASS" if efe_circ_pass else f"Need ≥95% recovery (current {round(rec_pct,1)}%) AND 0% hazardous. Redesign."}, indent=2)

class RepairInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    fastener_types: List[str] = Field(...)
    module_count: int = Field(..., ge=1)
    special_tools_required: bool = Field(False)
    spare_parts_locally_available: bool = Field(True)
    disassembly_steps: int = Field(..., ge=1)
    documentation_quality: Literal["none","poor","adequate","good","excellent"] = Field("adequate")

@mcp.tool(name="lca_repair_index", annotations={"readOnlyHint":True,"idempotentHint":True})
async def lca_repair_index(params: RepairInput) -> str:
    score=10.0
    bad_fasteners=sum(1 for f in params.fastener_types if any(b in f.lower() for b in ["adhesive","glue","snap","rivet","weld","solder"]))
    score-=bad_fasteners*1.5
    if params.disassembly_steps>20: score-=2
    elif params.disassembly_steps>10: score-=1
    if params.special_tools_required: score-=2
    if not params.spare_parts_locally_available: score-=1.5
    if params.module_count>=4: score+=0.5
    doc_bonus={"none":-2,"poor":-1,"adequate":0,"good":0.5,"excellent":1}
    score+=doc_bonus[params.documentation_quality]
    score=max(0,min(10,score))
    grade="EXCELLENT" if score>=8 else("GOOD" if score>=7 else("FAIR" if score>=5 else("POOR" if score>=3 else "CRITICAL")))
    efe_pass=score>=7
    return json.dumps({"repair_index":round(score,1),"grade":grade,"EFE_durable_pass":efe_pass,"issues":{"bad_fasteners":bad_fasteners,"special_tools":params.special_tools_required,"parts_unavailable":not params.spare_parts_locally_available,"high_step_count":params.disassembly_steps>10},"recommendations":[] if efe_pass else ["Replace adhesive/snap with M3-M8 bolts" if bad_fasteners else None,"Eliminate special tools — design for Phillips/hex only" if params.special_tools_required else None,"Make spare parts available locally or on open licence" if not params.spare_parts_locally_available else None,"Reduce disassembly steps to <10" if params.disassembly_steps>10 else None]}, indent=2)

class CarbonBudgetInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    material_kg_CO2e: float = Field(...)
    manufacturing_kg_CO2e: float = Field(...)
    transport_kg_CO2e: float = Field(0.0)
    use_phase_kg_CO2e: float = Field(...)
    eol_kg_CO2e: float = Field(0.0)
    sequestration_kg_CO2e: float = Field(0.0, ge=0)

@mcp.tool(name="lca_carbon_budget", annotations={"readOnlyHint":True,"idempotentHint":True})
async def lca_carbon_budget(params: CarbonBudgetInput) -> str:
    total=(params.material_kg_CO2e + params.manufacturing_kg_CO2e + params.transport_kg_CO2e + params.use_phase_kg_CO2e + params.eol_kg_CO2e - params.sequestration_kg_CO2e)
    stages={"materials":params.material_kg_CO2e,"manufacturing":params.manufacturing_kg_CO2e,"transport":params.transport_kg_CO2e,"use_phase":params.use_phase_kg_CO2e,"eol":params.eol_kg_CO2e,"sequestration":-params.sequestration_kg_CO2e}
    total_pos=sum(v for v in stages.values() if v>0)
    pcts={k:round(v/total_pos*100,1) if total_pos>0 else 0 for k,v in stages.items()}
    dominant=max(stages,key=lambda k:stages[k]) if total>0 else "sequestration"
    grade="A+" if total<0 else("A" if total<10 else("B" if total<100 else("C" if total<1000 else "D")))
    return json.dumps({"total_net_kg_CO2e":round(total,2),"carbon_negative":total<0,"carbon_grade":grade,"stages_kg_CO2e":stages,"stage_pct_of_gross":pcts,"dominant_stage":dominant,"priority_reduction":dominant if total>0 else "NONE — carbon negative"}, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")
