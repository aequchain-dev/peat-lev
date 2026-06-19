"""EFE-MCP Validation Suite — portable validation of all 8 servers."""
import json, subprocess, sys
from pathlib import Path

BASE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
VENV = str(BASE / "venv" / "bin" / "python")

INIT = {
    "jsonrpc": "2.0", "id": 1, "method": "initialize",
    "params": {"protocolVersion": "2024-11-05", "capabilities": {},
               "clientInfo": {"name": "validate_all", "version": "1.0"}},
}
NOTIFIED = {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}

SERVERS = [
    {"name": "efe_units",     "script": str(BASE / "mcp-units"    / "server.py"),     "tool": "unt_convert",     "args": {"params": {"value": 100, "from_unit": "MPa", "to_unit": "Pa"}},                                              "expected_count": 5},
    {"name": "efe_physics",   "script": str(BASE / "mcp-physics"  / "server.py"),     "tool": "phy_beam_analysis","args": {"params": {"beam_type": "simply_supported", "span_m": 3.0, "load_type": "udl", "load_magnitude": 5000}},                "expected_count": 12},
    {"name": "efe_materials", "script": str(BASE / "mcp-materials"/ "server.py"),     "tool": "mat_lookup",      "args": {"params": {"material_id": "bamboo_structural"}},                              "expected_count": 6},
    {"name": "efe_framework", "script": str(BASE / "mcp-framework"/ "server.py"),    "tool": "frm_dual_axis_calibrate","args": {"params": {"task_description":"Design a community water filter","deployment_scale":"community","irreversible":False,"safety_critical":True,"estimated_hours":40}}, "expected_count": 8},
    {"name": "efe_lifecycle", "script": str(BASE / "mcp-lifecycle"/ "server.py"),    "tool": "lca_repair_index", "args": {"params": {"fastener_types":["M5_bolts","M3_screws"],"module_count":4,"special_tools_required":False,"spare_parts_locally_available":True,"disassembly_steps":8,"documentation_quality":"good"}}, "expected_count": 4},
    {"name": "efe_standards", "script": str(BASE / "mcp-standards"/ "server.py"),    "tool": "std_safety_factor", "args": {"params": {"application": "ductile_static_standard"}},                        "expected_count": 4},
    {"name": "efe_docs",      "script": str(BASE / "mcp-docs"      / "server.py"),   "tool": "doc_create_bom",    "args": {"params": {"project_name":"Test","items":[{"item_no":1,"description":"Bamboo frame","qty":1,"material":"bamboo_structural","mass_kg":2.5,"efe_tier":1}]}}, "expected_count": 4},
    {"name": "efe_project",   "script": str(BASE / "mcp-project"  / "server.py"),    "tool": "prj_status",      "args": {"params": {"project_id": "test_project"}},                                "expected_count": 6},
]

def run(script, messages):
    payload = "\n".join(json.dumps(m) for m in messages) + "\n"
    proc = subprocess.run([VENV, script], input=payload, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"{script} exited {proc.returncode}: {proc.stderr}")
    objs = [json.loads(l) for l in proc.stdout.splitlines() if l.strip().startswith("{")]
    if not objs:
        raise RuntimeError(f"No JSON-RPC responses from {script}")
    return objs

def initialize(script):
    objs = run(script, [INIT])
    if "error" in objs[-1]:
        raise RuntimeError(f"initialize failed: {objs[-1]['error']}")
    return objs[-1]["result"]["serverInfo"]["name"]

def call_tool(script, name, args):
    msgs = [INIT, NOTIFIED, {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                             "params": {"name": name, "arguments": args}}]
    objs = run(script, msgs)
    response = next((o for o in objs if o.get("id") == 2), objs[-1])
    if "error" in response:
        raise RuntimeError(f"tool call failed: {response['error']}")
    if response.get("result", {}).get("isError"):
        raise RuntimeError(f"tool reported error: {response['result']}")
    return True

def list_tools(script):
    msgs = [INIT, NOTIFIED, {"jsonrpc": "2.0", "id": 3, "method": "tools/list", "params": {}}]
    objs = run(script, msgs)
    response = next((o for o in objs if o.get("id") == 3), objs[-1])
    if "error" in response:
        raise RuntimeError(f"tools/list failed: {response['error']}")
    return [t["name"] for t in response["result"].get("tools", [])]

failed = []
for server in SERVERS:
    try:
        info_name = initialize(server["script"])
        call_tool(server["script"], server["tool"], server["args"])
        tools = list_tools(server["script"])
        if len(tools) != server["expected_count"]:
            raise RuntimeError(f"expected {server['expected_count']} tools, got {len(tools)}: {tools}")
        print(f"[{server['name']}] OK  | {info_name:22s} | {server['tool']:25s} | {len(tools)} tools")
    except Exception as exc:
        failed.append((server["name"], str(exc)))
        print(f"[{server['name']}] FAIL - {exc}", file=sys.stderr)

if failed:
    print(f"\n=== VALIDATION FAILED: {len(failed)} server(s) ===", file=sys.stderr)
    for name, err in failed:
        print(f"  - {name}: {err}", file=sys.stderr)
    sys.exit(1)

print(f"\n=== VALIDATION COMPLETE: ALL {len(SERVERS)} SERVERS PASSED ===")
