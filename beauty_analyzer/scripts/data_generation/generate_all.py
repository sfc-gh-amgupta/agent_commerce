"""
Agent Commerce - Complete Data Generation
==========================================
Generates all sample data for the Agent Commerce platform.

Usage:
    python scripts/data_generation/generate_all.py

Phases:
    1. PRODUCTS - Products, variants, media, ingredients, labels
    2. CUSTOMERS - Customer profiles, face embeddings
    3. INVENTORY - Locations, stock levels
    4. SOCIAL - Reviews, social mentions, influencers
    5. CART_OLTP - Cart sessions, orders, payments
"""

import os
import sys
import csv
import json
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from config import *

# Try to import PIL for image generation
try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("⚠️  PIL not installed. Image generation will be skipped.")
    print("   Install with: pip install Pillow")

# Try to import pandas for CSV processing
try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False
    print("⚠️  pandas not installed. Using basic CSV processing.")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def generate_uuid():
    return str(uuid.uuid4())

def random_date(start_days_ago=365, end_days_ago=0):
    """Generate random date within range."""
    days_ago = random.randint(end_days_ago, start_days_ago)
    return (datetime.now() - timedelta(days=days_ago)).strftime("%Y-%m-%d")

def random_timestamp(start_days_ago=365, end_days_ago=0):
    """Generate random timestamp within range."""
    days_ago = random.randint(end_days_ago, start_days_ago)
    hours = random.randint(0, 23)
    minutes = random.randint(0, 59)
    dt = datetime.now() - timedelta(days=days_ago, hours=hours, minutes=minutes)
    return dt.strftime("%Y-%m-%d %H:%M:%S")

def weighted_choice(choices_dict):
    """Select item based on weights."""
    items = list(choices_dict.keys())
    weights = list(choices_dict.values())
    return random.choices(items, weights=weights, k=1)[0]

def write_csv(filepath, data, headers):
    """Write data to CSV file."""
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    
    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(data)
    
    print(f"  ✅ Wrote {len(data)} rows to {filepath.name}")

# ============================================================================
# PHASE 1: PRODUCTS
# ============================================================================

