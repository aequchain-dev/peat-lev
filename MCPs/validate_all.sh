#!/usr/bin/env bash
set -euo pipefail

# EFE-MCP Validation Suite — portable version
# Runs from the MCPs/ directory; expects a venv/ subdirectory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="${SCRIPT_DIR}/venv/bin/python"

if [ ! -x "$VENV_PYTHON" ]; then
    echo "ERROR: No venv found at ${VENV_PYTHON}"
    echo "Run: python3 -m venv venv && ./venv/bin/pip install mcp pydantic"
    exit 1
fi

echo "=== EFE MCP VALIDATION SUITE ==="
echo "  Script dir: ${SCRIPT_DIR}"
echo "  Python:     ${VENV_PYTHON}"
echo ""

# Delegate to Python script with SCRIPT_DIR as argument
exec "$VENV_PYTHON" "${SCRIPT_DIR}/validate_all.py" "${SCRIPT_DIR}"
