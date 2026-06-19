#!/usr/bin/env python3
"""efe_units_mcp — Unit conversion, SI normalisation, physical constants, dimensional analysis."""
import sys, os
sys.path.insert(0, "/var/home/ryan/.local/share/efe-mcps/shared")

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
import json, math

mcp = FastMCP("efe_units_mcp")

# ── Physical Constants (CODATA 2022) ──────────────────────────────────────────
CONSTANTS = {
    "c":       {"value": 299792458.0,      "unit": "m/s",         "name": "Speed of light"},
    "G":       {"value": 6.67430e-11,      "unit": "m³/(kg·s²)",  "name": "Gravitational constant"},
    "h":       {"value": 6.62607015e-34,   "unit": "J·s",         "name": "Planck constant"},
    "hbar":    {"value": 1.054571817e-34,  "unit": "J·s",         "name": "Reduced Planck constant"},
    "k_B":     {"value": 1.380649e-23,     "unit": "J/K",         "name": "Boltzmann constant"},
    "N_A":     {"value": 6.02214076e23,    "unit": "mol⁻¹",       "name": "Avogadro constant"},
    "R":       {"value": 8.314462618,      "unit": "J/(mol·K)",   "name": "Gas constant"},
    "e":       {"value": 1.602176634e-19,  "unit": "C",           "name": "Elementary charge"},
    "epsilon0":{"value": 8.8541878128e-12, "unit": "F/m",         "name": "Vacuum permittivity"},
    "mu0":     {"value": 1.25663706212e-6, "unit": "H/m",         "name": "Vacuum permeability"},
    "sigma_SB":{"value": 5.670374419e-8,   "unit": "W/(m²·K⁴)",  "name": "Stefan-Boltzmann constant"},
    "g":       {"value": 9.80665,          "unit": "m/s²",        "name": "Standard gravity"},
    "atm":     {"value": 101325.0,         "unit": "Pa",          "name": "Standard atmosphere"},
    "R_earth": {"value": 6371000.0,        "unit": "m",           "name": "Earth mean radius"},
    "m_e":     {"value": 9.1093837015e-31, "unit": "kg",          "name": "Electron mass"},
    "m_p":     {"value": 1.67262192369e-27,"unit": "kg",          "name": "Proton mass"},
}