def generate_products():
    """Generate all product-related data."""
    print("\n" + "="*60)
    print("PHASE 1: GENERATING PRODUCTS DATA")
    print("="*60)
    
    products = []
    variants = []
    media = []
    labels = []
    ingredients = []
    warnings = []
    price_history = []
    promotions = []
    
    # Get available hero images
    hero_images = {}
    for category, info in PRODUCT_CATEGORIES.items():
        folder = HERO_IMAGES_DIR / info["hero_folder"]
        if folder.exists():
            hero_images[category] = [f.name for f in folder.glob("*.jpg")]
        else:
            hero_images[category] = []
    
    # Generate products by category
    for category, info in PRODUCT_CATEGORIES.items():
        category_count = int(PRODUCT_COUNT * info["weight"])
        print(f"\n  Generating {category_count} {category} products...")
        
        for i in range(category_count):
            product_id = generate_uuid()
            brand = random.choice(COSMETIC_BRANDS)
            subcategory = random.choice(info["subcategories"])
            
            # Product name
            name_prefix = random.choice(["Pro", "Ultra", "Perfect", "Luxe", "Essential", "Classic", "Radiant", "Glow", "Matte", "Velvet"])
            name = f"{brand} {name_prefix} {subcategory.title()}"
            
            # Pricing
            base_price = round(random.uniform(15, 65), 2)
            current_price = base_price if random.random() > 0.3 else round(base_price * random.uniform(0.7, 0.95), 2)
            
            # Product record
            product = {
                "product_id": product_id,
                "sku": f"{brand[:3].upper()}-{category[:3].upper()}-{i+1:04d}",
                "name": name,
                "brand": brand,
                "category": category,
                "subcategory": subcategory,
                "description": f"A premium {subcategory} from {brand}. Provides long-lasting, beautiful results.",
                "short_description": f"{brand} {subcategory} - professional quality",
                "base_price": base_price,
                "current_price": current_price,
                "cost": round(base_price * 0.4, 2),
                "color_hex": "",  # Set by variant
                "color_lab": "",
                "color_name": "",
                "finish": random.choice(["matte", "satin", "glossy", "shimmer", "metallic"]),
                "skin_tone_compatibility": json.dumps(random.sample(["fair", "light", "medium", "tan", "deep"], random.randint(3, 5))),
                "undertone_compatibility": json.dumps(random.sample(["warm", "cool", "neutral"], random.randint(1, 3))),
                "monk_scale_min": random.randint(1, 4),
                "monk_scale_max": random.randint(6, 10),
                "size": random.choice(["3g", "5ml", "10ml", "15ml", "30ml", "50ml"]),
                "size_unit": "ml" if "ml" in random.choice(["ml", "g"]) else "g",
                "ingredients": "",  # Populated separately
                "is_vegan": random.random() > 0.7,
                "is_cruelty_free": random.random() > 0.5,
                "spf_value": random.choice([0, 0, 0, 15, 20, 30, 50]) if category in ["face", "skincare"] else 0,
                "is_active": True,
                "is_featured": random.random() > 0.9,
                "launch_date": random_date(730, 30),
                "discontinue_date": "",
                "created_at": random_timestamp(365, 30),
                "updated_at": random_timestamp(30, 0)
            }
            products.append(product)
            
            # Generate variants
            if category == "lips":
                color_palette = LIPSTICK_COLORS
            elif category == "face":
                color_palette = FOUNDATION_COLORS
            elif category == "eyes":
                color_palette = EYESHADOW_COLORS
            elif category == "nails":
                color_palette = NAIL_COLORS
            else:
                color_palette = LIPSTICK_COLORS  # Default
            
            variant_colors = random.sample(color_palette, min(VARIANTS_PER_PRODUCT, len(color_palette)))
            
            for j, (color_hex, color_name) in enumerate(variant_colors):
                variant_id = generate_uuid()
                variant = {
                    "variant_id": variant_id,
                    "product_id": product_id,
                    "sku": f"{product['sku']}-{color_name[:3].upper()}",
                    "shade_name": color_name,
                    "shade_code": f"{j+1:02d}",
                    "color_hex": color_hex,
                    "color_lab": "",  # Can calculate if needed
                    "size": product["size"],
                    "size_unit": product["size_unit"],
                    "price_modifier": 0,
                    "is_available": random.random() > 0.1,
                    "is_default": j == 0,
                    "created_at": product["created_at"],
                    "display_order": j
                }
                variants.append(variant)
                
                # Media for this variant (swatch)
                media.append({
                    "media_id": generate_uuid(),
                    "product_id": product_id,
                    "variant_id": variant_id,
                    "url": f"@PRODUCTS.PRODUCT_MEDIA/swatches/{variant['sku']}.png",
                    "media_type": "image",
                    "media_subtype": "swatch",
                    "alt_text": f"{color_name} swatch",
                    "width": 200,
                    "height": 200,
                    "file_size_bytes": random.randint(5000, 20000),
                    "display_order": 1,
                    "is_primary": False,
                    "is_processed": True,
                    "processed_at": random_timestamp(30, 0),
                    "created_at": product["created_at"]
                })
            
            # Hero image for product
            if hero_images.get(category):
                hero_file = random.choice(hero_images[category])
                media.append({
                    "media_id": generate_uuid(),
                    "product_id": product_id,
                    "variant_id": "",
                    "url": f"@PRODUCTS.PRODUCT_MEDIA/hero/{category}/{hero_file}",
                    "media_type": "image",
                    "media_subtype": "hero",
                    "alt_text": f"{name} product image",
                    "width": 800,
                    "height": 800,
                    "file_size_bytes": random.randint(50000, 200000),
                    "display_order": 0,
                    "is_primary": True,
                    "is_processed": True,
                    "processed_at": random_timestamp(30, 0),
                    "created_at": product["created_at"]
                })
            
            # Label for product
            label_format = random.choice(LABEL_FORMATS)
            labels.append({
                "label_id": generate_uuid(),
                "product_id": product_id,
                "label_type": "ingredients",
                "extracted_text": "",  # Would be populated by AI_EXTRACT
                "structured_data": "",
                "source_image_url": f"@PRODUCTS.PRODUCT_MEDIA/labels/{product['sku']}_{label_format}.png",
                "source_media_id": "",
                "extraction_model": "claude-3-5-sonnet",
                "extraction_confidence": round(random.uniform(0.85, 0.99), 2),
                "extraction_date": random_timestamp(30, 0)
            })
            
            # Ingredients
            category_ingredients = SAMPLE_INGREDIENTS.get(category, SAMPLE_INGREDIENTS["skincare"])
            if category_ingredients:
                selected_ingredients = random.sample(
                    category_ingredients, 
                    min(INGREDIENTS_PER_PRODUCT, len(category_ingredients))
                )
                for pos, ing_name in enumerate(selected_ingredients):
                    ingredients.append({
                        "ingredient_id": generate_uuid(),
                        "product_id": product_id,
                        "label_id": labels[-1]["label_id"],
                        "ingredient_name": ing_name,
                        "ingredient_name_normalized": ing_name.split("(")[0].strip().lower(),
                        "position": pos + 1,
                        "percentage": "",
                        "is_active": pos < 3,
                        "is_allergen": "fragrance" in ing_name.lower() or "parfum" in ing_name.lower(),
                        "allergen_type": "fragrance" if "fragrance" in ing_name.lower() else "",
                        "source_image_url": labels[-1]["source_image_url"],
                        "created_at": product["created_at"]
                    })
            
            # Warnings
            selected_warnings = random.sample(SAMPLE_WARNINGS, min(WARNINGS_PER_PRODUCT, len(SAMPLE_WARNINGS)))
            for warn_type, warn_text, severity in selected_warnings:
                warnings.append({
                    "warning_id": generate_uuid(),
                    "product_id": product_id,
                    "label_id": labels[-1]["label_id"],
                    "warning_type": warn_type,
                    "warning_text": warn_text,
                    "severity": severity,
                    "source_image_url": labels[-1]["source_image_url"],
                    "created_at": product["created_at"]
                })
            
            # Price history
            price = base_price
            for k in range(PRICE_HISTORY_PER_PRODUCT):
                days_ago = 365 - (k * 36)
                if random.random() > 0.7:
                    new_price = round(price * random.uniform(0.85, 1.15), 2)
                else:
                    new_price = price
                
                price_history.append({
                    "history_id": generate_uuid(),
                    "product_id": product_id,
                    "variant_id": "",
                    "price": new_price,
                    "previous_price": price,
                    "effective_date": (datetime.now() - timedelta(days=days_ago)).strftime("%Y-%m-%d"),
                    "end_date": (datetime.now() - timedelta(days=days_ago-35)).strftime("%Y-%m-%d") if k < PRICE_HISTORY_PER_PRODUCT-1 else "",
                    "change_reason": random.choice(["regular", "promotion", "seasonal", "cost_adjustment"]),
                    "created_at": random_timestamp(days_ago, days_ago)
                })
                price = new_price
    
    # Generate promotions
    print(f"\n  Generating {500} promotions...")
    promo_names = ["Summer Sale", "Holiday Special", "Flash Sale", "VIP Exclusive", "New Customer", "Birthday Treat", "Buy More Save More"]
    for i in range(500):
        start_date = datetime.now() - timedelta(days=random.randint(0, 60))
        end_date = start_date + timedelta(days=random.randint(3, 30))
        
        promotions.append({
            "promotion_id": generate_uuid(),
            "name": f"{random.choice(promo_names)} {i+1}",
            "description": "Limited time offer - save on your favorite products!",
            "promo_code": f"SAVE{random.randint(10,50)}" if random.random() > 0.5 else "",
            "discount_type": random.choice(["percentage", "fixed", "bogo"]),
            "discount_value": random.choice([10, 15, 20, 25, 30, 5, 10]),
            "applies_to": random.choice(["all", "category", "brand"]),
            "product_ids": "",
            "category_ids": "",
            "brand_names": random.choice(COSMETIC_BRANDS) if random.random() > 0.7 else "",
            "min_purchase_amount": random.choice([0, 25, 50, 75, 100]),
            "max_uses": random.choice([100, 500, 1000, 0]),
            "max_uses_per_customer": random.choice([1, 2, 5]),
            "current_uses": random.randint(0, 50),
            "start_date": start_date.strftime("%Y-%m-%d %H:%M:%S"),
            "end_date": end_date.strftime("%Y-%m-%d %H:%M:%S"),
            "is_active": end_date > datetime.now(),
            "created_at": start_date.strftime("%Y-%m-%d %H:%M:%S")
        })
    
    # Write CSVs
    print("\n  Writing CSV files...")
    write_csv(CSV_OUTPUT_DIR / "products.csv", products, products[0].keys())
    write_csv(CSV_OUTPUT_DIR / "product_variants.csv", variants, variants[0].keys())
    write_csv(CSV_OUTPUT_DIR / "product_media.csv", media, media[0].keys())
    write_csv(CSV_OUTPUT_DIR / "product_labels.csv", labels, labels[0].keys())
    write_csv(CSV_OUTPUT_DIR / "product_ingredients.csv", ingredients, ingredients[0].keys())
    write_csv(CSV_OUTPUT_DIR / "product_warnings.csv", warnings, warnings[0].keys())
    write_csv(CSV_OUTPUT_DIR / "price_history.csv", price_history, price_history[0].keys())
    write_csv(CSV_OUTPUT_DIR / "promotions.csv", promotions, promotions[0].keys())
    
    return products, variants

