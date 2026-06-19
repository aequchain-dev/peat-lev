# EFE-MCP Servers — Engineering for Everyone

> **EFE (Engineering For Everyone)** is a sustainable engineering design framework integrating EFE Filter principles (7 pillars) with the OPTIBEST Premium Framework (7 dimensions, 9 gated phases, 5-method plateau verification). These MCP servers expose EFE engineering tools as callable AI agent tools via the **Model Context Protocol**.

**8 MCP servers** — self-contained Python `FastMCP` servers for engineering analysis, materials science, lifecycle assessment, standards references, project tracking, and documentation generation.

> ⚠️ **EFE PRESENTER** (HTML presentation generator) is excluded from this repository.

---

## Server Index

| # | Server | Tools | Domain |
|---|--------|-------|--------|
| 1 | `mcp-units` | 5 | Unit conversion, SI normalization, dimensional analysis, physical constants |
| 2 | `mcp-physics` | 12 | Beam bending, column buckling, stress analysis, fatigue, heat transfer, pipe flow, pressure vessels, springs, gears, impact, electrical power, convection |
| 3 | `mcp-materials` | 6 | Material lookup (20 materials), property search, EFE compliance scoring, alternatives finder, carbon intensity, side-by-side comparison |
| 4 | `mcp-framework` | 8 | EFE Filter (7 principles), dual-axis calibration, OPTIBEST dimension scoring, gap detection, enhancement delta, FMEA calculation, constraint classification, plateau verification |
| 5 | `mcp-lifecycle` | 4 | Lifecycle assessment (LCA), carbon budget, circularity index, repair index |
| 6 | `mcp-standards` | 4 | ISO tolerance fits, safety factors (13 categories), fastener specs (M3–M24), surface finish lookup |
| 7 | `mcp-docs` | 4 | ODF blueprint generation, BOM tables, FMEA tables, OPTIBEST delivery certificates |
| 8 | `mcp-project` | 6 | Project init, decision log, assumption log, risk log (with RPN scoring), iteration records, project status |
| — | `shared/` | — | Shared materials database (`materials_db.py`) used by `mcp-materials` and `mcp-lifecycle` |

**Total: 49 tools**

---

## Quick Start

### Prerequisites

- **Python 3.10+** (3.11 or 3.12 recommended)
- pip

### Setup

```bash
# 1. Clone or navigate to this repository
cd MCPs

# 2. Create a virtual environment
python3 -m venv venv

# 3. Activate
# Linux / macOS:
source venv/bin/activate
# Windows (cmd):
venv\Scripts\activate
# Windows (PowerShell):
venv\Scripts\Activate.ps1

# 4. Install dependencies
pip install mcp pydantic
```

### Run a Server (standalone test)

```bash
# Linux / macOS:
python3 mcp-units/server.py

# Windows:
python mcp-units/server.py
```

Each server communicates over **stdio** (stdin/stdout JSON-RPC), the standard MCP transport.

---

## Configuration by MCP Client

