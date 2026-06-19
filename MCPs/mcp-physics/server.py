#!/usr/bin/env python3
"""efe_physics_mcp — Engineering physics calculator: beam, stress, fatigue,
pressure vessel, buckling, heat conduction, convection, pipe flow,
spring, gear, electrical, impact."""
import sys, math, json
sys.path.insert(0, "/var/home/ryan/.local/share/efe-mcps/shared")

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Literal, List

mcp = FastMCP("efe_physics_mcp")

# ─────────────────────────────────────────────────────────────────────────────
# BEAM ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
class BeamInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    beam_type: Literal["simply_supported","cantilever","fixed_fixed","propped_cantilever"] = Field(...)
    span_m: float = Field(..., gt=0, description="Beam span (m)")
    load_type: Literal["udl","point_center","point_end","point_half"] = Field(...)
    load_magnitude: float = Field(..., gt=0, description="N/m for udl; N for point loads")
    section_type: Literal["rectangular","circular","hollow_circular","i_beam","custom"] = Field("rectangular")
    width_mm: Optional[float] = Field(None, gt=0)
    height_mm: Optional[float] = Field(None, gt=0)
    diameter_mm: Optional[float] = Field(None, gt=0)
    inner_diameter_mm: Optional[float] = Field(None, gt=0)
    flange_thickness_mm: Optional[float] = Field(None, gt=0)
    web_thickness_mm: Optional[float] = Field(None, gt=0)
    I_custom_m4: Optional[float] = Field(None, gt=0)
    Z_custom_m3: Optional[float] = Field(None, gt=0)
    youngs_modulus_GPa: float = Field(200.0, gt=0, description="GPa (steel=200, Al=69, conc=30)")
    yield_strength_MPa: float = Field(250.0, gt=0, description="MPa yield for safety factor")
    deflection_limit: Literal["L/360","L/300","L/250","L/200","none"] = Field("L/360")

