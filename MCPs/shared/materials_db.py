"""
EFE Materials Database — 20 materials, EFE-annotated
Tiers: 1=PREFERRED, 2=ACCEPTABLE, 3=AVOID, 4=PROHIBITED
"""

MATERIALS = {
    "steel_s275": {
        "name": "Structural Steel S275", "class": "metal",
        "density": 7850.0, "E_GPa": 200.0, "nu": 0.30,
        "yield_MPa": 275.0, "uts_MPa": 410.0,
        "k_W_mK": 50.0, "cp_J_kgK": 500.0, "alpha_um_mK": 12.0,
        "T_melt_C": 1425.0, "hardness_HB": 130.0,
        "efe_tier": 2, "recycle_pct": 85.0, "co2_kg_per_kg": 1.8,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Most common structural steel. 85% recycling rate globally.",
        "eol_path": "Steel scrap → EAF smelting → new steel",
        "alternatives": ["bamboo_structural", "hemp_composite", "recycled_steel"],
        "local_availability": "global"
    },
    "steel_304": {
        "name": "Stainless Steel 304", "class": "metal",
        "density": 7930.0, "E_GPa": 193.0, "nu": 0.29,
        "yield_MPa": 215.0, "uts_MPa": 505.0,
        "k_W_mK": 16.2, "cp_J_kgK": 500.0, "alpha_um_mK": 17.2,
        "T_melt_C": 1455.0, "hardness_HB": 150.0,
        "efe_tier": 2, "recycle_pct": 80.0, "co2_kg_per_kg": 3.5,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Austenitic stainless. High Ni/Cr raises CO2 vs carbon steel.",
        "eol_path": "Stainless scrap → AOD furnace → new stainless",
        "alternatives": ["steel_duplex_lean", "aluminum_6061_t6"],
        "local_availability": "global"
    },
    "aluminum_6061_t6": {
        "name": "Aluminum Alloy 6061-T6", "class": "metal",
        "density": 2700.0, "E_GPa": 68.9, "nu": 0.33,
        "yield_MPa": 276.0, "uts_MPa": 310.0,
        "k_W_mK": 167.0, "cp_J_kgK": 896.0, "alpha_um_mK": 23.6,
        "T_melt_C": 652.0, "hardness_HB": 95.0,
        "efe_tier": 2, "recycle_pct": 75.0, "co2_kg_per_kg": 9.2,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Versatile alloy. High primary CO2; recycled Al = 0.35 kg/kg.",
        "eol_path": "Al scrap → secondary smelting (saves 95% energy vs primary)",
        "alternatives": ["bamboo_structural", "hemp_composite"],
        "local_availability": "global"
    },
    "copper_c101": {
        "name": "Copper C101 (ETP)", "class": "metal",
        "density": 8960.0, "E_GPa": 117.0, "nu": 0.34,
        "yield_MPa": 70.0, "uts_MPa": 220.0,
        "k_W_mK": 385.0, "cp_J_kgK": 385.0, "alpha_um_mK": 17.7,
        "T_melt_C": 1083.0, "hardness_HB": 50.0,
        "efe_tier": 2, "recycle_pct": 90.0, "co2_kg_per_kg": 4.0,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Highest conductivity metal. 90% recycling rate. Use sparingly.",
        "eol_path": "Cu scrap → electrolytic refining → new copper",
        "alternatives": ["aluminum_c101_equiv"],
        "local_availability": "global"
    },
    "titanium_6al4v": {
        "name": "Titanium Ti-6Al-4V", "class": "metal",
        "density": 4430.0, "E_GPa": 114.0, "nu": 0.33,
        "yield_MPa": 880.0, "uts_MPa": 950.0,
        "k_W_mK": 6.7, "cp_J_kgK": 520.0, "alpha_um_mK": 8.6,
        "T_melt_C": 1660.0, "hardness_HB": 300.0,
        "efe_tier": 3, "recycle_pct": 50.0, "co2_kg_per_kg": 35.0,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "EFE AVOID: extremely energy-intensive. Justify for safety-critical only.",
        "eol_path": "Ti scrap → Kroll process → new titanium (limited)",
        "alternatives": ["steel_s275", "aluminum_6061_t6"],
        "local_availability": "limited"
    },
    "pla": {
        "name": "PLA (Polylactic Acid)", "class": "biopolymer",
        "density": 1240.0, "E_GPa": 3.5, "nu": 0.36,
        "yield_MPa": 50.0, "uts_MPa": 60.0,
        "k_W_mK": 0.13, "cp_J_kgK": 1800.0, "alpha_um_mK": 68.0,
        "T_melt_C": 160.0, "hardness_HB": 80.0,
        "efe_tier": 1, "recycle_pct": 60.0, "co2_kg_per_kg": 2.2,
        "renewable": True, "recyclable": True, "compostable": True,
        "notes": "EFE PREFERRED: bio-sourced corn/sugarcane. Industrial compostable.",
        "eol_path": "Industrial composting OR mechanical recycling into PLA pellets",
        "alternatives": ["recycled_hdpe", "mycelium_composite"],
        "local_availability": "global"
    },
    "abs_polymer": {
        "name": "ABS (Acrylonitrile Butadiene Styrene)", "class": "polymer",
        "density": 1050.0, "E_GPa": 2.3, "nu": 0.40,
        "yield_MPa": 40.0, "uts_MPa": 48.0,
        "k_W_mK": 0.17, "cp_J_kgK": 1400.0, "alpha_um_mK": 90.0,
        "T_melt_C": 220.0, "hardness_HB": 70.0,
        "efe_tier": 2, "recycle_pct": 35.0, "co2_kg_per_kg": 3.2,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Petroleum-based. Prefer PLA or rHDPE where function allows.",
        "eol_path": "Mechanical recycling (limited); some chemical depolymerization",
        "alternatives": ["pla", "recycled_hdpe"],
        "local_availability": "global"
    },
    "recycled_hdpe": {
        "name": "Recycled HDPE (rHDPE)", "class": "recycled_polymer",
        "density": 960.0, "E_GPa": 0.9, "nu": 0.40,
        "yield_MPa": 20.0, "uts_MPa": 28.0,
        "k_W_mK": 0.48, "cp_J_kgK": 1800.0, "alpha_um_mK": 120.0,
        "T_melt_C": 130.0, "hardness_HB": 65.0,
        "efe_tier": 1, "recycle_pct": 95.0, "co2_kg_per_kg": 0.45,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "EFE PREFERRED: diverts plastic waste. CO2 = 0.45 vs 1.8 kg/kg virgin.",
        "eol_path": "Re-granulation → new rHDPE products",
        "alternatives": ["pla", "hemp_composite"],
        "local_availability": "global"
    },
    "bamboo_structural": {
        "name": "Structural Bamboo (Moso)", "class": "natural_composite",
        "density": 700.0, "E_GPa": 20.0, "nu": 0.30,
        "yield_MPa": 100.0, "uts_MPa": 160.0,
        "k_W_mK": 0.17, "cp_J_kgK": 1300.0, "alpha_um_mK": 5.0,
        "T_melt_C": 300.0, "hardness_HB": 30.0,
        "efe_tier": 1, "recycle_pct": 100.0, "co2_kg_per_kg": -1.2,
        "renewable": True, "recyclable": True, "compostable": True,
        "notes": "EFE PREMIUM TIER 1: carbon-NEGATIVE, fastest-growing plant, local-growable.",
        "eol_path": "Compost OR chip for biomass OR return to soil",
        "alternatives": ["wood_oak_fsc", "steel_s275"],
        "local_availability": "tropical/subtropical"
    },
    "hemp_composite": {
        "name": "Hemp Fiber / Bio-resin Composite", "class": "natural_composite",
        "density": 1350.0, "E_GPa": 15.0, "nu": 0.30,
        "yield_MPa": 80.0, "uts_MPa": 120.0,
        "k_W_mK": 0.22, "cp_J_kgK": 1700.0, "alpha_um_mK": 20.0,
        "T_melt_C": 250.0, "hardness_HB": 25.0,
        "efe_tier": 1, "recycle_pct": 100.0, "co2_kg_per_kg": 0.5,
        "renewable": True, "recyclable": True, "compostable": True,
        "notes": "EFE TIER 1: hemp grows in 3mo, no pesticides, low water. Outperforms GF in many apps.",
        "eol_path": "Compost OR shred for insulation OR soil amendment",
        "alternatives": ["bamboo_structural", "glass_fiber_gfrp"],
        "local_availability": "temperate global"
    },
    "mycelium_composite": {
        "name": "Mycelium / Agri-waste Composite", "class": "bio_grown",
        "density": 250.0, "E_GPa": 0.15, "nu": 0.30,
        "yield_MPa": 0.5, "uts_MPa": 0.8,
        "k_W_mK": 0.04, "cp_J_kgK": 1500.0, "alpha_um_mK": 25.0,
        "T_melt_C": 200.0, "hardness_HB": 5.0,
        "efe_tier": 1, "recycle_pct": 100.0, "co2_kg_per_kg": 0.1,
        "renewable": True, "recyclable": True, "compostable": True,
        "notes": "EFE APEX TIER 1: grown on agricultural waste in days. Insulation/packaging.",
        "eol_path": "100% compostable in weeks",
        "alternatives": ["recycled_hdpe", "pla"],
        "local_availability": "any (home-growable)"
    },
    "wood_oak_fsc": {
        "name": "White Oak FSC-Certified", "class": "wood",
        "density": 770.0, "E_GPa": 12.0, "nu": 0.45,
        "yield_MPa": 50.0, "uts_MPa": 100.0,
        "k_W_mK": 0.17, "cp_J_kgK": 1700.0, "alpha_um_mK": 4.0,
        "T_melt_C": 270.0, "hardness_HB": 60.0,
        "efe_tier": 1, "recycle_pct": 100.0, "co2_kg_per_kg": -0.9,
        "renewable": True, "recyclable": True, "compostable": True,
        "notes": "EFE TIER 1 (FSC): carbon-sequestering, repairable, compostable at EoL.",
        "eol_path": "Reuse → reclaim → chip/biomass → compost",
        "alternatives": ["bamboo_structural", "hemp_composite"],
        "local_availability": "temperate global"
    },
    "concrete_c25": {
        "name": "Normal Concrete C25/30", "class": "mineral",
        "density": 2400.0, "E_GPa": 30.0, "nu": 0.20,
        "yield_MPa": 25.0, "uts_MPa": 2.5,
        "k_W_mK": 1.7, "cp_J_kgK": 880.0, "alpha_um_mK": 12.0,
        "T_melt_C": 1400.0, "hardness_HB": 100.0,
        "efe_tier": 2, "recycle_pct": 70.0, "co2_kg_per_kg": 0.16,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Cement = 8% global CO2. Specify SCM (GGBS/fly ash) to reduce. High total volume = high impact.",
        "eol_path": "Crushing → recycled aggregate (downgraded use)",
        "alternatives": ["rammed_earth", "timber_frame", "hemp_lime"],
        "local_availability": "global"
    },
    "glass_fiber_gfrp": {
        "name": "Glass Fiber Reinforced Polymer (GFRP)", "class": "composite",
        "density": 1800.0, "E_GPa": 45.0, "nu": 0.28,
        "yield_MPa": 400.0, "uts_MPa": 600.0,
        "k_W_mK": 0.35, "cp_J_kgK": 840.0, "alpha_um_mK": 14.0,
        "T_melt_C": 300.0, "hardness_HB": 80.0,
        "efe_tier": 2, "recycle_pct": 25.0, "co2_kg_per_kg": 3.0,
        "renewable": False, "recyclable": True, "compostable": False,
        "notes": "Difficult to recycle. Prefer hemp/flax composite where strength permits.",
        "eol_path": "Grinding for cement filler OR pyrolysis (limited)",
        "alternatives": ["hemp_composite", "bamboo_structural"],
        "local_availability": "global"
    },
    "carbon_fiber_cfrp": {
        "name": "Carbon Fiber Reinforced Polymer (CFRP)", "class": "advanced_composite",
        "density": 1550.0, "E_GPa": 135.0, "nu": 0.28,
        "yield_MPa": 1200.0, "uts_MPa": 1500.0,
        "k_W_mK": 5.0, "cp_J_kgK": 840.0, "alpha_um_mK": 0.5,
        "T_melt_C": 300.0, "hardness_HB": 150.0,
        "efe_tier": 3, "recycle_pct": 15.0, "co2_kg_per_kg": 26.0,
        "renewable": False, "recyclable": False, "compostable": False,
        "notes": "EFE AVOID: 26 kg CO2/kg, nearly non-recyclable. Only for irreplaceable performance.",
        "eol_path": "Pyrolysis (reclaims fiber at ~30% strength) OR landfill",
        "alternatives": ["hemp_composite", "aluminum_6061_t6"],
        "local_availability": "limited"
    },
}

MATERIAL_CLASSES = list({m["class"] for m in MATERIALS.values()})

def get_material(mid):
    return MATERIALS.get(mid)

def search_materials(filters=None, efe_tier_max=4, class_filter=None,
                     renewable_only=False, recyclable_only=False):
    results = []
    for mid, mat in MATERIALS.items():
        if mat["efe_tier"] > efe_tier_max:
            continue
        if class_filter and mat["class"] != class_filter:
            continue
        if renewable_only and not mat["renewable"]:
            continue
        if recyclable_only and not mat["recyclable"]:
            continue
        if filters:
            ok = True
            for prop, (lo, hi) in filters.items():
                val = mat.get(prop)
                if val is None or not (lo <= val <= hi):
                    ok = False
                    break
            if not ok:
                continue
        results.append((mid, mat))
    return results
