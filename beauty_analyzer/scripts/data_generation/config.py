"""
Data Generation Configuration
=============================
Centralized configuration for all data generation scripts.
"""

import os
from pathlib import Path

# ============================================================================
# PATHS
# ============================================================================

# Base paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
DATA_DIR = PROJECT_ROOT / "data"
SAMPLE_IMAGES_DIR = PROJECT_ROOT / "sample_images"

# Input data paths
FAIRFACE_DIR = SAMPLE_IMAGES_DIR / "fairface_data" / "FairFace"
FAIRFACE_LABELS = FAIRFACE_DIR / "train_labels.csv"
FAIRFACE_IMAGES = FAIRFACE_DIR / "train"
HERO_IMAGES_DIR = SAMPLE_IMAGES_DIR / "hero_images"

# Output paths
OUTPUT_DIR = DATA_DIR / "generated"
CSV_OUTPUT_DIR = OUTPUT_DIR / "csv"
IMAGES_OUTPUT_DIR = OUTPUT_DIR / "images"
LABELS_OUTPUT_DIR = IMAGES_OUTPUT_DIR / "labels"
SWATCHES_OUTPUT_DIR = IMAGES_OUTPUT_DIR / "swatches"
FACES_OUTPUT_DIR = IMAGES_OUTPUT_DIR / "faces"