# ============================================================================
# PHASE 2: CUSTOMERS
# ============================================================================

def generate_customers():
    """Generate customer profiles and face embeddings."""
    print("\n" + "="*60)
    print("PHASE 2: GENERATING CUSTOMERS DATA")
    print("="*60)
    
    customers = []
    embeddings = []
    analysis_history = []
    
    # Load FairFace labels
    if not FAIRFACE_LABELS.exists():
        print(f"  ⚠️  FairFace labels not found at {FAIRFACE_LABELS}")
        print("     Generating synthetic customer data without face images...")
        use_fairface = False
    else:
        use_fairface = True
        if HAS_PANDAS:
            ff_df = pd.read_csv(FAIRFACE_LABELS)
        else:
            with open(FAIRFACE_LABELS, 'r') as f:
                reader = csv.DictReader(f)
                ff_data = list(reader)
            ff_df = None
    
    # Select faces by gender
    if use_fairface and HAS_PANDAS:
        female_count = int(CUSTOMER_COUNT * CUSTOMER_GENDER_SPLIT["Female"])
        male_count = CUSTOMER_COUNT - female_count
        
        # Filter by gender and age (exclude children)
        ff_df_adults = ff_df[~ff_df['age'].isin(['0-2', '3-9', '10-19'])]
        
        females = ff_df_adults[ff_df_adults['gender'] == 'Female'].sample(n=min(female_count, len(ff_df_adults[ff_df_adults['gender'] == 'Female'])))
        males = ff_df_adults[ff_df_adults['gender'] == 'Male'].sample(n=min(male_count, len(ff_df_adults[ff_df_adults['gender'] == 'Male'])))
        
        selected_faces = pd.concat([females, males]).reset_index(drop=True)
        print(f"  Selected {len(selected_faces)} faces from FairFace ({len(females)} F, {len(males)} M)")
    else:
        selected_faces = None
    
    # First names by gender
    female_names = ["Emma", "Olivia", "Ava", "Isabella", "Sophia", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn",
                    "Abigail", "Emily", "Elizabeth", "Sofia", "Avery", "Ella", "Scarlett", "Grace", "Chloe", "Victoria",
                    "Riley", "Aria", "Lily", "Aubrey", "Zoey", "Penelope", "Layla", "Nora", "Camila", "Hannah"]
    male_names = ["Liam", "Noah", "Oliver", "Elijah", "William", "James", "Benjamin", "Lucas", "Henry", "Alexander",
                  "Mason", "Michael", "Ethan", "Daniel", "Jacob", "Logan", "Jackson", "Sebastian", "Jack", "Aiden",
                  "Owen", "Samuel", "Ryan", "Nathan", "Carter", "Dylan", "Luke", "Gabriel", "Anthony", "Isaac"]
    last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
                  "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
                  "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson"]
    
    skin_types = ["Oily", "Dry", "Combination", "Normal", "Sensitive"]
    undertones = ["Warm", "Cool", "Neutral"]
    
    print(f"\n  Generating {CUSTOMER_COUNT} customer profiles...")
    
    for i in range(CUSTOMER_COUNT):
        customer_id = generate_uuid()
        
        # Determine gender
        if selected_faces is not None and i < len(selected_faces):
            gender = selected_faces.iloc[i]['gender']
            age_range = selected_faces.iloc[i]['age']
            race = selected_faces.iloc[i]['race']
            face_file = selected_faces.iloc[i]['file']
        else:
            gender = "Female" if random.random() < 0.8 else "Male"
            age_range = weighted_choice(CUSTOMER_AGE_DISTRIBUTION)
            race = random.choice(["White", "Black", "East Asian", "Southeast Asian", "Indian", "Middle Eastern", "Latino_Hispanic"])
            face_file = None
        
        first_name = random.choice(female_names if gender == "Female" else male_names)
        last_name = random.choice(last_names)
        
        # Skin profile based on race (simplified mapping)
        if race in ["White"]:
            fitzpatrick = random.randint(1, 3)
            monk_shade = random.randint(1, 4)
        elif race in ["East Asian", "Southeast Asian", "Latino_Hispanic"]:
            fitzpatrick = random.randint(2, 4)
            monk_shade = random.randint(3, 6)
        elif race in ["Indian", "Middle Eastern"]:
            fitzpatrick = random.randint(3, 5)
            monk_shade = random.randint(4, 7)
        else:  # Black
            fitzpatrick = random.randint(4, 6)
            monk_shade = random.randint(6, 10)
        
        skin_profile = {
            "fitzpatrick": fitzpatrick,
            "monk_shade": monk_shade,
            "undertone": random.choice(undertones),
            "skin_type": random.choice(skin_types)
        }
        
        customer = {
            "customer_id": customer_id,
            "email": f"{first_name.lower()}.{last_name.lower()}{random.randint(1,999)}@email.com",
            "first_name": first_name,
            "last_name": last_name,
            "phone": f"+1{random.randint(200,999)}{random.randint(100,999)}{random.randint(1000,9999)}",
            "loyalty_tier": weighted_choice(LOYALTY_TIERS),
            "points_balance": random.randint(0, 5000),
            "lifetime_points": random.randint(1000, 50000),
            "skin_profile": json.dumps(skin_profile),
            "preferences": json.dumps({"notifications": True, "favorite_brands": random.sample(COSMETIC_BRANDS, 3)}),
            "created_at": random_timestamp(730, 30),
            "updated_at": random_timestamp(30, 0),
            "last_login_at": random_timestamp(7, 0),
            "is_active": random.random() > 0.05
        }
        customers.append(customer)
        
        # Face embedding (placeholder - actual embeddings require dlib)
        if face_file:
            embedding = {
                "embedding_id": generate_uuid(),
                "customer_id": customer_id,
                "embedding": json.dumps([random.uniform(-0.5, 0.5) for _ in range(128)]),  # Placeholder
                "quality_score": round(random.uniform(0.7, 0.99), 2),
                "lighting_condition": random.choice(["good", "low", "bright"]),
                "face_angle": random.choice(["frontal", "slight_left", "slight_right"]),
                "is_active": True,
                "is_primary": True,
                "created_at": customer["created_at"],
                "source": "profile_upload"
            }
            embeddings.append(embedding)
        
        # Skin analysis history
        num_analyses = random.randint(1, 5)
        for j in range(num_analyses):
            analysis_history.append({
                "analysis_id": generate_uuid(),
                "customer_id": customer_id,
                "image_stage_path": f"@CUSTOMERS.FACE_IMAGES/{customer_id}/analysis_{j+1}.jpg",
                "skin_hex": f"#{random.randint(0, 255):02x}{random.randint(150, 220):02x}{random.randint(100, 180):02x}",
                "skin_lab": json.dumps([random.uniform(50, 80), random.uniform(-5, 15), random.uniform(10, 30)]),
                "skin_rgb": json.dumps([random.randint(180, 255), random.randint(140, 220), random.randint(100, 180)]),
                "lip_hex": f"#{random.randint(150, 220):02x}{random.randint(50, 120):02x}{random.randint(80, 140):02x}",
                "lip_lab": "",
                "lip_rgb": "",
                "lip_is_natural": random.random() > 0.3,
                "estimated_natural_lip_hex": "",
                "fitzpatrick_type": skin_profile["fitzpatrick"],
                "monk_shade": skin_profile["monk_shade"],
                "undertone": skin_profile["undertone"],
                "ita_angle": round(random.uniform(10, 55), 1),
                "makeup_detected": random.random() > 0.5,
                "detected_makeup_types": json.dumps(random.sample(["lipstick", "foundation", "mascara", "eyeshadow"], random.randint(0, 3))),
                "confidence_score": round(random.uniform(0.8, 0.99), 2),
                "face_quality_score": round(random.uniform(0.7, 0.95), 2),
                "lighting_quality": random.choice(["good", "acceptable", "poor"]),
                "analyzed_at": random_timestamp(180, 0),
                "analysis_duration_ms": random.randint(500, 2000),
                "model_version": "1.0.0"
            })
    
    # Write CSVs
    print("\n  Writing CSV files...")
    write_csv(CSV_OUTPUT_DIR / "customers.csv", customers, customers[0].keys())
    if embeddings:
        write_csv(CSV_OUTPUT_DIR / "customer_face_embeddings.csv", embeddings, embeddings[0].keys())
    write_csv(CSV_OUTPUT_DIR / "skin_analysis_history.csv", analysis_history, analysis_history[0].keys())
    
    return customers

