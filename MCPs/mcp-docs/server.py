#!/usr/bin/env python3
"""efe_docs_mcp — ODF document generation: blueprints, BOM, FMEA, certificates."""
import json
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Dict, Any
from datetime import date

mcp = FastMCP("efe_docs_mcp")

def odf_line(char="═", width=80): return char*width
def odf_header(title, subtitle="", version="1.0", status="DRAFT"):
    lines=[odf_line("═"),title]
    if subtitle: lines.append(subtitle)
    lines+=[odf_line("─"),f"Version: {version} │ Date: {date.today()} │ Status: {status}",odf_line("═")]
    return "\n".join(lines)
def odf_section(n, title):
    return f"\n{odf_line('─')}\n{n}. {title.upper()}\n{odf_line('─')}"
def odf_block(label, content):
    lines=[f"┌─ {label} {'─'*(74-len(label))}","│"]
    for line in content.split("\n"): lines.append(f"│  {line}")
    lines+=["│","└"+"─"*79]
    return "\n".join(lines)

class BlueprintInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_name: str; purpose_statement: str
    efe_filter_pass: bool = False
    optibest_status: str = "IN PROGRESS"
    key_specs: Dict[str,Any] = Field(default_factory=dict)
    system_description: str = ""; materials_summary: List[str] = Field(default_factory=list)
    manufacturing_notes: str = ""; lifecycle_summary: str = ""
    known_limitations: List[str] = Field(default_factory=list)
    version: str = "0.1"; status: str = "DRAFT"

@mcp.tool(name="doc_generate_blueprint", annotations={"readOnlyHint":True,"idempotentHint":True})
async def doc_generate_blueprint(params: BlueprintInput) -> str:
    doc=[odf_header(f"BLUEPRINT: {params.project_name.upper()}", params.purpose_statement, params.version, params.status)]
    doc.append(odf_section(1,"EXECUTIVE SUMMARY"))
    doc.append(f"Purpose: {params.purpose_statement}")
    doc.append(f"EFE Filter: {'✓ PASS' if params.efe_filter_pass else '✗ PENDING'}")
    doc.append(f"OPTIBEST Status: {params.optibest_status}")
    if params.key_specs:
        doc.append(odf_block("KEY SPECIFICATIONS", "\n".join(f"{k:30s}: {v}" for k,v in params.key_specs.items())))
    doc.append(odf_section(2,"SYSTEM DESCRIPTION"))
    doc.append(params.system_description or "[COMPLETE: Describe system architecture, subsystems, interfaces]")
    doc.append(odf_section(3,"SUSTAINABILITY CERTIFICATION"))
    doc.append(odf_block("EFE FILTER STATUS", f"Status: {'ALL 7 PRINCIPLES PASS ✓' if params.efe_filter_pass else 'PENDING — run frm_efe_filter'}\nPrinciples: Sustainable │ Renewable │ Accessible │ Open │ Local-First │ Circular │ Durable"))
    doc.append(odf_section(4,"TECHNICAL SPECIFICATIONS"))
    doc.append("[COMPLETE: Populate from phy_* tool outputs with tolerances, dimensions, performance data]")
    doc.append(odf_section(5,"MATERIALS"))
    if params.materials_summary:
        doc.append(odf_block("BILL OF MATERIALS SUMMARY","\n".join(f"• {m}" for m in params.materials_summary)))
    else:
        doc.append("[COMPLETE: Use doc_create_bom with full material list]")
    doc.append(odf_section(6,"MANUFACTURING"))
    doc.append(params.manufacturing_notes or "[COMPLETE: Manufacturing process, equipment, QC checkpoints]")
    doc.append(odf_section(7,"LIFECYCLE"))
    doc.append(params.lifecycle_summary or "[COMPLETE: Use lca_quick and lca_circularity outputs]")
    doc.append(odf_section(8,"SCALING"))
    doc.append("[COMPLETE: Prototype → production → global distributed manufacturing protocol]")
    doc.append(odf_section(9,"OPTIBEST VERIFICATION"))
    doc.append(f"Status: {params.optibest_status}")
    if params.known_limitations:
        doc.append(odf_block("KNOWN LIMITATIONS","\n".join(f"• {l}" for l in params.known_limitations)))
    doc.append(f"\n{odf_line('═')}\nEND OF BLUEPRINT │ {params.project_name} │ v{params.version}\n{odf_line('═')}")
    return "\n".join(doc)

class BOMInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    items: List[Dict] = Field(...)
    project_name: str = ""

@mcp.tool(name="doc_create_bom", annotations={"readOnlyHint":True,"idempotentHint":True})
async def doc_create_bom(params: BOMInput) -> str:
    lines=[odf_header(f"BILL OF MATERIALS: {params.project_name.upper()}")]
    header=f"{'Item':<6}│{'Description':<28}│{'Qty':<5}│{'Material':<20}│{'Mass kg':<8}│{'EFE':<4}│Notes"
    sep="─"*6+"┼"+"─"*28+"┼"+"─"*5+"┼"+"─"*20+"┼"+"─"*8+"┼"+"─"*4+"┼"+"─"*10
    lines+=[header,sep]
    total_mass=0
    for item in params.items:
        mass=item.get("mass_kg",0); total_mass+=float(mass)*float(item.get("qty",1))
        tier=item.get("efe_tier","?"); tier_flag="✓" if str(tier) in ["1","2"] else "⚠" if str(tier)=="3" else "✗"
        lines.append(f"{str(item.get('item_no','')):<6}│{str(item.get('description',''))[:27]:<28}│{str(item.get('qty','1')):<5}│{str(item.get('material',''))[:19]:<20}│{str(mass):<8}│{tier_flag}{tier:<3}│{str(item.get('notes',''))[:15]}")
    lines+=[sep,f"Total mass: {round(total_mass,3)} kg │ Items: {len(params.items)}"]
    return "\n".join(lines)

class FMEADocInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_name: str = ""; rpn_threshold: int = 100
    items: List[Dict] = Field(...)

@mcp.tool(name="doc_fmea_table", annotations={"readOnlyHint":True,"idempotentHint":True})
async def doc_fmea_table(params: FMEADocInput) -> str:
    lines=[odf_header(f"FMEA TABLE: {params.project_name.upper()}")]
    lines.append(f"RPN Threshold: {params.rpn_threshold} │ S≥9 always flagged")
    header=f"{'Component':<20}│{'Failure Mode':<20}│{'Effect':<20}│{'S':<3}│{'O':<3}│{'D':<3}│{'RPN':<5}│Status"
    sep="─"*20+"┼"+"─"*20+"┼"+"─"*20+"┼"+"─"*3+"┼"+"─"*3+"┼"+"─"*3+"┼"+"─"*5+"┼"+"─"*10
    lines+=[header,sep]
    sorted_items=sorted(params.items, key=lambda x:x.get("S",1)*x.get("O",1)*x.get("D",1),reverse=True)
    for item in sorted_items:
        S=item.get("S",1); O=item.get("O",1); D=item.get("D",1); RPN=S*O*D
        flag="⚠ MITIGATE" if RPN>params.rpn_threshold or S>=9 else "✓ OK"
        lines.append(f"{str(item.get('component',''))[:19]:<20}│{str(item.get('failure_mode',''))[:19]:<20}│{str(item.get('effect',''))[:19]:<20}│{S:<3}│{O:<3}│{D:<3}│{RPN:<5}│{flag}")
    return "\n".join(lines)

class CertInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    design_name: str; purpose_statement: str
    iterations: int; final_delta: str
    efe_all_pass: bool; dimension_scores: Dict[str,int]
    plateau_all_pass: bool; known_limitations: List[str]
    rigor: str = "FULL"; magnitude: str = "STANDARD"; scale: str = "regional"

@mcp.tool(name="doc_optibest_certificate", annotations={"readOnlyHint":True,"idempotentHint":True})
async def doc_optibest_certificate(params: CertInput) -> str:
    all_5=all(v==5 for v in params.dimension_scores.values())
    status="◈ OPTIBEST ACHIEVED — PREMIUM CONFIRMED" if (all_5 and params.efe_all_pass and params.plateau_all_pass) else "◈ IN PROGRESS — Criteria not yet met"
    void_reasons=[]
    if not params.efe_all_pass: void_reasons.append("EFE Filter: not all 7 principles pass")
    if not params.plateau_all_pass: void_reasons.append("Plateau: not all 5 methods verified")
    if not all_5:
        sub5=[f"{d}={s}" for d,s in params.dimension_scores.items() if s<5]
        void_reasons.append(f"Dimension scores <5: {', '.join(sub5)}")
    lines=["╔"+"═"*78+"╗","║"+" "*20+"EFE OPTIBEST ENGINEER — DELIVERY CERTIFICATION"+" "*12+"║","╠"+"═"*78+"╣",f"║ Design: {params.design_name[:30]:<30} │ Purpose: {params.purpose_statement[:28]:<28} ║",f"║ Magnitude: {params.magnitude:<12} │ Scale: {params.scale:<10} │ Rigor: {params.rigor:<10} ║",f"║ Iterations: {params.iterations:<5} │ Final Δ: {params.final_delta:<20}                 ║","╠"+"═"*78+"╣","║ EFE FILTER (7 principles):                                                  ║",f"║  {'✓' if params.efe_all_pass else '✗'} Sustainable {'✓' if params.efe_all_pass else '✗'} Renewable {'✓' if params.efe_all_pass else '✗'} Accessible {'✓' if params.efe_all_pass else '✗'} Open {'✓' if params.efe_all_pass else '✗'} Local {'✓' if params.efe_all_pass else '✗'} Circular {'✓' if params.efe_all_pass else '✗'} Durable    ║","╠"+"═"*78+"╣","║ OPTIBEST DIMENSIONS (score 5/5 required):                                   ║"]
    for dim,score in params.dimension_scores.items():
        mark="✓" if score==5 else "✗"
        lines.append(f"║  {mark} {dim.capitalize():<20} {score}/5                                             ║")
    plateau_mark="✓" if params.plateau_all_pass else "✗"
    lines+=["╠"+"═"*78+"╣",f"║ PLATEAU: M1{plateau_mark} M2{plateau_mark} M3{plateau_mark} M4{plateau_mark} M5{plateau_mark} │ Anti-gaming: {'✓' if params.plateau_all_pass else '✗'}                              ║"]
    if params.known_limitations:
        lines.append("╠"+"═"*78+"╣")
        for lim in params.known_limitations[:3]:
            lines.append(f"║  LIMITATION: {lim[:62]:<62} ║")
    lines+=["╠"+"═"*78+"╣",f"║ STATUS: {status:<69} ║"]
    if void_reasons:
        for r in void_reasons: lines.append(f"║  ✗ {r[:73]:<73} ║")
    lines.append("╚"+"═"*78+"╝")
    return "\n".join(lines)

if __name__ == "__main__":
    mcp.run(transport="stdio")
