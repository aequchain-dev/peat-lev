#!/usr/bin/env python3
"""efe_project_mcp — Project state: decisions, assumptions, risks, requirements, iterations."""
import json, os
from pathlib import Path
from datetime import datetime
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional, Any

mcp = FastMCP("efe_project_mcp")
DATA_DIR = Path("/var/home/ryan/.local/share/efe-mcps/project-data")
DATA_DIR.mkdir(parents=True, exist_ok=True)

def _load(project_id):
    f=DATA_DIR/f"{project_id}.json"
    if f.exists(): return json.loads(f.read_text())
    return {"id":project_id,"decisions":[],"assumptions":[],"risks":[],"requirements":[],"iterations":[],"phase_gates":{}}

def _save(project_id, data):
    (DATA_DIR/f"{project_id}.json").write_text(json.dumps(data,indent=2))

class InitInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str; project_name: str; purpose: str
    magnitude: str = "STANDARD"; scale: str = "regional"; rigor: str = "FULL"

@mcp.tool(name="prj_init", annotations={"readOnlyHint":False})
async def prj_init(params: InitInput) -> str:
    data=_load(params.project_id)
    data.update({"name":params.project_name,"purpose":params.purpose,"magnitude":params.magnitude,"scale":params.scale,"rigor":params.rigor,"created":datetime.now().isoformat(),"current_phase":0})
    _save(params.project_id, data)
    return json.dumps({"status":"INITIALISED","project_id":params.project_id,"name":params.project_name,"file":str(DATA_DIR/f"{params.project_id}.json")}, indent=2)

class DecisionInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str; phase: int; decision: str
    rationale: str; alternatives_considered: List[str]; selected: str

@mcp.tool(name="prj_log_decision", annotations={"readOnlyHint":False})
async def prj_log_decision(params: DecisionInput) -> str:
    data=_load(params.project_id)
    entry={"id":len(data["decisions"])+1,"phase":params.phase,"decision":params.decision,"rationale":params.rationale,"alternatives":params.alternatives_considered,"selected":params.selected,"timestamp":datetime.now().isoformat()}
    data["decisions"].append(entry); _save(params.project_id, data)
    return json.dumps({"logged":True,"entry_id":entry["id"],"decision":params.decision}, indent=2)

class AssumptionInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str; phase: int
    assumption: str; basis: str; risk_if_wrong: str

@mcp.tool(name="prj_log_assumption", annotations={"readOnlyHint":False})
async def prj_log_assumption(params: AssumptionInput) -> str:
    data=_load(params.project_id)
    entry={"id":len(data["assumptions"])+1,"phase":params.phase,"assumption":params.assumption,"basis":params.basis,"risk_if_wrong":params.risk_if_wrong,"timestamp":datetime.now().isoformat()}
    data["assumptions"].append(entry); _save(params.project_id, data)
    return json.dumps({"logged":True,"entry_id":entry["id"]}, indent=2)

class RiskInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str; risk: str
    likelihood: int = Field(..., ge=1, le=5)
    impact: int = Field(..., ge=1, le=5)
    mitigation: str; owner: str

@mcp.tool(name="prj_log_risk", annotations={"readOnlyHint":False})
async def prj_log_risk(params: RiskInput) -> str:
    data=_load(params.project_id)
    rpn=params.likelihood*params.impact
    level="CRITICAL" if rpn>=15 else("HIGH" if rpn>=9 else("MEDIUM" if rpn>=4 else "LOW"))
    entry={"id":len(data["risks"])+1,"risk":params.risk,"L":params.likelihood,"I":params.impact,"RPN":rpn,"level":level,"mitigation":params.mitigation,"owner":params.owner,"status":"OPEN","timestamp":datetime.now().isoformat()}
    data["risks"].append(entry); _save(params.project_id, data)
    return json.dumps({"logged":True,"entry_id":entry["id"],"risk_level":level,"RPN":rpn}, indent=2)

class IterationInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str; cycle: int
    gaps_found: List[str]; enhancements: List[str]
    delta_items: List[dict] = Field(default_factory=list)

@mcp.tool(name="prj_iteration_record", annotations={"readOnlyHint":False})
async def prj_iteration_record(params: IterationInput) -> str:
    data=_load(params.project_id)
    improvements=sum(1 for d in params.delta_items if abs(float(d.get("after",0))-float(d.get("before",0)))>0)
    entry={"cycle":params.cycle,"gaps":params.gaps_found,"enhancements":params.enhancements,"delta_items":params.delta_items,"improvements_count":improvements,"delta_to_zero":improvements==0,"timestamp":datetime.now().isoformat()}
    data["iterations"].append(entry); _save(params.project_id, data)
    return json.dumps({"cycle":params.cycle,"gaps_found":len(params.gaps_found),"enhancements_applied":len(params.enhancements),"improvements":improvements,"verdict":"Delta approaching zero — consider Phase 7" if improvements==0 else f"{improvements} improvements found"}, indent=2)

class StatusInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    project_id: str

@mcp.tool(name="prj_status", annotations={"readOnlyHint":True,"idempotentHint":True})
async def prj_status(params: StatusInput) -> str:
    data=_load(params.project_id)
    open_risks=[r for r in data.get("risks",[]) if r.get("status")=="OPEN" and r.get("level") in ["HIGH","CRITICAL"]]
    return json.dumps({"project_id":params.project_id,"name":data.get("name",""),"purpose":data.get("purpose",""),"rigor":data.get("rigor",""),"decisions":len(data.get("decisions",[])),"assumptions":len(data.get("assumptions",[])),"risks_total":len(data.get("risks",[])),"risks_high_critical":len(open_risks),"iterations_completed":len(data.get("iterations",[])),"last_iteration_delta_zero":data["iterations"][-1]["delta_to_zero"] if data.get("iterations") else None}, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")