# Create output directories
for dir_path in [CSV_OUTPUT_DIR, LABELS_OUTPUT_DIR, SWATCHES_OUTPUT_DIR, FACES_OUTPUT_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# ============================================================================
# DATA GENERATION SETTINGS
# ============================================================================

# Customer settings
CUSTOMER_COUNT = 2000
CUSTOMER_GENDER_SPLIT = {"Female": 0.80, "Male": 0.20}
CUSTOMER_AGE_DISTRIBUTION = {
    "18-24": 0.15,
    "25-34": 0.35,
    "35-44": 0.25,
    "45-54": 0.15,
    "55+": 0.10
}
LOYALTY_TIERS = {
    "Bronze": 0.50,
    "Silver": 0.30,
    "Gold": 0.15,
    "Platinum": 0.05
}

# Product settings
PRODUCT_COUNT = 2000
VARIANTS_PER_PRODUCT = 4
INGREDIENTS_PER_PRODUCT = 15
WARNINGS_PER_PRODUCT = 2
PRICE_HISTORY_PER_PRODUCT = 10

# Product categories with hero image mapping
PRODUCT_CATEGORIES = {
    "lips": {
        "subcategories": ["lipstick", "lipgloss", "lip liner", "lip balm"],
        "weight": 0.25,
        "hero_folder": "lips"
    },
    "face": {
        "subcategories": ["foundation", "concealer", "powder", "blush", "bronzer", "highlighter"],
        "weight": 0.30,
        "hero_folder": "face"
    },
    "eyes": {
        "subcategories": ["eyeshadow", "mascara", "eyeliner", "brow"],
        "weight": 0.20,
        "hero_folder": "eyes"
    },
    "skincare": {
        "subcategories": ["moisturizer", "serum", "cleanser", "sunscreen", "mask", "toner"],
        "weight": 0.15,
        "hero_folder": "skincare"
    },
    "nails": {
        "subcategories": ["nail polish", "nail treatment"],
        "weight": 0.05,
        "hero_folder": "nails"
    },
    "fragrance": {
        "subcategories": ["perfume", "body mist"],
        "weight": 0.025,
        "hero_folder": "fragrance"
    },
    "tools": {
        "subcategories": ["brushes", "sponges", "applicators"],
        "weight": 0.025,
        "hero_folder": "tools"
    }
}

# Inventory settings
LOCATION_COUNT = 25
LOCATIONS_BREAKDOWN = {"warehouse": 5, "store": 18, "popup": 2}

# Social settings
REVIEWS_PER_PRODUCT = 20
SOCIAL_MENTIONS_COUNT = 15000
INFLUENCER_MENTIONS_COUNT = 5000

# Cart/Order settings
CART_SESSIONS_COUNT = 2000
ORDERS_COUNT = 10000
ITEMS_PER_CART = 4
ITEMS_PER_ORDER = 4

# ============================================================================
# LABEL GENERATION SETTINGS
# ============================================================================

LABEL_FORMATS = ["vertical", "horizontal", "tabular", "minimalist", "dense", "luxury"]
LABEL_WIDTH = 400
LABEL_HEIGHT = 600

# ============================================================================
# BRANDS (Sample cosmetic brands)
# ============================================================================

COSMETIC_BRANDS = [
    "MAC", "NARS", "Fenty Beauty", "Charlotte Tilbury", "Urban Decay",
    "Too Faced", "Benefit", "Tarte", "Anastasia Beverly Hills", "Huda Beauty",
    "Pat McGrath Labs", "Rare Beauty", "NYX", "Maybelline", "L'Oreal",
    "Clinique", "Estee Lauder", "Lancome", "Bobbi Brown", "Laura Mercier",
    "Hourglass", "ILIA", "Kosas", "Tower 28", "Milk Makeup",
    "Glossier", "Summer Fridays", "Drunk Elephant", "The Ordinary", "CeraVe"
]

# ============================================================================
# SAMPLE INGREDIENTS (Realistic cosmetic ingredients)
# ============================================================================

SAMPLE_INGREDIENTS = {
    "lips": [
        "Ricinus Communis (Castor) Seed Oil", "Octyldodecanol", "Candelilla Cera",
        "Synthetic Wax", "Polyethylene", "Mica", "Silica", "Tocopherol",
        "Ascorbyl Palmitate", "Caprylic/Capric Triglyceride", "Jojoba Oil",
        "Shea Butter", "Vitamin E", "Beeswax", "Lanolin"
    ],
    "face": [
        "Water/Aqua/Eau", "Dimethicone", "Talc", "PEG-10 Dimethicone",
        "Trimethylsiloxysilicate", "Isododecane", "Nylon-12", "Phenoxyethanol",
        "Glycerin", "Sodium Hyaluronate", "Titanium Dioxide", "Iron Oxides",
        "Silica", "Zinc Oxide", "Niacinamide"
    ],
    "eyes": [
        "Talc", "Mica", "Dimethicone", "Zinc Stearate", "Silica",
        "Phenoxyethanol", "Tocopherol", "Caprylic/Capric Triglyceride",
        "Iron Oxides", "Titanium Dioxide", "Carmine", "Ultramarines",
        "Chromium Oxide Greens", "Ferric Ferrocyanide", "Manganese Violet"
    ],
    "skincare": [
        "Water/Aqua/Eau", "Glycerin", "Butylene Glycol", "Dimethicone",
        "Niacinamide", "Hyaluronic Acid", "Sodium Hyaluronate", "Squalane",
        "Ceramide NP", "Tocopherol", "Ascorbic Acid", "Retinol",
        "Salicylic Acid", "Centella Asiatica Extract", "Green Tea Extract"
    ],
    "nails": [
        "Butyl Acetate", "Ethyl Acetate", "Nitrocellulose", "Adipic Acid",
        "Isopropyl Alcohol", "Acetyl Tributyl Citrate", "Tosylamide",
        "Formaldehyde Resin", "Camphor", "Benzophenone-1"
    ],
    "fragrance": [
        "Alcohol Denat.", "Parfum/Fragrance", "Aqua/Water", "Limonene",
        "Linalool", "Citronellol", "Geraniol", "Coumarin", "Benzyl Benzoate"
    ],
    "tools": []
}

# ============================================================================
# SAMPLE WARNINGS
# ============================================================================

SAMPLE_WARNINGS = [
    ("usage", "For external use only", "info"),
    ("usage", "Avoid contact with eyes", "caution"),
    ("usage", "Discontinue use if irritation occurs", "warning"),
    ("storage", "Keep out of reach of children", "caution"),
    ("storage", "Store in a cool, dry place", "info"),
    ("allergy", "May contain traces of nuts", "warning"),
    ("allergy", "Contains fragrance", "info"),
    ("safety", "Do not use on broken or irritated skin", "caution"),
]

# ============================================================================
# COLOR PALETTES (For swatch generation)
# ============================================================================

LIPSTICK_COLORS = [
    ("#C41E3A", "Ruby Red"), ("#8B0000", "Dark Red"), ("#DC143C", "Crimson"),
    ("#FF6B6B", "Coral"), ("#E75480", "Dark Pink"), ("#FF69B4", "Hot Pink"),
    ("#FFB6C1", "Light Pink"), ("#FFC0CB", "Pink"), ("#DDA0DD", "Plum"),
    ("#800020", "Burgundy"), ("#A52A2A", "Brown"), ("#D2691E", "Chocolate"),
    ("#CD853F", "Peru"), ("#F5DEB3", "Wheat"), ("#FFDAB9", "Peach"),
    ("#FF7F50", "Coral Orange"), ("#FF4500", "Orange Red"), ("#B22222", "Firebrick"),
    ("#8B4513", "Saddle Brown"), ("#A0522D", "Sienna")
]

FOUNDATION_COLORS = [
    ("#FFF5E1", "Porcelain"), ("#FFE4C4", "Bisque"), ("#FFDAB9", "Peach"),
    ("#F5DEB3", "Wheat"), ("#DEB887", "Burlywood"), ("#D2B48C", "Tan"),
    ("#C19A6B", "Camel"), ("#B8860B", "Dark Goldenrod"), ("#A0522D", "Sienna"),
    ("#8B4513", "Saddle Brown"), ("#654321", "Dark Brown"), ("#3D2914", "Espresso"),
    ("#F5F5DC", "Beige"), ("#FAF0E6", "Linen"), ("#FDF5E6", "Old Lace"),
    ("#FAEBD7", "Antique White"), ("#FFE4B5", "Moccasin"), ("#FFEBCD", "Blanched Almond"),
    ("#D2691E", "Chocolate"), ("#CD853F", "Peru")
]

EYESHADOW_COLORS = [
    ("#000000", "Black"), ("#36454F", "Charcoal"), ("#808080", "Gray"),
    ("#C0C0C0", "Silver"), ("#FFD700", "Gold"), ("#B8860B", "Dark Gold"),
    ("#800080", "Purple"), ("#4B0082", "Indigo"), ("#8B008B", "Dark Magenta"),
    ("#DA70D6", "Orchid"), ("#0000FF", "Blue"), ("#4169E1", "Royal Blue"),
    ("#1E90FF", "Dodger Blue"), ("#00CED1", "Dark Turquoise"), ("#008080", "Teal"),
    ("#228B22", "Forest Green"), ("#6B8E23", "Olive Drab"), ("#556B2F", "Dark Olive"),
    ("#FFE4E1", "Misty Rose"), ("#FFF0F5", "Lavender Blush")
]

NAIL_COLORS = [
    ("#FF0000", "Red"), ("#FF1493", "Deep Pink"), ("#FF69B4", "Hot Pink"),
    ("#FFB6C1", "Light Pink"), ("#800080", "Purple"), ("#4B0082", "Indigo"),
    ("#0000FF", "Blue"), ("#00FFFF", "Cyan"), ("#008080", "Teal"),
    ("#00FF00", "Lime"), ("#228B22", "Forest Green"), ("#FFD700", "Gold"),
    ("#FFA500", "Orange"), ("#FF4500", "Orange Red"), ("#8B0000", "Dark Red"),
    ("#A52A2A", "Brown"), ("#000000", "Black"), ("#FFFFFF", "White"),
    ("#F5F5DC", "Beige"), ("#D3D3D3", "Light Gray")
]

print(f"Configuration loaded. Output directory: {OUTPUT_DIR}")