### Claude Desktop (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "efe-units": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-units/server.py"]
    },
    "efe-physics": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-physics/server.py"]
    },
    "efe-materials": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-materials/server.py"]
    },
    "efe-framework": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-framework/server.py"]
    },
    "efe-lifecycle": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-lifecycle/server.py"]
    },
    "efe-standards": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-standards/server.py"]
    },
    "efe-docs": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-docs/server.py"]
    },
    "efe-project": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/MCPs/mcp-project/server.py"]
    }
  }
}
```

> Replace `/path/to/venv/bin/python` with your Python interpreter from the venv (e.g., `./venv/bin/python`).
> On Windows, use `./venv/Scripts/python.exe` and backslashes or forward slashes as appropriate.

### OpenCode / OpenClaude

Configure in `opencode.json`:

```json
{
  "mcp": {
    "servers": {
      "efe-units": {
        "command": "./venv/bin/python",
        "args": ["mcp-units/server.py"],
        "env": {}
      },
      "efe-physics": {
        "command": "./venv/bin/python",
        "args": ["mcp-physics/server.py"],
        "env": {}
      },
      "efe-materials": {
        "command": "./venv/bin/python",
        "args": ["mcp-materials/server.py"],
        "env": {}
      },
      "efe-framework": {
        "command": "./venv/bin/python",
        "args": ["mcp-framework/server.py"],
        "env": {}
      },
      "efe-lifecycle": {
        "command": "./venv/bin/python",
        "args": ["mcp-lifecycle/server.py"],
        "env": {}
      },
      "efe-standards": {
        "command": "./venv/bin/python",
        "args": ["mcp-standards/server.py"],
        "env": {}
      },
      "efe-docs": {
        "command": "./venv/bin/python",
        "args": ["mcp-docs/server.py"],
        "env": {}
      },
      "efe-project": {
        "command": "./venv/bin/python",
        "args": ["mcp-project/server.py"],
        "env": {}
      }
    }
  }
}
```

### Other Clients (VS Code, Cursor, etc.)

All follow the same pattern — point the `command` to your Python interpreter and `args` to the server script path.

---

## Tools Reference

### `mcp-units` (5 tools)

| Tool | Description |
|------|-------------|
| `unt_convert` | Convert between compatible engineering units (MPa↔Pa, ft↔m, kWh↔J, °C↔K, etc.) |
| `unt_si_normalize` | Normalize any value to SI base units |
| `unt_dimensional_check` | Verify dimensional consistency of equations |
| `unt_physical_constants` | CODATA 2022 constants: G, c, h, k_B, N_A, g, etc. |
| `unt_unit_list` | List all available units by quantity type |

### `mcp-physics` (12 tools)

| Tool | Description |
|------|-------------|
| `phy_beam_analysis` | Bending, shear, deflection, stress, SF for 4 support types + 4 load types |
| `phy_column_buckling` | Euler / Johnson buckling analysis with 4 end conditions |
| `phy_stress_analysis` | Combined axial/bending/shear/torsion → von Mises → safety factor |
| `phy_fatigue_analysis` | Modified endurance limit via Marin factors (Goodman/Soderberg/Gerber) |
| `phy_heat_conduction` | Steady-state conduction: flat wall, cylinder, sphere, composite |
| `phy_convection` | Nusselt-correlation convection (forced + natural, multiple geometries) |
| `phy_pipe_flow` | Reynolds, friction factor (Colebrook), pressure drop, pump power |
| `phy_pressure_vessel` | Thin/thick wall hoop/axial stress, Lamé equations |
| `phy_spring_design` | Helical spring rate, Wahl-corrected shear stress, SF |
| `phy_gear_bending` | Lewis bending check for spur gears |
| `phy_impact_analysis` | Impact force from drop height or velocity |
| `phy_electrical_power` | DC/AC single-phase/three-phase power calculations |

### `mcp-materials` (6 tools)

| Tool | Description |
|------|-------------|
| `mat_lookup` | Full property sheet for any of 20 materials |
| `mat_search` | Search by EFE tier, class, property ranges, renewable/recyclable |
| `mat_compare` | Side-by-side comparison of 2–6 materials |
| `mat_carbon_intensity` | Cradle-to-gate CO₂e for a material mass |
| `mat_efe_compliance` | Evaluate material against all 7 EFE principles |
| `mat_find_alternatives` | Find EFE-superior alternatives with property trade-off analysis |

### `mcp-framework` (8 tools)

| Tool | Description |
|------|-------------|
| `frm_efe_filter` | Evaluate design against all 7 EFE Filter principles (pass/fail) |
| `frm_dual_axis_calibrate` | Calibrate EFE vs OPTIBEST axes for a task |
| `frm_optibest_score` | Score a single OPTIBEST dimension with evidence |
| `frm_gap_detect` | Detect gaps in a design across OPTIBEST dimensions |
| `frm_enhancement_delta` | Quantify improvement from one iteration to the next |
| `frm_fmea_calculate` | Calculate RPN with severity/occurrence/detection |
| `frm_constraint_classify` | Classify constraints by type (physical/resource/regulatory/etc.) |
| `frm_plateau_verify` | 5-method plateau verification (certifies zero-delta) |

### `mcp-lifecycle` (4 tools)

| Tool | Description |
|------|-------------|
| `lca_quick` | Rapid LCA: materials, manufacturing, transport, use, end-of-life |
| `lca_carbon_budget` | Full carbon budget with optional sequestration |
| `lca_circularity` | Circularity metric: recycled content, recyclability, hazardous waste |
| `lca_repair_index` | Repairability score: fasteners, modules, tools, steps, documentation |

### `mcp-standards` (4 tools)

| Tool | Description |
|------|-------------|
| `std_iso_tolerance` | ISO 286 hole/shaft fit tolerances (H7/f6 through H9/d9) |
| `std_safety_factor` | Recommended safety factors for 13 application classes |
| `std_fastener_specs` | M3–M24 bolt specs (pitch, torque, shear, UTS) with grade scaling |
| `std_surface_finish` | Surface finish lookup or find suitable process by required Ra |

### `mcp-docs` (4 tools)

| Tool | Description |
|------|-------------|
| `doc_generate_blueprint` | Generate a structured ODF-format engineering blueprint |
| `doc_create_bom` | Create a formatted bill of materials table |
| `doc_fmea_table` | Create a formatted FMEA table (sorted by RPN) |
| `doc_optibest_certificate` | Generate OPTIBEST delivery certification document |

### `mcp-project` (6 tools)

| Tool | Description |
|------|-------------|
| `prj_init` | Initialize a project with ID, name, purpose, magnitude, scale, rigor |
| `prj_log_decision` | Log a design decision with rationale and alternatives |
| `prj_log_assumption` | Log an assumption with basis and risk-if-wrong |
| `prj_log_risk` | Log a risk with L/I scoring → RPN → level (LOW/MEDIUM/HIGH/CRITICAL) |
| `prj_iteration_record` | Record an OPTIBEST iteration cycle with delta tracking |
| `prj_status` | Project status summary: decisions, assumptions, risks, iterations |

---

## Cross-Platform Notes

| Platform | Python | Paths | Notes |
|----------|--------|-------|-------|
| **Linux** | `python3` | `/path/to/venv/bin/python` | Native. Test with `source venv/bin/activate` |
| **macOS** | `python3` | `/path/to/venv/bin/python` | Same as Linux. Avoid system Python; use venv |
| **Windows** | `python` | `.\venv\Scripts\python.exe` | Use cmd or PowerShell. Forward slashes work in JSON config. Watch for CRLF in scripts |

### Windows-specific notes
- Activate venv with `venv\Scripts\activate`
- In JSON configs, use `"command": ".\\venv\\Scripts\\python.exe"` or `"command": "./venv/Scripts/python.exe"`
- The `.sh` validation script requires WSL or Git Bash on Windows

---

## Validation

```bash
# Ensure venv is activated, then:
bash validate_all.sh
```

This tests all 8 servers:
1. Initializes each server via JSON-RPC
2. Calls one representative tool per server
3. Verifies tool count matches expected
4. Reports pass/fail per server

---

## Architecture

```
MCPs/
├── README.md
├── validate_all.sh
├── shared/
│   └── materials_db.py          # 20-material database (shared by mcp-materials & mcp-lifecycle)
├── mcp-units/server.py          # Unit conversions & constants
├── mcp-physics/server.py        # Structural & thermal physics
├── mcp-materials/server.py      # Materials database & EFE compliance
├── mcp-framework/server.py      # OPTIBEST framework engine
├── mcp-lifecycle/server.py      # LCA & circularity
├── mcp-standards/server.py      # ISO standards & safety factors
├── mcp-docs/server.py           # ODF document generation
└── mcp-project/server.py        # Project state management
```

### Dependency Graph

```
mcp-project     (standalone — file-based state)
mcp-docs        (standalone — ODF text generation)
mcp-standards   (standalone — built-in tables)
mcp-units       (standalone — built-in tables)
mcp-physics     (standalone — pure computation)
mcp-framework   (standalone — pure computation)
mcp-lifecycle ──→ shared/materials_db.py
mcp-materials ──→ shared/materials_db.py
```

All servers use **Python MCP SDK's `FastMCP`** and communicate via **stdio transport**. No network ports, no databases (except `mcp-project` which persists to local JSON files). Each server is independently runnable.

---

## EFE Filter (7 Principles)

Every tool is designed to support engineering within these principles:

| # | Principle | Meaning |
|---|-----------|---------|
| 1 | **Sustainable** | Low-carbon materials & processes |
| 2 | **Renewable** | Bio-based, rapidly renewable inputs |
| 3 | **Accessible** | Globally deployable, patent-free |
| 4 | **Open** | Fully documented, open-source |
| 5 | **Local-First** | Regionally sourced, locally repairable |
| 6 | **Circular** | Recyclable, compostable, recoverable |
| 7 | **Durable** | Long-life, upgradeable design |

Materials are tiered **1 (preferred) → 4 (prohibited)** based on these principles.

---

## License

This is an open engineering toolkit. All server source code is provided for use, modification, and distribution in service of sustainable engineering. Attribution appreciated but not required.

---

*Built with the EFE OPTIBEST ENGINE. 49 tools. Zero compromises.*