# ── Conversion table: (factor_to_SI, SI_unit, dimension) ──────────────────────
UNITS = {
    # Length
    "m":    (1.0,        "m",   "length"), "km": (1e3, "m", "length"),
    "cm":   (0.01,       "m",   "length"), "mm": (1e-3,"m","length"),
    "um":   (1e-6,       "m",   "length"), "nm": (1e-9,"m","length"),
    "in":   (0.0254,     "m",   "length"), "ft": (0.3048,"m","length"),
    "yd":   (0.9144,     "m",   "length"), "mi": (1609.344,"m","length"),
    # Mass
    "kg":   (1.0,        "kg",  "mass"),   "g":  (1e-3,"kg","mass"),
    "mg":   (1e-6,       "kg",  "mass"),   "t":  (1e3,"kg","mass"),
    "lb":   (0.45359237, "kg",  "mass"),   "oz": (0.028349523,"kg","mass"),
    "ton_uk":(1016.047,  "kg",  "mass"),   "ton_us":(907.185,"kg","mass"),
    # Time
    "s":    (1.0,        "s",   "time"),   "ms": (1e-3,"s","time"),
    "us":   (1e-6,       "s",   "time"),   "min":(60.0,"s","time"),
    "hr":   (3600.0,     "s",   "time"),   "day":(86400.0,"s","time"),
    "yr":   (31557600.0, "s",   "time"),
    # Temperature (handled specially — offsets)
    "K":    (1.0,        "K",   "temperature"),
    "C":    (1.0,        "K",   "temperature"),
    "F":    (5/9,        "K",   "temperature"),
    "R":    (5/9,        "K",   "temperature"),
    # Force
    "N":    (1.0,        "N",   "force"),   "kN": (1e3,"N","force"),
    "MN":   (1e6,        "N",   "force"),   "lbf":(4.44822,"N","force"),
    "kip":  (4448.22,    "N",   "force"),   "dyn":(1e-5,"N","force"),
    # Pressure
    "Pa":   (1.0,        "Pa",  "pressure"),"kPa":(1e3,"Pa","pressure"),
    "MPa":  (1e6,        "Pa",  "pressure"),"GPa":(1e9,"Pa","pressure"),
    "bar":  (1e5,        "Pa",  "pressure"),"mbar":(100.0,"Pa","pressure"),
    "psi":  (6894.757,   "Pa",  "pressure"),"ksi":(6894757.0,"Pa","pressure"),
    "atm":  (101325.0,   "Pa",  "pressure"),"torr":(133.322,"Pa","pressure"),
    # Energy
    "J":    (1.0,        "J",   "energy"),  "kJ": (1e3,"J","energy"),
    "MJ":   (1e6,        "J",   "energy"),  "GJ": (1e9,"J","energy"),
    "Wh":   (3600.0,     "J",   "energy"),  "kWh":(3.6e6,"J","energy"),
    "cal":  (4.184,      "J",   "energy"),  "kcal":(4184.0,"J","energy"),
    "BTU":  (1055.06,    "J",   "energy"),  "eV": (1.602e-19,"J","energy"),
    # Power
    "W":    (1.0,        "W",   "power"),   "kW": (1e3,"W","power"),
    "MW":   (1e6,        "W",   "power"),   "hp": (745.7,"W","power"),
    # Angle
    "rad":  (1.0,        "rad", "angle"),   "deg":(math.pi/180,"rad","angle"),
    "rev":  (2*math.pi,  "rad", "angle"),
    # Stress/Pressure aliases
    "N_m2": (1.0,        "Pa",  "pressure"),
    "N_mm2":(1e6,        "Pa",  "pressure"),
    # Velocity
    "m_s":  (1.0,        "m/s", "velocity"),"km_h":(1/3.6,"m/s","velocity"),
    "mph":  (0.44704,    "m/s", "velocity"),"knot":(0.5144,"m/s","velocity"),
    # Volume
    "m3":   (1.0,        "m³",  "volume"),  "L":  (1e-3,"m³","volume"),
    "mL":   (1e-6,       "m³",  "volume"),  "cm3":(1e-6,"m³","volume"),
    "gal_us":(0.003785,  "m³",  "volume"),  "ft3":(0.028317,"m³","volume"),
    # Flow rate
    "m3_s": (1.0,        "m³/s","flow"),    "L_s":(1e-3,"m³/s","flow"),
    "L_min":(1/60000,    "m³/s","flow"),    "gpm":(6.309e-5,"m³/s","flow"),
    # Thermal conductivity
    "W_mK": (1.0,        "W/(m·K)","thermal_conductivity"),
    # Specific heat
    "J_kgK":(1.0,        "J/(kg·K)","specific_heat"),
    # Frequency
    "Hz":   (1.0,        "Hz",  "frequency"),"kHz":(1e3,"Hz","frequency"),
    "MHz":  (1e6,        "Hz",  "frequency"),"rpm":(1/60,"Hz","frequency"),
    # Torque
    "Nm":   (1.0,        "N·m", "torque"),  "kNm":(1e3,"N·m","torque"),
    "lbft": (1.35582,    "N·m", "torque"),  "lbin":(0.113,"N·m","torque"),
}

def _temp_to_K(val, unit):
    if unit == "C":  return val + 273.15
    if unit == "F":  return (val + 459.67) * 5/9
    if unit == "R":  return val * 5/9
    return val

def _K_to_unit(K, unit):
    if unit == "C":  return K - 273.15
    if unit == "F":  return K * 9/5 - 459.67
    if unit == "R":  return K * 9/5
    return K

class ConvertInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    value: float = Field(..., description="Numeric value to convert")
    from_unit: str = Field(..., description="Source unit (e.g. 'MPa', 'ft', 'kWh', 'C')")
    to_unit: str   = Field(..., description="Target unit (e.g. 'Pa', 'm', 'J', 'K')")

@mcp.tool(name="unt_convert",
          annotations={"readOnlyHint": True, "idempotentHint": True})
async def unt_convert(params: ConvertInput) -> str:
    """Convert a value between any two compatible engineering units.
    Supports: length, mass, time, temperature, force, pressure, energy,
    power, velocity, volume, flow, torque, angle, frequency.
    Returns converted value, conversion factor, and both values in SI.
    """
    fu, tu = params.from_unit, params.to_unit
    v = params.value
    if fu not in UNITS: return json.dumps({"error": f"Unknown unit: {fu}. Try unt_unit_list."})
    if tu not in UNITS: return json.dumps({"error": f"Unknown unit: {tu}. Try unt_unit_list."})
    f_si, f_unit, f_dim = UNITS[fu]
    t_si, t_unit, t_dim = UNITS[tu]
    if f_dim != t_dim:
        return json.dumps({"error": f"Dimension mismatch: {f_dim} ≠ {t_dim}"})
    if f_dim == "temperature":
        si_val = _temp_to_K(v, fu)
        result = _K_to_unit(si_val, tu)
    else:
        si_val = v * f_si
        result = si_val / t_si
    return json.dumps({
        "input": f"{v} {fu}", "output": f"{result:.8g} {tu}",
        "si_value": f"{si_val:.8g} {f_unit}",
        "factor": f"1 {fu} = {f_si/t_si:.8g} {tu}"
    })

class SINormInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    value: float = Field(..., description="Numeric value")
    unit: str    = Field(..., description="Unit of the value")

@mcp.tool(name="unt_si_normalize",
          annotations={"readOnlyHint": True, "idempotentHint": True})
async def unt_si_normalize(params: SINormInput) -> str:
    """Normalize any engineering value to its SI base unit.
    Returns SI value, SI unit symbol, and physical dimension.
    """
    u = params.unit
    if u not in UNITS: return json.dumps({"error": f"Unknown unit: {u}"})
    factor, si_unit, dim = UNITS[u]
    if dim == "temperature":
        si_val = _temp_to_K(params.value, u)
    else:
        si_val = params.value * factor
    return json.dumps({"si_value": si_val, "si_unit": si_unit, "dimension": dim,
                       "original": f"{params.value} {u}"})

class DimCheckInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    lhs_units: List[str] = Field(..., description="Units on left-hand side of equation")
    rhs_units: List[str] = Field(..., description="Units on right-hand side of equation")
    lhs_exponents: Optional[List[float]] = Field(None, description="Exponents for LHS units (default all 1)")
    rhs_exponents: Optional[List[float]] = Field(None, description="Exponents for RHS units (default all 1)")

@mcp.tool(name="unt_dimensional_check",
          annotations={"readOnlyHint": True, "idempotentHint": True})
async def unt_dimensional_check(params: DimCheckInput) -> str:
    """Check dimensional consistency of an equation.
    Provide LHS and RHS units (and optional exponents).
    Returns consistent/inconsistent and dimension of each side.
    """
    def dim_of(units, exps):
        dims = {}
        for u, e in zip(units, exps):
            if u not in UNITS: return None, f"Unknown unit: {u}"
            d = UNITS[u][2]
            dims[d] = dims.get(d, 0) + e
        return {k: v for k, v in dims.items() if v != 0}, None
    lhs_e = params.lhs_exponents or [1.0]*len(params.lhs_units)
    rhs_e = params.rhs_exponents or [1.0]*len(params.rhs_units)
    lhs_dim, err = dim_of(params.lhs_units, lhs_e)
    if err: return json.dumps({"error": err})
    rhs_dim, err = dim_of(params.rhs_units, rhs_e)
    if err: return json.dumps({"error": err})
    consistent = lhs_dim == rhs_dim
    return json.dumps({"consistent": consistent, "lhs_dimension": lhs_dim,
                       "rhs_dimension": rhs_dim,
                       "verdict": "DIMENSIONALLY CONSISTENT" if consistent else "DIMENSIONAL ERROR"})

class ConstantsInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    names: Optional[List[str]] = Field(None, description="Constant names (e.g. ['G','k_B','g']). Omit for all.")

@mcp.tool(name="unt_physical_constants",
          annotations={"readOnlyHint": True, "idempotentHint": True})
async def unt_physical_constants(params: ConstantsInput) -> str:
    """Return physical constants (CODATA 2022): G, c, h, hbar, k_B, N_A, R,
    e, epsilon0, mu0, sigma_SB, g, atm, R_earth, m_e, m_p.
    """
    keys = params.names if params.names else list(CONSTANTS.keys())
    result = {}
    for k in keys:
        if k in CONSTANTS: result[k] = CONSTANTS[k]
        else: result[k] = {"error": "unknown constant"}
    return json.dumps(result, indent=2)

class UnitListInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    quantity_type: str = Field(..., description="Dimension category: length, mass, time, temperature, force, pressure, energy, power, velocity, volume, flow, torque, angle, frequency")

@mcp.tool(name="unt_unit_list",
          annotations={"readOnlyHint": True, "idempotentHint": True})
async def unt_unit_list(params: UnitListInput) -> str:
    """List all available units for a given quantity type with SI conversion factors."""
    q = params.quantity_type.lower()
    matches = {sym: {"factor_to_SI": f, "SI_unit": u, "dimension": d}
               for sym, (f, u, d) in UNITS.items() if d == q}
    if not matches:
        avail = sorted(set(d for _, _, d in UNITS.values()))
        return json.dumps({"error": f"Unknown quantity '{q}'", "available": avail})
    return json.dumps({"quantity": q, "units": matches})

if __name__ == "__main__":
    mcp.run(transport="stdio")