# ============================================================================
# PHASE 3: INVENTORY
# ============================================================================

def generate_inventory(products, variants):
    """Generate inventory data."""
    print("\n" + "="*60)
    print("PHASE 3: GENERATING INVENTORY DATA")
    print("="*60)
    
    locations = []
    stock_levels = []
    transactions = []
    
    # Generate locations
    print(f"\n  Generating {LOCATION_COUNT} locations...")
    cities = [
        ("New York", "NY", 40.7128, -74.0060),
        ("Los Angeles", "CA", 34.0522, -118.2437),
        ("Chicago", "IL", 41.8781, -87.6298),
        ("Houston", "TX", 29.7604, -95.3698),
        ("Phoenix", "AZ", 33.4484, -112.0740),
        ("Philadelphia", "PA", 39.9526, -75.1652),
        ("San Antonio", "TX", 29.4241, -98.4936),
        ("San Diego", "CA", 32.7157, -117.1611),
        ("Dallas", "TX", 32.7767, -96.7970),
        ("San Jose", "CA", 37.3382, -121.8863),
        ("Austin", "TX", 30.2672, -97.7431),
        ("Jacksonville", "FL", 30.3322, -81.6557),
        ("Fort Worth", "TX", 32.7555, -97.3308),
        ("Columbus", "OH", 39.9612, -82.9988),
        ("Indianapolis", "IN", 39.7684, -86.1581),
        ("Charlotte", "NC", 35.2271, -80.8431),
        ("Seattle", "WA", 47.6062, -122.3321),
        ("Denver", "CO", 39.7392, -104.9903),
        ("Boston", "MA", 42.3601, -71.0589),
        ("Miami", "FL", 25.7617, -80.1918),
    ]
    
    location_idx = 0
    for loc_type, count in LOCATIONS_BREAKDOWN.items():
        for i in range(count):
            city_data = cities[location_idx % len(cities)]
            location_id = generate_uuid()
            
            locations.append({
                "location_id": location_id,
                "name": f"{city_data[0]} {loc_type.title()} {i+1}",
                "location_type": loc_type,
                "location_code": f"{loc_type[:2].upper()}{city_data[1]}{i+1:02d}",
                "address_line1": f"{random.randint(100, 9999)} Main Street",
                "address_line2": f"Suite {random.randint(100, 999)}" if random.random() > 0.7 else "",
                "city": city_data[0],
                "state": city_data[1],
                "postal_code": f"{random.randint(10000, 99999)}",
                "country": "US",
                "latitude": city_data[2] + random.uniform(-0.1, 0.1),
                "longitude": city_data[3] + random.uniform(-0.1, 0.1),
                "phone": f"+1{random.randint(200,999)}{random.randint(100,999)}{random.randint(1000,9999)}",
                "email": f"{loc_type}.{city_data[1].lower()}{i+1}@agentcommerce.com",
                "operating_hours": json.dumps({"mon-fri": "9:00-21:00", "sat": "10:00-20:00", "sun": "11:00-18:00"}),
                "is_active": True,
                "is_pickup_enabled": loc_type == "store",
                "created_at": random_timestamp(365, 180)
            })
            location_idx += 1
    
    # Generate stock levels
    print(f"\n  Generating stock levels for {len(products)} products x {len(locations)} locations...")
    
    for product in products[:500]:  # Limit for demo
        for location in locations:
            stock_id = generate_uuid()
            qty_on_hand = random.randint(0, 100)
            qty_reserved = random.randint(0, min(10, qty_on_hand))
            
            stock_levels.append({
                "stock_id": stock_id,
                "product_id": product["product_id"],
                "variant_id": "",  # Product level
                "location_id": location["location_id"],
                "quantity_on_hand": qty_on_hand,
                "quantity_reserved": qty_reserved,
                "reorder_point": 10,
                "reorder_quantity": 50,
                "last_restock_date": random_date(60, 0),
                "last_updated": random_timestamp(7, 0)
            })
            
            # Generate some transactions
            num_txns = random.randint(1, 5)
            for t in range(num_txns):
                txn_type = random.choice(["received", "sold", "reserved", "adjusted"])
                qty = random.randint(1, 20) * (1 if txn_type in ["received", "adjusted"] else -1)
                
                transactions.append({
                    "transaction_id": generate_uuid(),
                    "stock_id": stock_id,
                    "transaction_type": txn_type,
                    "quantity": abs(qty),
                    "quantity_before": qty_on_hand,
                    "quantity_after": qty_on_hand + qty,
                    "reference_type": random.choice(["order", "purchase_order", "adjustment"]),
                    "reference_id": generate_uuid(),
                    "notes": "",
                    "created_at": random_timestamp(30, 0),
                    "created_by": "system"
                })
    
    # Write CSVs
    print("\n  Writing CSV files...")
    write_csv(CSV_OUTPUT_DIR / "locations.csv", locations, locations[0].keys())
    write_csv(CSV_OUTPUT_DIR / "stock_levels.csv", stock_levels, stock_levels[0].keys())
    write_csv(CSV_OUTPUT_DIR / "inventory_transactions.csv", transactions, transactions[0].keys())
    
    return locations

