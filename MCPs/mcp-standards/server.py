#!/usr/bin/env python3
"""efe_standards_mcp — ISO tolerances, safety factors, fastener specs, surface finish, codes."""
import json
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Literal

mcp = FastMCP("efe_standards_mcp")

ISO_FITS = {
    "H7/f6":{"name":"Running clearance","type":"clearance","description":"Precision shafts, bearings","clearance_range":"0 to +upper"},
    "H7/g6":{"name":"Close running","type":"clearance","description":"Precision sliding fits"},
    "H7/h6":{"name":"Sliding","type":"clearance","description":"Close sliding, spigots"},
    "H7/k6":{"name":"Push fit","type":"transition","description":"Locating, easily assembled by hand"},
    "H7/n6":{"name":"Press fit (light)","type":"interference","description":"Permanent assembly, light press"},
    "H7/p6":{"name":"Press fit (medium)","type":"interference","description":"Standard press fit"},
    "H7/s6":{"name":"Shrink fit","type":"interference","description":"Permanent, heat-assisted assembly"},
    "H8/d9":{"name":"Easy clearance","type":"clearance","description":"Loose fits, agricultural, shaft seals"},
    "H9/d9":{"name":"Free running","type":"clearance","description":"Widely used for free-running fits"},
}

def iso_tolerance_um(nominal_mm: float, IT: int) -> float:
    D = (nominal_mm * 1.0)**0.333
    return round(10**((2.5+IT/5))*0.45*(D) * 1.5, 1)

SAFETY_FACTORS = {
    "ductile_static_benign":{"min":1.25,"typical":1.5,"note":"Well-understood load, ductile, low consequence"},
    "ductile_static_standard":{"min":1.5,"typical":2.0,"note":"Normal structural steel, standard load"},
    "ductile_dynamic":{"min":1.5,"typical":2.5,"note":"Fatigue loading, ductile material"},
    "brittle_static":{"min":2.0,"typical":3.0,"note":"Cast iron, ceramics, static load"},
    "pressure_vessel_asme":{"min":3.0,"typical":3.5,"note":"ASME Sec VIII Div 1 (vs UTS)"},
    "lifting_gear_forged":{"min":4.0,"typical":5.0,"note":"Hooks, slings, crane components"},
    "aerospace_primary_structure":{"min":1.4,"typical":1.5,"note":"Mil-Spec, well-characterised loads"},
    "timber_structural":{"min":2.5,"typical":3.0,"note":"AS/NZS 1720, variability in wood"},
    "concrete_structural":{"min":1.5,"typical":1.7,"note":"Eurocode 2 γ_c partial factor"},
    "impact_load_ductile":{"min":2.0,"typical":3.0,"note":"Dynamic factor already applied"},
    "bio_natural_materials":{"min":3.0,"typical":4.0,"note":"Higher variability in natural fibre/bamboo"},
    "offshore_corrosive":{"min":2.0,"typical":2.5,"note":"Combined corrosion + dynamic"},
    "seismic":{"min":1.5,"typical":2.0,"note":"After applying seismic load combos"},
}