@mcp.tool(name="phy_beam_analysis", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_beam_analysis(params: BeamInput) -> str:
    """Beam bending: max moment (kNm), shear (kN), deflection (mm),
    bending stress (MPa), safety factor.
    """
    L = params.span_m
    E = params.youngs_modulus_GPa * 1e9
    w = params.load_magnitude
    s = params.section_type
    if s == "rectangular":
        b = (params.width_mm or 50.0)/1000; h = (params.height_mm or 100.0)/1000
        I = b*h**3/12; Z = b*h**2/6; y = h/2
    elif s == "circular":
        d = (params.diameter_mm or 50.0)/1000
        I = math.pi*d**4/64; Z = math.pi*d**3/32; y = d/2
    elif s == "hollow_circular":
        D = (params.diameter_mm or 60.0)/1000
        di = (params.inner_diameter_mm or 50.0)/1000
        I = math.pi*(D**4-di**4)/64; Z = math.pi*(D**4-di**4)/(32*D); y = D/2
    elif s == "i_beam":
        B=(params.width_mm or 150.0)/1000; H=(params.height_mm or 200.0)/1000
        tf=(params.flange_thickness_mm or 10.0)/1000; tw=(params.web_thickness_mm or 6.0)/1000
        hw=H-2*tf
        I=(B*H**3/12)-((B-tw)*hw**3/12); Z=I/(H/2); y=H/2
    else:
        I = params.I_custom_m4 or 1e-6
        Z = params.Z_custom_m3 or (I/0.05)
        y = I/Z
    bt = params.beam_type; lt = params.load_type
    M=V=delta=0.0
    if bt=="simply_supported":
        if lt=="udl":
            M=w*L**2/8; V=w*L/2; delta=5*w*L**4/(384*E*I)
        elif lt=="point_center":
            M=w*L/4; V=w/2; delta=w*L**3/(48*E*I)
        elif lt=="point_half":
            a=L/2; b2=L/2; M=w*a*b2/L; V=w*b2/L
            delta=w*a*b2*(L+b2)*math.sqrt(max(0,3*a*(L+b2)))/(27*E*I*L) if L>0 else 0
        else:
            a=3*L/4; b2=L/4; M=w*a*b2/L; V=w*b2/L; delta=w*a**2*b2**2/(3*E*I*L)
    elif bt=="cantilever":
        if lt=="udl":
            M=w*L**2/2; V=w*L; delta=w*L**4/(8*E*I)
        elif lt in ("point_center","point_end"):
            M=w*L; V=w; delta=w*L**3/(3*E*I)
        else:
            a=L/2; M=w*a; V=w; delta=w*a**2*(3*L-a)/(6*E*I)
    elif bt=="fixed_fixed":
        if lt=="udl":
            M=w*L**2/12; V=w*L/2; delta=w*L**4/(384*E*I)
        else:
            M=w*L/8; V=w/2; delta=w*L**3/(192*E*I)
    else:
        if lt=="udl":
            M=9*w*L**2/128; V=5*w*L/8; delta=w*L**4/(185*E*I)
        else:
            M=3*w*L/16; V=11*w/16; delta=w*L**3/(107*E*I)
    sigma_b = M*y/I if I>0 else 0
    SF = (params.yield_strength_MPa*1e6)/sigma_b if sigma_b>0 else 999
    defl_mm = delta*1000
    ratio = int(L/delta) if delta>1e-15 else 999999
    lim_map={"L/360":360,"L/300":300,"L/250":250,"L/200":200,"none":0}
    lim=lim_map[params.deflection_limit]
    d_status = "PASS" if (lim==0 or ratio>=lim) else "FAIL"
    s_status = "PASS" if SF>=1.5 else ("MARGINAL" if SF>=1.0 else "FAIL")
    return json.dumps({
        "section":{"I_m4":I,"Z_m3":Z,"y_max_mm":y*1000},
        "results":{"max_moment_kNm":round(M/1000,4),"max_shear_kN":round(V/1000,4),
                   "max_deflection_mm":round(defl_mm,4),"bending_stress_MPa":round(sigma_b/1e6,3)},
        "safety":{"SF":round(SF,2),"sf_status":s_status,
                  "deflection":f"L/{ratio}","defl_status":d_status},
        "summary":f"M_max={round(M/1000,3)}kNm SF={round(SF,2)} {s_status} | δ=L/{ratio} {d_status}"
    }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# STRESS ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
class StressInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    axial_force_N: float = Field(0.0, description="Axial force (N, + = tension)")
    shear_force_N: float = Field(0.0, description="Transverse shear (N)")
    moment_Nm: float = Field(0.0, description="Bending moment (N·m)")
    torsion_Nm: float = Field(0.0, description="Torsional moment (N·m)")
    cross_section_area_m2: float = Field(..., gt=0, description="Cross-section area (m²)")
    section_modulus_m3: float = Field(..., gt=0, description="Section modulus Z = I/y (m³)")
    polar_modulus_m3: Optional[float] = Field(None, description="Polar section modulus Zp = J/r (m³)")
    yield_strength_MPa: float = Field(250.0, gt=0, description="Material yield strength (MPa)")
    load_safety_factor_applied: float = Field(1.0, gt=0, description="Applied load factor")

@mcp.tool(name="phy_stress_analysis", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_stress_analysis(params: StressInput) -> str:
    """Combined stress analysis: axial, bending, shear, torsion → von Mises → SF."""
    lf = params.load_safety_factor_applied
    A = params.cross_section_area_m2
    Z = params.section_modulus_m3
    Zp = params.polar_modulus_m3 or (Z * 2)
    sigma_axial = (params.axial_force_N * lf) / A
    sigma_bend  = (params.moment_Nm * lf) / Z
    sigma_total = sigma_axial + sigma_bend
    tau_shear   = 1.5*(params.shear_force_N*lf)/A
    tau_torsion = (params.torsion_Nm * lf) / Zp
    tau_total   = tau_shear + tau_torsion
    von_mises = math.sqrt(sigma_total**2 + 3*tau_total**2)
    Sy = params.yield_strength_MPa * 1e6
    SF = Sy/von_mises if von_mises>0 else 999
    status = "PASS" if SF>=1.5 else ("MARGINAL" if SF>=1.0 else "FAIL")
    return json.dumps({
        "stresses_MPa":{
            "axial": round(sigma_axial/1e6,3), "bending": round(sigma_bend/1e6,3),
            "combined_normal": round(sigma_total/1e6,3),
            "shear": round(tau_shear/1e6,3), "torsion": round(tau_torsion/1e6,3),
            "combined_shear": round(tau_total/1e6,3),
            "von_mises": round(von_mises/1e6,3)
        },
        "safety":{"yield_MPa":params.yield_strength_MPa,"SF":round(SF,2),"status":status}
    }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# FATIGUE ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
class FatigueInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    uts_MPa: float = Field(..., gt=0, description="Material ultimate tensile strength (MPa)")
    stress_amplitude_MPa: float = Field(..., gt=0, description="Alternating stress amplitude (MPa)")
    mean_stress_MPa: float = Field(0.0, description="Mean stress (MPa, 0 = fully-reversed)")
    surface_finish: Literal["mirror","ground","machined","hot_rolled","forged","cast"] = Field("machined")
    stress_concentration_kt: float = Field(1.0, ge=1.0, description="Stress concentration factor Kt")
    reliability_percent: float = Field(90.0, description="Required reliability %")
    criterion: Literal["goodman","soderberg","gerber"] = Field("goodman")

@mcp.tool(name="phy_fatigue_analysis", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_fatigue_analysis(params: FatigueInput) -> str:
    """Fatigue life analysis: modified endurance limit via Marin factors."""
    Sut = params.uts_MPa
    Se_prime = 0.504 * Sut if Sut <= 1400 else 700.0
    ka_map = {"mirror":(1.58,-0.085),"ground":(1.58,-0.085),
              "machined":(4.51,-0.265),"hot_rolled":(57.7,-0.718),
              "forged":(272.0,-0.995),"cast":(272.0,-0.995)}
    a_sf, b_sf = ka_map[params.surface_finish]
    ka = min(a_sf * Sut**b_sf, 1.0)
    kb = 0.85; kc = 1.0; kd = 1.0
    rel_map = {50:1.0,90:0.897,95:0.868,99:0.814,99.9:0.753}
    pct = params.reliability_percent
    ke = min(rel_map.items(), key=lambda x: abs(x[0]-pct))[1]
    kf = params.stress_concentration_kt
    Se = ka*kb*kc*kd*ke * Se_prime / kf
    sa = params.stress_amplitude_MPa
    sm = params.mean_stress_MPa
    Sy = 0.577 * Sut
    if params.criterion == "goodman":
        lhs = sa/Se + sm/Sut
    elif params.criterion == "soderberg":
        lhs = sa/Se + sm/Sy
    else:
        lhs = sa/Se + (sm/Sut)**2
    SF = 1.0/lhs if lhs>0 else 999
    sigma_f = Sut + 345
    b_exp = -0.085
    if sa > 0:
        N = 0.5*(sa/sigma_f)**(1/b_exp)
        regime = "high_cycle" if N>1e4 else "low_cycle"
    else:
        N = float('inf'); regime = "infinite"
    status = "PASS" if SF>=1.5 else ("MARGINAL" if SF>=1.0 else "FAIL")
    return json.dumps({
        "marin_factors":{"ka":round(ka,4),"kb":kb,"kc":kc,"kd":kd,"ke":ke,"kf":kf},
        "endurance_limit_MPa":{"Se_prime":round(Se_prime,2),"Se_modified":round(Se,2)},
        "criterion":params.criterion,"mean_stress_correction_LHS":round(lhs,4),
        "safety_factor":round(SF,2),"status":status,
        "fatigue_life_cycles":f"{N:.2e}","regime":regime
    }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# PRESSURE VESSEL
# ─────────────────────────────────────────────────────────────────────────────
class PVInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    vessel_type: Literal["thin_cylinder","thick_cylinder","thin_sphere","thick_sphere"] = Field(...)
    design_pressure_MPa: float = Field(..., gt=0)
    inner_radius_mm: float = Field(..., gt=0)
    material_yield_MPa: float = Field(250.0, gt=0)
    material_uts_MPa: float = Field(400.0, gt=0)
    wall_thickness_mm: Optional[float] = Field(None, gt=0, description="If known; else computed for required SF")
    required_safety_factor: float = Field(3.0, gt=1.0)
    weld_efficiency: float = Field(1.0, gt=0, le=1.0, description="Joint efficiency")

@mcp.tool(name="phy_pressure_vessel", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_pressure_vessel(params: PVInput) -> str:
    """Pressure vessel wall sizing: thin-wall hoop/axial stress OR Lamé thick-wall."""
    p = params.design_pressure_MPa
    ri = params.inner_radius_mm
    Sy = params.material_yield_MPa
    SF = params.required_safety_factor
    S_allow = Sy / SF
    E_j = params.weld_efficiency
    vt = params.vessel_type
    if "thin" in vt:
        if "cylinder" in vt:
            t_req = p*ri / (S_allow*E_j - 0.6*p)
        else:
            t_req = p*ri / (2*S_allow*E_j - 0.2*p)
        t = params.wall_thickness_mm if params.wall_thickness_mm else t_req
        ro = ri + t
        if "cylinder" in vt:
            sigma_h = p*ri/t
            sigma_a = p*ri/(2*t)
            vm = math.sqrt(sigma_h**2 - sigma_h*sigma_a + sigma_a**2)
        else:
            sigma_h = p*ri/(2*t)
            sigma_a = sigma_h
            vm = sigma_h
        actual_SF = Sy/vm if vm>0 else 999
        return json.dumps({
            "vessel_type":vt,"pressure_MPa":p,
            "geometry":{"ri_mm":ri,"t_mm":round(t,3),"t_required_mm":round(t_req,3),
                        "ro_mm":round(ro,3),"t_ri_ratio":round(t/ri,4)},
            "stresses_MPa":{"hoop":round(sigma_h,2),"axial":round(sigma_a,2),"von_mises":round(vm,2)},
            "safety":{"allowable_MPa":round(S_allow,2),"actual_SF":round(actual_SF,2),
                      "status":"PASS" if actual_SF>=SF else "FAIL"},
            "thin_wall_valid": t/ri < 0.1
        }, indent=2)
    else:
        if params.wall_thickness_mm:
            ro = ri + params.wall_thickness_mm
        else:
            ro_sq = ri**2*(S_allow+p)/(S_allow-p) if S_allow>p else None
            if ro_sq is None: return json.dumps({"error":"Allowable stress < pressure. Increase SF or yield strength."})
            ro = math.sqrt(ro_sq)
        t = ro - ri
        A_lame = p*ri**2/(ro**2-ri**2)
        B_lame = p*ri**2*ro**2/(ro**2-ri**2)
        sigma_h_inner = A_lame + B_lame/ri**2
        sigma_r_inner = -p
        sigma_h_outer = A_lame + B_lame/ro**2
        vm_inner = math.sqrt(sigma_h_inner**2 - sigma_h_inner*sigma_r_inner + sigma_r_inner**2)
        actual_SF = Sy/vm_inner if vm_inner>0 else 999
        return json.dumps({
            "vessel_type":vt,"geometry":{"ri_mm":ri,"ro_mm":round(ro,2),"t_mm":round(t,2)},
            "lame_constants":{"A":round(A_lame,3),"B":round(B_lame,3)},
            "stresses_MPa":{"hoop_inner":round(sigma_h_inner,2),"radial_inner":round(sigma_r_inner,2),
                "hoop_outer":round(sigma_h_outer,2),"vm_inner":round(vm_inner,2)},
            "safety":{"actual_SF":round(actual_SF,2),"status":"PASS" if actual_SF>=SF else "FAIL"}
        }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# COLUMN BUCKLING
# ─────────────────────────────────────────────────────────────────────────────
class BucklingInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    length_m: float = Field(..., gt=0)
    section_type: Literal["rectangular","circular","hollow_circular","custom"] = Field("rectangular")
    width_mm: Optional[float] = Field(None, gt=0)
    height_mm: Optional[float] = Field(None, gt=0)
    diameter_mm: Optional[float] = Field(None, gt=0)
    inner_diameter_mm: Optional[float] = Field(None, gt=0)
    I_min_m4: Optional[float] = Field(None, gt=0, description="Min second moment of area (custom)")
    area_m2: Optional[float] = Field(None, gt=0, description="Cross-section area (custom)")
    youngs_modulus_GPa: float = Field(200.0, gt=0)
    yield_strength_MPa: float = Field(250.0, gt=0)
    end_condition: Literal["pinned_pinned","fixed_free","fixed_pinned","fixed_fixed"] = Field("pinned_pinned")
    applied_load_kN: float = Field(..., gt=0)

@mcp.tool(name="phy_column_buckling", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_column_buckling(params: BucklingInput) -> str:
    """Euler / Johnson column buckling analysis."""
    K_map = {"pinned_pinned":1.0,"fixed_free":2.0,"fixed_pinned":0.699,"fixed_fixed":0.5}
    K = K_map[params.end_condition]
    E = params.youngs_modulus_GPa*1e9; Sy = params.yield_strength_MPa*1e6; L=params.length_m
    s = params.section_type
    if s=="rectangular":
        b=(params.width_mm or 50.0)/1000; h=(params.height_mm or 100.0)/1000
        I_min=b*min(b,h)**3/12; A=b*h
    elif s=="circular":
        d=(params.diameter_mm or 50.0)/1000; I_min=math.pi*d**4/64; A=math.pi*d**2/4
    elif s=="hollow_circular":
        D=(params.diameter_mm or 60.0)/1000; di=(params.inner_diameter_mm or 50.0)/1000
        I_min=math.pi*(D**4-di**4)/64; A=math.pi*(D**2-di**2)/4
    else:
        I_min=params.I_min_m4 or 1e-6; A=params.area_m2 or 1e-3
    r = math.sqrt(I_min/A)
    lambda_ratio = K*L/r
    lambda_c = math.pi*math.sqrt(2*E/Sy)
    P_euler = math.pi**2*E*I_min/(K*L)**2
    if lambda_ratio >= lambda_c:
        P_cr = P_euler; mode = "Euler (long column)"
    else:
        P_cr = A*Sy*(1-(Sy*(K*L)**2)/(4*math.pi**2*E*r**2))
        mode = "Johnson parabola (intermediate column)"
    SF = P_cr/(params.applied_load_kN*1000) if params.applied_load_kN>0 else 999
    return json.dumps({
        "end_condition":params.end_condition,"K_factor":K,
        "geometry":{"r_gyration_mm":round(r*1000,3),"slenderness_KL_r":round(lambda_ratio,1),
                    "critical_slenderness":round(lambda_c,1)},
        "buckling_mode":mode,
        "loads_kN":{"critical_Euler":round(P_euler/1000,2),"governing_Pcr":round(P_cr/1000,2),
                    "applied":params.applied_load_kN},
        "safety":{"SF":round(SF,2),"status":"PASS" if SF>=2.0 else ("MARGINAL" if SF>=1.5 else "FAIL")}
    }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# HEAT CONDUCTION
# ─────────────────────────────────────────────────────────────────────────────
class HeatCondInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    geometry: Literal["flat_wall","cylinder","sphere","composite_wall"] = Field(...)
    k_W_mK: Optional[float] = Field(None, gt=0)
    T_hot_C: float = Field(...)
    T_cold_C: float = Field(...)
    area_m2: Optional[float] = Field(None, gt=0)
    thickness_m: Optional[float] = Field(None, gt=0)
    r_inner_m: Optional[float] = Field(None, gt=0)
    r_outer_m: Optional[float] = Field(None, gt=0)
    length_m: Optional[float] = Field(None, gt=0)
    layers: Optional[List[dict]] = Field(None, description="Composite: [{k:float, thickness_m:float}]")

@mcp.tool(name="phy_heat_conduction", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_heat_conduction(params: HeatCondInput) -> str:
    """Steady-state heat conduction: flat wall, cylindrical shell, spherical shell, composite."""
    dT = params.T_hot_C - params.T_cold_C; g=params.geometry
    if g=="flat_wall":
        k=params.k_W_mK or 50.0; A=params.area_m2 or 1.0; t=params.thickness_m or 0.01
        R=t/(k*A); Q=k*A*dT/t
        return json.dumps({"Q_W":round(Q,3),"R_K_W":round(R,6),"flux_W_m2":round(Q/A,2),"dT_C":dT}, indent=2)
    elif g=="cylinder":
        k=params.k_W_mK or 50.0; ri=params.r_inner_m or 0.025
        ro=params.r_outer_m or 0.030; L=params.length_m or 1.0
        R=math.log(ro/ri)/(2*math.pi*k*L); Q=2*math.pi*k*L*dT/math.log(ro/ri)
        return json.dumps({"Q_W":round(Q,3),"R_K_W":round(R,6),"inner_flux_W_m2":round(Q/(2*math.pi*ri*L),2)}, indent=2)
    elif g=="sphere":
        k=params.k_W_mK or 50.0; ri=params.r_inner_m or 0.05; ro=params.r_outer_m or 0.055
        R=(ro-ri)/(4*math.pi*k*ri*ro); Q=4*math.pi*k*ri*ro*dT/(ro-ri)
        return json.dumps({"Q_W":round(Q,3),"R_K_W":round(R,6)}, indent=2)
    else:
        layers=params.layers or []; A=params.area_m2 or 1.0
        if not layers: return json.dumps({"error":"Provide layers: [{k, thickness_m}]"})
        R_total=sum(lay["thickness_m"]/(lay["k"]*A) for lay in layers)
        Q=dT/R_total if R_total>0 else 0
        return json.dumps({"Q_W":round(Q,3),"R_total_K_W":round(R_total,6),"flux_W_m2":round(Q/A,2),"n_layers":len(layers)}, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# PIPE FLOW
# ─────────────────────────────────────────────────────────────────────────────
class PipeInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    diameter_mm: float = Field(..., gt=0)
    length_m: float = Field(..., gt=0)
    flow_rate_m3_s: float = Field(..., gt=0)
    fluid_density_kg_m3: float = Field(1000.0, gt=0)
    dynamic_viscosity_Pa_s: float = Field(0.001002, gt=0)
    roughness_mm: float = Field(0.046, ge=0)
    minor_loss_coefficient: float = Field(0.0, ge=0)
    pump_efficiency: float = Field(0.70, gt=0, le=1.0)

@mcp.tool(name="phy_pipe_flow", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_pipe_flow(params: PipeInput) -> str:
    """Pipe flow: Reynolds number, friction factor, pressure drop, pump power."""
    D=params.diameter_mm/1000; L=params.length_m
    Q=params.flow_rate_m3_s; rho=params.fluid_density_kg_m3
    mu=params.dynamic_viscosity_Pa_s; eps=params.roughness_mm/1000
    A_pipe=math.pi*D**2/4; v=Q/A_pipe
    Re=rho*v*D/mu
    regime = "LAMINAR" if Re<2300 else ("TRANSITIONAL" if Re<4000 else "TURBULENT")
    if Re < 2300:
        f=64/Re
    elif Re < 4000:
        f=0.038
    else:
        f=0.25/(math.log10(eps/(3.7*D)+5.74/Re**0.9))**2
        for _ in range(50):
            rhs=1/(-2*math.log10(eps/(3.7*D)+2.51/(Re*math.sqrt(f))))**2
            if abs(rhs-f)<1e-10: f=rhs; break
            f=rhs
    dP_major = f*(L/D)*(rho*v**2/2)
    dP_minor = params.minor_loss_coefficient*(rho*v**2/2)
    dP_total = dP_major+dP_minor
    h_loss = dP_total/(rho*9.81)
    P_hydraulic = Q*dP_total
    P_shaft = P_hydraulic/params.pump_efficiency
    return json.dumps({
        "flow":{"velocity_m_s":round(v,4),"Re":round(Re,0),"regime":regime},
        "friction":{"f_darcy":round(f,6)},
        "losses":{"dP_major_kPa":round(dP_major/1000,3),"dP_minor_kPa":round(dP_minor/1000,3),
                  "dP_total_kPa":round(dP_total/1000,3),"head_loss_m":round(h_loss,3)},
        "pump":{"hydraulic_power_W":round(P_hydraulic,2),"shaft_power_W":round(P_shaft,2),
                "shaft_power_kW":round(P_shaft/1000,3)}
    }, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# CONVECTION
# ─────────────────────────────────────────────────────────────────────────────
class ConvInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    geometry: Literal["flat_plate_forced","cylinder_crossflow","pipe_internal","vertical_plate_natural","horizontal_plate_natural"] = Field(...)
    T_surface_C: float = Field(...)
    T_fluid_C: float = Field(...)
    velocity_m_s: Optional[float] = Field(None, ge=0)
    characteristic_length_m: float = Field(..., gt=0)
    fluid: Literal["air_25C","water_20C","water_60C","oil_SAE10","custom"] = Field("air_25C")
    custom_rho: Optional[float]=Field(None)
    custom_mu: Optional[float]=Field(None)
    custom_k: Optional[float]=Field(None)
    custom_Pr: Optional[float]=Field(None)
    surface_area_m2: float = Field(1.0, gt=0)

@mcp.tool(name="phy_convection", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_convection(params: ConvInput) -> str:
    """Convection heat transfer coefficient via Nusselt correlations."""
    fluid_props = {"air_25C":(1.184,1.849e-5,0.02551,0.7296),"water_20C":(998.2,1.002e-3,0.5984,7.01),"water_60C":(983.2,4.67e-4,0.6513,2.99),"oil_SAE10":(870.0,6.5e-2,0.145,1000.0)}
    if params.fluid=="custom":
        rho=params.custom_rho or 1.2; mu=params.custom_mu or 1.8e-5
        k_f=params.custom_k or 0.025; Pr=params.custom_Pr or 0.73
    else:
        rho,mu,k_f,Pr = fluid_props[params.fluid]
    L=params.characteristic_length_m; v=params.velocity_m_s or 1.0
    dT=abs(params.T_surface_C-params.T_fluid_C)
    g_geom = params.geometry
    if g_geom=="flat_plate_forced":
        Re=rho*v*L/mu
        if Re<5e5: Nu=0.664*Re**0.5*Pr**(1/3)
        else: Nu=(0.037*Re**0.8-871)*Pr**(1/3)
        regime="laminar" if Re<5e5 else "mixed"
    elif g_geom=="cylinder_crossflow":
        Re=rho*v*L/mu
        Nu=0.3+(0.62*Re**0.5*Pr**(1/3))/(1+(0.4/Pr)**(2/3))**0.25*(1+(Re/282000)**0.625)**0.8
        regime="turbulent" if Re>2e5 else "laminar"
    elif g_geom=="pipe_internal":
        Re=rho*v*L/mu
        if Re<2300:
            Nu=3.66; regime="laminar_developed"
        else:
            Nu=0.023*Re**0.8*Pr**0.4; regime="turbulent_Dittus_Boelter"
    elif g_geom=="vertical_plate_natural":
        beta=1/(params.T_fluid_C+273.15); nu=mu/rho
        Gr=9.81*beta*dT*L**3/nu**2; Ra=Gr*Pr
        Nu=0.59*Ra**0.25 if Ra<1e9 else 0.1*Ra**(1/3)
        Re=0; regime=f"Ra={Ra:.2e}"
    else:
        beta=1/(params.T_fluid_C+273.15); nu=mu/rho
        Gr=9.81*beta*dT*L**3/nu**2; Ra=Gr*Pr
        Nu=0.54*Ra**0.25 if Ra<1e7 else 0.15*Ra**(1/3)
        Re=0; regime=f"Ra={Ra:.2e}"
    h=Nu*k_f/L; Q=h*params.surface_area_m2*dT
    return json.dumps({"geometry":g_geom,"fluid":params.fluid,"flow":{"Re":round(Re,0) if Re else "N/A (natural)","regime":regime},"results":{"Nu":round(Nu,3),"h_W_m2K":round(h,3),"Q_W":round(Q,2)},"summary":f"h={round(h,2)} W/(m²·K), Q={round(Q,2)} W"}, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# SPRING DESIGN
# ─────────────────────────────────────────────────────────────────────────────
class SpringInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    spring_type: Literal["helical_compression","helical_extension","torsion"] = Field("helical_compression")
    wire_diameter_mm: float = Field(..., gt=0)
    mean_coil_diameter_mm: float = Field(..., gt=0)
    active_coils: float = Field(..., gt=0)
    shear_modulus_GPa: float = Field(79.3, gt=0)
    yield_shear_MPa: float = Field(460.0, gt=0)
    load_N: float = Field(..., gt=0)

@mcp.tool(name="phy_spring_design", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_spring_design(params: SpringInput) -> str:
    """Helical spring design: spring rate, Wahl-corrected shear stress, SF."""
    d=params.wire_diameter_mm; D=params.mean_coil_diameter_mm
    Na=params.active_coils; G=params.shear_modulus_GPa*1e3
    Sys=params.yield_shear_MPa; F=params.load_N
    C=D/d; Kw=(4*C-1)/(4*C-4)+0.615/C
    k=G*d**4/(8*D**3*Na); delta=F/k
    tau=8*Kw*F*D/(math.pi*d**3)
    SF=Sys/tau if tau>0 else 999
    rho_wire=7850e-9
    fn=d/(math.pi*D**2*Na)*math.sqrt(G*1e6*9810/(8*rho_wire)) if rho_wire>0 else 0
    Ls=d*(Na+2)
    return json.dumps({"spring_index_C":round(C,2),"Wahl_Kw":round(Kw,4),"spring_rate_N_mm":round(k,4),"deflection_mm":round(delta,3),"shear_stress_MPa":round(tau,2),"SF_yield":round(SF,2),"solid_length_mm":round(Ls,2),"natural_freq_Hz":round(fn,1),"status":"PASS" if SF>=1.3 else "FAIL"}, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# ELECTRICAL POWER
# ─────────────────────────────────────────────────────────────────────────────
class ElecInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    circuit_type: Literal["dc","ac_single","ac_three"] = Field("dc")
    voltage_V: float = Field(..., gt=0)
    current_A: Optional[float] = Field(None, ge=0)
    resistance_ohm: Optional[float] = Field(None, gt=0)
    power_factor: float = Field(1.0, gt=0, le=1.0)
    efficiency: float = Field(1.0, gt=0, le=1.0)

@mcp.tool(name="phy_electrical_power", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_electrical_power(params: ElecInput) -> str:
    """Electrical power calculations: DC or AC single/three-phase."""
    V=params.voltage_V; pf=params.power_factor; eff=params.efficiency
    I = params.current_A; R = params.resistance_ohm
    if I is None and R is not None: I=V/R
    elif I is None: return json.dumps({"error":"Provide current_A or resistance_ohm"})
    if R is None and I>0: R=V/I
    if params.circuit_type=="dc":
        P_real=V*I; P_loss=I**2*(R or 0); P_useful=P_real*eff
        return json.dumps({"type":"DC","V":V,"I":round(I,3),"R_ohm":round(R,3) if R else None,"P_real_W":round(P_real,2),"P_useful_W":round(P_useful,2),"P_heat_loss_W":round(P_real*(1-eff),2)}, indent=2)
    elif params.circuit_type=="ac_single":
        S=V*I; P=S*pf; Q=S*math.sqrt(max(0,1-pf**2)); P_useful=P*eff
        return json.dumps({"type":"AC 1-phase","V_rms":V,"I_rms":round(I,3),"pf":pf,"apparent_VA":round(S,2),"real_W":round(P,2),"reactive_VAR":round(Q,2),"useful_W":round(P_useful,2)}, indent=2)
    else:
        S=math.sqrt(3)*V*I; P=S*pf; Q=S*math.sqrt(max(0,1-pf**2)); P_useful=P*eff
        return json.dumps({"type":"AC 3-phase","V_line":V,"I_line":round(I,3),"pf":pf,"apparent_VA":round(S,2),"real_W":round(P,2),"reactive_VAR":round(Q,2),"useful_kW":round(P_useful/1000,3)}, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# IMPACT ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
class ImpactInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    mass_kg: float = Field(..., gt=0)
    impact_velocity_m_s: Optional[float] = Field(None, ge=0)
    drop_height_m: Optional[float] = Field(None, ge=0)
    contact_duration_ms: float = Field(10.0, gt=0)
    coefficient_restitution: float = Field(0.0, ge=0, le=1.0)

@mcp.tool(name="phy_impact_analysis", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_impact_analysis(params: ImpactInput) -> str:
    """Impact force estimation: mass, impact velocity or drop height, contact duration."""
    m=params.mass_kg; e=params.coefficient_restitution
    dt=params.contact_duration_ms/1000
    if params.impact_velocity_m_s is not None:
        v=params.impact_velocity_m_s
    elif params.drop_height_m is not None:
        v=math.sqrt(2*9.81*params.drop_height_m)
    else:
        return json.dumps({"error":"Provide impact_velocity_m_s or drop_height_m"})
    v_rebound=e*v; delta_v=v+v_rebound
    impulse=m*delta_v; F_avg=impulse/dt
    F_peak=F_avg*1.5
    KE=0.5*m*v**2; g_load=F_avg/(m*9.81)
    return json.dumps({"impact_velocity_m_s":round(v,3),"rebound_velocity_m_s":round(v_rebound,3),"impulse_Ns":round(impulse,3),"kinetic_energy_J":round(KE,2),"forces":{"F_average_kN":round(F_avg/1000,3),"F_peak_kN":round(F_peak/1000,3),"g_load_avg":round(g_load,1)}}, indent=2)

# ─────────────────────────────────────────────────────────────────────────────
# SIMPLE GEAR BENDING CHECK
# ─────────────────────────────────────────────────────────────────────────────
class GearInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    transmitted_tangential_load_N: float = Field(..., gt=0)
    module_mm: float = Field(..., gt=0)
    face_width_mm: float = Field(..., gt=0)
    lewis_form_factor: float = Field(0.35, gt=0, le=0.6, description="Y; typical 0.3-0.45")
    allowable_bending_stress_MPa: float = Field(150.0, gt=0)
    velocity_factor: float = Field(1.0, gt=0, le=1.0, description="Kv <=1; use 1 for static estimate")

@mcp.tool(name="phy_gear_bending", annotations={"readOnlyHint":True,"idempotentHint":True})
async def phy_gear_bending(params: GearInput) -> str:
    """Simple Lewis bending check for spur gears: σ = Ft / (b*m*Y*Kv)."""
    Ft = params.transmitted_tangential_load_N
    b = params.face_width_mm
    m = params.module_mm
    Y = params.lewis_form_factor
    Kv = params.velocity_factor
    sigma = Ft / (b*m*Y*Kv)
    SF = params.allowable_bending_stress_MPa / sigma if sigma > 0 else 999
    return json.dumps({"sigma_bending_MPa":round(sigma,3),"allowable_MPa":params.allowable_bending_stress_MPa,"SF":round(SF,2),"status":"PASS" if SF>=1.5 else ("MARGINAL" if SF>=1.0 else "FAIL")}, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")