# ============================================================================
# PHASE 4: SOCIAL
# ============================================================================

def generate_social(products, customers):
    """Generate social proof data."""
    print("\n" + "="*60)
    print("PHASE 4: GENERATING SOCIAL DATA")
    print("="*60)
    
    reviews = []
    social_mentions = []
    influencer_mentions = []
    
    # Review templates
    positive_reviews = [
        "Absolutely love this product! Will definitely repurchase.",
        "Amazing quality for the price. Highly recommend!",
        "This is my new holy grail product. Can't live without it.",
        "Perfect color match for my skin tone. So happy!",
        "Long-lasting and beautiful finish. 5 stars!",
        "Best purchase I've made in a while. Worth every penny.",
        "Finally found a product that works for my skin type!",
        "The texture is incredible. Goes on so smoothly.",
    ]
    neutral_reviews = [
        "Decent product but nothing special.",
        "It's okay, does what it says.",
        "Good quality but a bit pricey.",
        "Nice product but the shade was slightly off.",
    ]
    negative_reviews = [
        "Not what I expected. Returning it.",
        "Didn't work well for my skin type.",
        "The color looked different in person.",
        "Quality could be better for the price.",
    ]
    
    # Generate reviews
    print(f"\n  Generating {REVIEWS_PER_PRODUCT * len(products[:200])} product reviews...")
    
    for product in products[:200]:  # Limit for demo
        num_reviews = REVIEWS_PER_PRODUCT
        for _ in range(num_reviews):
            rating = random.choices([1, 2, 3, 4, 5], weights=[0.02, 0.05, 0.13, 0.30, 0.50])[0]
            
            if rating >= 4:
                review_text = random.choice(positive_reviews)
            elif rating == 3:
                review_text = random.choice(neutral_reviews)
            else:
                review_text = random.choice(negative_reviews)
            
            customer = random.choice(customers) if customers else None
            
            reviews.append({
                "review_id": generate_uuid(),
                "product_id": product["product_id"],
                "customer_id": customer["customer_id"] if customer and random.random() > 0.3 else "",
                "platform": random.choice(["website", "app", "bazaarvoice"]),
                "rating": rating,
                "title": review_text[:50] + "..." if len(review_text) > 50 else review_text,
                "review_text": review_text,
                "review_url": f"https://agentcommerce.com/reviews/{generate_uuid()[:8]}",
                "helpful_votes": random.randint(0, 50),
                "not_helpful_votes": random.randint(0, 10),
                "verified_purchase": random.random() > 0.3,
                "reviewer_skin_tone": random.choice(["Fair", "Light", "Medium", "Tan", "Deep"]),
                "reviewer_skin_type": random.choice(["Oily", "Dry", "Combination", "Normal", "Sensitive"]),
                "reviewer_undertone": random.choice(["Warm", "Cool", "Neutral"]),
                "reviewer_age_range": random.choice(["18-24", "25-34", "35-44", "45-54", "55+"]),
                "is_approved": True,
                "moderation_status": "approved",
                "created_at": random_timestamp(180, 0),
                "updated_at": ""
            })
    
    # Generate social mentions
    print(f"\n  Generating {5000} social mentions...")
    platforms = ["instagram", "tiktok", "twitter", "youtube", "pinterest"]
    
    for _ in range(5000):
        product = random.choice(products[:200])
        platform = random.choice(platforms)
        
        social_mentions.append({
            "mention_id": generate_uuid(),
            "product_id": product["product_id"],
            "platform": platform,
            "post_url": f"https://{platform}.com/post/{generate_uuid()[:12]}",
            "content_text": f"Loving this {product['name']}! 💄✨ #beauty #makeup #{product['brand'].replace(' ', '')}",
            "media_url": f"https://{platform}.com/media/{generate_uuid()[:12]}.jpg",
            "author_handle": f"@beauty_lover_{random.randint(1000, 9999)}",
            "author_name": f"{random.choice(['Beauty', 'Glam', 'Makeup', 'Style'])} {random.choice(['Queen', 'Guru', 'Lover', 'Fan'])}",
            "author_follower_count": random.randint(100, 100000),
            "likes": random.randint(10, 10000),
            "comments": random.randint(0, 500),
            "shares": random.randint(0, 200),
            "views": random.randint(100, 100000) if platform in ["tiktok", "youtube"] else 0,
            "sentiment_score": round(random.uniform(0.3, 1.0), 2),
            "sentiment_label": random.choice(["positive", "positive", "positive", "neutral"]),
            "posted_at": random_timestamp(90, 0),
            "ingested_at": random_timestamp(30, 0)
        })
    
    # Generate influencer mentions
    print(f"\n  Generating {2000} influencer mentions...")
    influencer_handles = [f"@beauty_influencer_{i}" for i in range(100)]
    
    for _ in range(2000):
        product = random.choice(products[:200])
        platform = random.choice(["instagram", "tiktok", "youtube"])
        
        influencer_mentions.append({
            "mention_id": generate_uuid(),
            "product_id": product["product_id"],
            "influencer_id": generate_uuid(),
            "influencer_handle": random.choice(influencer_handles),
            "influencer_name": f"{random.choice(['Sarah', 'Emma', 'Jessica', 'Ashley', 'Michelle'])} {random.choice(['Beauty', 'Glam', 'Makeup'])}",
            "platform": platform,
            "post_url": f"https://{platform}.com/influencer/{generate_uuid()[:12]}",
            "content_text": f"Trying out the new {product['name']} from {product['brand']}! Full review coming soon! 💕",
            "media_url": f"https://{platform}.com/media/{generate_uuid()[:12]}.jpg",
            "content_type": random.choice(["post", "story", "reel", "video", "review"]),
            "likes": random.randint(1000, 500000),
            "comments": random.randint(50, 5000),
            "shares": random.randint(10, 1000),
            "views": random.randint(10000, 1000000),
            "influencer_skin_tone": random.choice(["Fair", "Light", "Medium", "Tan", "Deep"]),
            "influencer_skin_type": random.choice(["Oily", "Dry", "Combination", "Normal"]),
            "influencer_undertone": random.choice(["Warm", "Cool", "Neutral"]),
            "follower_count": random.randint(10000, 5000000),
            "engagement_rate": round(random.uniform(1.0, 10.0), 2),
            "audience_demographics": json.dumps({"age_18_24": 0.35, "age_25_34": 0.40, "female": 0.85}),
            "is_sponsored": random.random() > 0.7,
            "is_affiliate": random.random() > 0.5,
            "posted_at": random_timestamp(60, 0),
            "ingested_at": random_timestamp(30, 0)
        })
    
    # Write CSVs
    print("\n  Writing CSV files...")
    write_csv(CSV_OUTPUT_DIR / "product_reviews.csv", reviews, reviews[0].keys())
    write_csv(CSV_OUTPUT_DIR / "social_mentions.csv", social_mentions, social_mentions[0].keys())
    write_csv(CSV_OUTPUT_DIR / "influencer_mentions.csv", influencer_mentions, influencer_mentions[0].keys())
    
    return reviews