FASTENERS = {
    "M3":{"pitch":0.5,"head_hex_mm":5.5,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":1.0,"shear_MPa":490},
    "M4":{"pitch":0.7,"head_hex_mm":7.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":2.4,"shear_MPa":490},
    "M5":{"pitch":0.8,"head_hex_mm":8.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":4.8,"shear_MPa":490},
    "M6":{"pitch":1.0,"head_hex_mm":10.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":8.2,"shear_MPa":490},
    "M8":{"pitch":1.25,"head_hex_mm":13.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":20.0,"shear_MPa":490},
    "M10":{"pitch":1.5,"head_hex_mm":17.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":40.0,"shear_MPa":490},
    "M12":{"pitch":1.75,"head_hex_mm":19.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":68.0,"shear_MPa":490},
    "M16":{"pitch":2.0,"head_hex_mm":24.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":165.0,"shear_MPa":490},
    "M20":{"pitch":2.5,"head_hex_mm":30.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":330.0,"shear_MPa":490},
    "M24":{"pitch":3.0,"head_hex_mm":36.0,"proof_8_8":580,"uts_8_8":830,"torque_8_8_Nm":560.0,"shear_MPa":490},
}

SURFACE_FINISH = {
    "mirror_polished":{"Ra_um":(0.006,0.025),"process":["superfinishing","lapping"],"use":"optical, seals"},
    "ground":{"Ra_um":(0.025,0.4),"process":["cylindrical grinding","surface grinding"],"use":"bearing races, precision fits"},
    "turned_fine":{"Ra_um":(0.4,1.6),"process":["fine turning","boring"],"use":"running fits, most machined parts"},
    "milled":{"Ra_um":(0.8,6.3),"process":["end milling","face milling"],"use":"general machined surfaces"},
    "shaped_planed":{"Ra_um":(1.6,12.5),"process":["shaping","planning"],"use":"general structural"},
    "hot_rolled":{"Ra_um":(12.5,50),"process":["rolling"],"use":"structural steel as-rolled"},
    "sand_cast":{"Ra_um":(6.3,25),"process":["sand casting"],"use":"cast housings, non-critical"},
    "3d_printed_fdm":{"Ra_um":(12,50),"process":["FDM","FFF"],"use":"prototypes, jigs, non-critical"},
    "3d_printed_resin":{"Ra_um":(0.5,5),"process":["SLA","MSLA","DLP"],"use":"precise prototypes"},
    "bamboo_planed":{"Ra_um":(0.8,3.2),"process":["planing","sanding"],"use":"EFE natural material surfaces"},
}

class ToleranceInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    nominal_mm: float = Field(..., gt=0)
    fit_code: str = Field(...)
    component: Literal["hole","shaft","both"] = Field("both")

@mcp.tool(name="std_iso_tolerance", annotations={"readOnlyHint":True,"idempotentHint":True})
async def std_iso_tolerance(params: ToleranceInput) -> str:
    fit=ISO_FITS.get(params.fit_code)
    if not fit: return json.dumps({"error":f"Unknown fit. Options: {list(ISO_FITS.keys())}"})
    it7=iso_tolerance_um(params.nominal_mm,7); it6=iso_tolerance_um(params.nominal_mm,6)
    return json.dumps({"fit":params.fit_code,"nominal_mm":params.nominal_mm,"fit_name":fit["name"],"fit_type":fit["type"],"description":fit["description"],"approx_tolerances_um":{"hole_IT7":it7,"shaft_IT6":it6},"note":"Use ISO 286 tables for exact deviations. These are approximate IT grade values."}, indent=2)

class SFInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    application: str = Field(...)

@mcp.tool(name="std_safety_factor", annotations={"readOnlyHint":True,"idempotentHint":True})
async def std_safety_factor(params: SFInput) -> str:
    sf=SAFETY_FACTORS.get(params.application)
    if not sf: return json.dumps({"error":f"Unknown application. Options: {list(SAFETY_FACTORS.keys())}"})
    return json.dumps({"application":params.application,**sf}, indent=2)

class FastenerInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    size: str = Field(...)
    grade: str = Field("8.8")

GRADE_FACTORS={"4.6":0.5,"8.8":1.0,"10.9":1.27,"12.9":1.47,"A2-70":0.78}

@mcp.tool(name="std_fastener_specs", annotations={"readOnlyHint":True,"idempotentHint":True})
async def std_fastener_specs(params: FastenerInput) -> str:
    f=FASTENERS.get(params.size)
    if not f: return json.dumps({"error":f"Unknown size. Options: {list(FASTENERS.keys())}"})
    gf=GRADE_FACTORS.get(params.grade,1.0)
    return json.dumps({"size":params.size,"grade":params.grade,"thread_pitch_mm":f["pitch"],"head_hex_mm":f["head_hex_mm"],"proof_strength_MPa":round(f["proof_8_8"]*gf),"uts_MPa":round(f["uts_8_8"]*gf),"recommended_torque_Nm":round(f["torque_8_8_Nm"]*gf,1),"shear_strength_MPa":round(f["shear_MPa"]*gf),"efe_note":"Prefer stainless (A2-70/A4-80) for corrosion/recyclability. Phosphate steel (grade 8.8) second choice."}, indent=2)

class SurfaceInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    surface_name: Optional[str] = Field(None)
    required_Ra_um: Optional[float] = Field(None, gt=0)

@mcp.tool(name="std_surface_finish", annotations={"readOnlyHint":True,"idempotentHint":True})
async def std_surface_finish(params: SurfaceInput) -> str:
    if params.surface_name:
        sf=SURFACE_FINISH.get(params.surface_name)
        if not sf: return json.dumps({"error":f"Unknown surface. Options: {list(SURFACE_FINISH.keys())}"})
        return json.dumps({"surface":params.surface_name,**sf}, indent=2)
    elif params.required_Ra_um:
        Ra=params.required_Ra_um
        matches={k:v for k,v in SURFACE_FINISH.items() if v["Ra_um"][0]<=Ra<=v["Ra_um"][1]}
        return json.dumps({"required_Ra_um":Ra,"suitable_processes":matches}, indent=2)
    return json.dumps({"error":"Provide surface_name or required_Ra_um"})

if __name__ == "__main__":
    mcp.run(transport="stdio")