# ============================================================================
# PHASE 5: CART_OLTP
# ============================================================================

def generate_cart_oltp(products, variants, customers, locations):
    """Generate cart and order data."""
    print("\n" + "="*60)
    print("PHASE 5: GENERATING CART_OLTP DATA")
    print("="*60)
    
    cart_sessions = []
    cart_items = []
    fulfillment_options = []
    payment_methods = []
    payment_transactions = []
    orders = []
    order_items = []
    
    # Generate fulfillment options (seed data)
    print("\n  Generating fulfillment options...")
    fulfillment_data = [
        ("Standard Shipping", "shipping", 599, 5, 7, "USPS"),
        ("Express Shipping", "shipping", 999, 2, 3, "UPS"),
        ("Next Day", "shipping", 1499, 1, 1, "FedEx"),
        ("Free Shipping", "shipping", 0, 7, 10, "USPS"),
        ("Store Pickup", "pickup", 0, 0, 1, ""),
    ]
    
    for name, ftype, price, min_days, max_days, carrier in fulfillment_data:
        fulfillment_options.append({
            "option_id": generate_uuid(),
            "name": name,
            "description": f"{name} - {min_days}-{max_days} business days" if ftype == "shipping" else "Pick up at your nearest store",
            "fulfillment_type": ftype,
            "price_cents": price,
            "free_threshold_cents": 5000 if name == "Free Shipping" else 0,
            "estimated_days_min": min_days,
            "estimated_days_max": max_days,
            "carrier": carrier,
            "is_available": True,
            "available_countries": "US,CA",
            "display_order": len(fulfillment_options),
            "created_at": random_timestamp(365, 365)
        })
    
    # Generate payment methods for customers
    print(f"\n  Generating payment methods for {len(customers[:500])} customers...")
    for customer in customers[:500]:
        num_methods = random.randint(1, 3)
        for _ in range(num_methods):
            card_brand = random.choice(["visa", "mastercard", "amex", "discover"])
            last_four = f"{random.randint(1000, 9999)}"
            
            payment_methods.append({
                "payment_method_id": generate_uuid(),
                "customer_id": customer["customer_id"],
                "payment_type": random.choice(["card", "card", "card", "paypal", "apple_pay"]),
                "token": f"tok_{generate_uuid()[:24]}",
                "display_name": f"{card_brand.title()} ****{last_four}",
                "card_brand": card_brand,
                "card_last_four": last_four,
                "expires_month": random.randint(1, 12),
                "expires_year": random.randint(2025, 2030),
                "is_default": _ == 0,
                "is_verified": True,
                "billing_address": json.dumps({"city": "New York", "state": "NY", "zip": "10001"}),
                "created_at": random_timestamp(365, 30),
                "last_used_at": random_timestamp(30, 0)
            })
    
    # Generate cart sessions
    print(f"\n  Generating {CART_SESSIONS_COUNT} cart sessions...")
    
    for i in range(CART_SESSIONS_COUNT):
        session_id = generate_uuid()
        customer = random.choice(customers[:500]) if random.random() > 0.2 else None
        status = random.choices(
            ["active", "completed", "abandoned", "expired"],
            weights=[0.1, 0.5, 0.3, 0.1]
        )[0]
        
        # Select random items
        num_items = random.randint(1, ITEMS_PER_CART)
        selected_variants = random.sample(variants[:1000], min(num_items, len(variants[:1000])))
        
        subtotal = 0
        for variant in selected_variants:
            product = next((p for p in products if p["product_id"] == variant["product_id"]), None)
            if not product:
                continue
            
            qty = random.randint(1, 3)
            unit_price = int(float(product["current_price"]) * 100)
            item_subtotal = unit_price * qty
            subtotal += item_subtotal
            
            cart_items.append({
                "item_id": generate_uuid(),
                "session_id": session_id,
                "product_id": product["product_id"],
                "variant_id": variant["variant_id"],
                "quantity": qty,
                "unit_price_cents": unit_price,
                "subtotal_cents": item_subtotal,
                "product_name": product["name"],
                "variant_name": variant["shade_name"],
                "product_image_url": f"@PRODUCTS.PRODUCT_MEDIA/swatches/{variant['sku']}.png",
                "added_at": random_timestamp(30, 0),
                "updated_at": ""
            })
        
        tax = int(subtotal * 0.08)
        shipping = random.choice([0, 599, 999]) if status == "completed" else 0
        discount = int(subtotal * random.choice([0, 0, 0, 0.1, 0.15, 0.2])) if random.random() > 0.7 else 0
        total = subtotal + tax + shipping - discount
        
        fulfillment = random.choice(fulfillment_options)
        
        cart_sessions.append({
            "session_id": session_id,
            "customer_id": customer["customer_id"] if customer else "",
            "status": status,
            "subtotal_cents": subtotal,
            "tax_cents": tax,
            "shipping_cents": shipping,
            "discount_cents": discount,
            "total_cents": total,
            "currency": "USD",
            "applied_promo_codes": json.dumps(["SAVE10"]) if discount > 0 else "",
            "applied_loyalty_points": 0,
            "fulfillment_type": fulfillment["fulfillment_type"] if status == "completed" else "",
            "shipping_address": json.dumps({"city": "New York", "state": "NY"}) if status == "completed" else "",
            "billing_address": json.dumps({"city": "New York", "state": "NY"}) if status == "completed" else "",
            "shipping_method_id": fulfillment["option_id"] if status == "completed" else "",
            "is_gift": random.random() > 0.95,
            "gift_message": "",
            "gift_recipient_email": "",
            "is_valid": True,
            "validation_message": "",
            "idempotency_key": f"idem_{generate_uuid()[:16]}",
            "created_at": random_timestamp(60, 0),
            "updated_at": random_timestamp(30, 0),
            "expires_at": "",
            "completed_at": random_timestamp(30, 0) if status == "completed" else ""
        })
        
        # Generate order if completed
        if status == "completed" and customer:
            order_id = generate_uuid()
            order_number = f"ORD-{random.randint(100000, 999999)}"
            
            orders.append({
                "order_id": order_id,
                "order_number": order_number,
                "session_id": session_id,
                "customer_id": customer["customer_id"],
                "status": random.choice(["confirmed", "processing", "shipped", "delivered"]),
                "subtotal_cents": subtotal,
                "tax_cents": tax,
                "shipping_cents": shipping,
                "discount_cents": discount,
                "total_cents": total,
                "currency": "USD",
                "shipping_address": json.dumps({"city": "New York", "state": "NY", "zip": "10001"}),
                "shipping_method": fulfillment["name"],
                "tracking_number": f"1Z{random.randint(100000000, 999999999)}" if random.random() > 0.5 else "",
                "tracking_url": "",
                "created_at": cart_sessions[-1]["completed_at"],
                "confirmed_at": cart_sessions[-1]["completed_at"],
                "shipped_at": random_timestamp(20, 0) if random.random() > 0.3 else "",
                "delivered_at": random_timestamp(10, 0) if random.random() > 0.5 else "",
                "cancelled_at": ""
            })
            
            # Copy cart items to order items
            for item in [ci for ci in cart_items if ci["session_id"] == session_id]:
                order_items.append({
                    "order_item_id": generate_uuid(),
                    "order_id": order_id,
                    "product_id": item["product_id"],
                    "variant_id": item["variant_id"],
                    "quantity": item["quantity"],
                    "unit_price_cents": item["unit_price_cents"],
                    "subtotal_cents": item["subtotal_cents"],
                    "product_name": item["product_name"],
                    "variant_name": item["variant_name"],
                    "product_image_url": item["product_image_url"],
                    "created_at": orders[-1]["created_at"]
                })
            
            # Generate payment transaction
            customer_methods = [pm for pm in payment_methods if pm["customer_id"] == customer["customer_id"]]
            if customer_methods:
                payment_transactions.append({
                    "transaction_id": generate_uuid(),
                    "session_id": session_id,
                    "payment_method_id": random.choice(customer_methods)["payment_method_id"],
                    "amount_cents": total,
                    "currency": "USD",
                    "status": "captured",
                    "psp_name": "stripe",
                    "psp_transaction_id": f"pi_{generate_uuid()[:24]}",
                    "psp_response": json.dumps({"status": "succeeded"}),
                    "failure_code": "",
                    "failure_message": "",
                    "created_at": orders[-1]["created_at"],
                    "updated_at": ""
                })
    
    # Write CSVs
    print("\n  Writing CSV files...")
    write_csv(CSV_OUTPUT_DIR / "cart_sessions.csv", cart_sessions, cart_sessions[0].keys())
    write_csv(CSV_OUTPUT_DIR / "cart_items.csv", cart_items, cart_items[0].keys())
    write_csv(CSV_OUTPUT_DIR / "fulfillment_options.csv", fulfillment_options, fulfillment_options[0].keys())
    write_csv(CSV_OUTPUT_DIR / "payment_methods.csv", payment_methods, payment_methods[0].keys())
    if payment_transactions:
        write_csv(CSV_OUTPUT_DIR / "payment_transactions.csv", payment_transactions, payment_transactions[0].keys())
    write_csv(CSV_OUTPUT_DIR / "orders.csv", orders, orders[0].keys())
    write_csv(CSV_OUTPUT_DIR / "order_items.csv", order_items, order_items[0].keys())

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("\n" + "="*70)
    print("  AGENT COMMERCE - DATA GENERATION")
    print("="*70)
    print(f"\nOutput directory: {OUTPUT_DIR}")
    print(f"Generating data for {CUSTOMER_COUNT} customers, {PRODUCT_COUNT} products")
    
    start_time = datetime.now()
    
    # Phase 1: Products
    products, variants = generate_products()
    
    # Phase 2: Customers
    customers = generate_customers()
    
    # Phase 3: Inventory
    locations = generate_inventory(products, variants)
    
    # Phase 4: Social
    generate_social(products, customers)
    
    # Phase 5: Cart/Orders
    generate_cart_oltp(products, variants, customers, locations)
    
    # Summary
    elapsed = datetime.now() - start_time
    print("\n" + "="*70)
    print("  DATA GENERATION COMPLETE")
    print("="*70)
    print(f"\n  ⏱️  Time elapsed: {elapsed}")
    print(f"  📁 Output directory: {CSV_OUTPUT_DIR}")
    print(f"\n  Generated CSV files:")
    
    for f in sorted(CSV_OUTPUT_DIR.glob("*.csv")):
        size_kb = f.stat().st_size / 1024
        with open(f, 'r') as file:
            row_count = sum(1 for _ in file) - 1
        print(f"    - {f.name}: {row_count:,} rows ({size_kb:.1f} KB)")
    
    print("\n  Next steps:")
    print("    1. Run image generation scripts (swatches, labels)")
    print("    2. Upload to Snowflake stages")
    print("    3. Run COPY INTO commands")

if __name__ == "__main__":
    main()

