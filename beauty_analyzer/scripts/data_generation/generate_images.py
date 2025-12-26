"""
Agent Commerce - Image Generation
==================================
Generates swatch and label images for products.

Usage:
    python scripts/data_generation/generate_images.py
"""

import csv
import random
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("❌ PIL not installed. Run: pip install Pillow")
    exit(1)

# Import config
import sys
sys.path.insert(0, str(Path(__file__).parent))
from config import *

# ============================================================================
# SWATCH GENERATION
# ============================================================================

def generate_swatch(color_hex, output_path, size=(200, 200)):
    """Generate a product swatch image."""
    # Create image with gradient effect for realism
    img = Image.new('RGB', size, color_hex)
    draw = ImageDraw.Draw(img)
    
    # Add subtle gradient/texture
    for y in range(size[1]):
        for x in range(size[0]):
            # Get base color
            r = int(color_hex[1:3], 16)
            g = int(color_hex[3:5], 16)
            b = int(color_hex[5:7], 16)
            
            # Add slight variation for texture
            variation = random.randint(-10, 10)
            r = max(0, min(255, r + variation))
            g = max(0, min(255, g + variation))
            b = max(0, min(255, b + variation))
            
            # Add subtle gradient from center
            center_x, center_y = size[0] // 2, size[1] // 2
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            max_dist = (center_x ** 2 + center_y ** 2) ** 0.5
            gradient = int((dist / max_dist) * 20)
            
            r = max(0, min(255, r - gradient))
            g = max(0, min(255, g - gradient))
            b = max(0, min(255, b - gradient))
            
            img.putpixel((x, y), (r, g, b))
    
    # Add subtle border
    draw.rectangle([0, 0, size[0]-1, size[1]-1], outline=(200, 200, 200), width=1)
    
    img.save(output_path)
    return output_path

def generate_circular_swatch(color_hex, output_path, size=(200, 200)):
    """Generate a circular swatch (like lipstick bullet)."""
    img = Image.new('RGBA', size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Parse color
    r = int(color_hex[1:3], 16)
    g = int(color_hex[3:5], 16)
    b = int(color_hex[5:7], 16)
    
    # Draw filled circle
    padding = 10
    draw.ellipse(
        [padding, padding, size[0]-padding, size[1]-padding],
        fill=(r, g, b, 255),
        outline=(r-30 if r > 30 else 0, g-30 if g > 30 else 0, b-30 if b > 30 else 0, 255),
        width=2
    )
    
    # Add highlight for 3D effect
    highlight_size = size[0] // 4
    draw.ellipse(
        [padding + 15, padding + 15, padding + 15 + highlight_size, padding + 15 + highlight_size],
        fill=(min(255, r + 50), min(255, g + 50), min(255, b + 50), 100)
    )
    
    img.save(output_path)
    return output_path

# ============================================================================
# LABEL GENERATION
# ============================================================================

def get_font(size=12):
    """Get a font, falling back to default if custom not available."""
    try:
        return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        try:
            return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
        except:
            return ImageFont.load_default()

def generate_vertical_label(product_name, brand, ingredients, output_path):
    """Generate vertical ingredient label (typical bottle back)."""
    width, height = 300, 500
    img = Image.new('RGB', (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Fonts
    title_font = get_font(14)
    header_font = get_font(12)
    text_font = get_font(10)
    
    y_pos = 20
    
    # Brand and product name
    draw.text((width//2, y_pos), brand.upper(), fill=(0, 0, 0), font=header_font, anchor="mm")
    y_pos += 25
    draw.text((width//2, y_pos), product_name, fill=(50, 50, 50), font=text_font, anchor="mm")
    y_pos += 35
    
    # Divider line
    draw.line([(20, y_pos), (width-20, y_pos)], fill=(200, 200, 200), width=1)
    y_pos += 20
    
    # Ingredients header
    draw.text((20, y_pos), "INGREDIENTS:", fill=(0, 0, 0), font=header_font)
    y_pos += 25
    
    # Ingredient list
    text = ", ".join(ingredients)
    words = text.split()
    line = ""
    for word in words:
        test_line = line + word + " "
        if draw.textlength(test_line, font=text_font) < width - 40:
            line = test_line
        else:
            draw.text((20, y_pos), line.strip(), fill=(60, 60, 60), font=text_font)
            y_pos += 15
            line = word + " "
            if y_pos > height - 100:
                break
    if line:
        draw.text((20, y_pos), line.strip(), fill=(60, 60, 60), font=text_font)
    
    # Border
    draw.rectangle([5, 5, width-5, height-5], outline=(180, 180, 180), width=1)
    
    img.save(output_path)
    return output_path

def generate_horizontal_label(product_name, brand, ingredients, output_path):
    """Generate horizontal ingredient label (tube style)."""
    width, height = 500, 200
    img = Image.new('RGB', (width, height), (250, 250, 250))
    draw = ImageDraw.Draw(img)
    
    title_font = get_font(14)
    text_font = get_font(9)
    
    # Left section: Brand
    draw.text((20, 20), brand.upper(), fill=(0, 0, 0), font=title_font)
    draw.text((20, 45), product_name[:30], fill=(80, 80, 80), font=text_font)
    
    # Divider
    draw.line([(150, 15), (150, height-15)], fill=(200, 200, 200), width=1)
    
    # Right section: Ingredients
    draw.text((165, 20), "Ingredients:", fill=(0, 0, 0), font=text_font)
    
    y_pos = 40
    text = ", ".join(ingredients[:10])
    words = text.split()
    line = ""
    for word in words:
        test_line = line + word + " "
        if draw.textlength(test_line, font=text_font) < width - 180:
            line = test_line
        else:
            draw.text((165, y_pos), line.strip(), fill=(60, 60, 60), font=text_font)
            y_pos += 14
            line = word + " "
            if y_pos > height - 30:
                break
    if line:
        draw.text((165, y_pos), line.strip(), fill=(60, 60, 60), font=text_font)
    
    draw.rectangle([2, 2, width-2, height-2], outline=(180, 180, 180), width=1)
    
    img.save(output_path)
    return output_path

def generate_tabular_label(product_name, brand, ingredients, output_path):
    """Generate tabular label with ingredient percentages."""
    width, height = 350, 450
    img = Image.new('RGB', (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    header_font = get_font(12)
    text_font = get_font(10)
    
    y_pos = 20
    
    # Header
    draw.text((width//2, y_pos), f"{brand} - {product_name[:25]}", fill=(0, 0, 0), font=header_font, anchor="mm")
    y_pos += 30
    
    # Table header
    draw.rectangle([15, y_pos, width-15, y_pos+25], fill=(240, 240, 240))
    draw.text((25, y_pos+5), "Ingredient", fill=(0, 0, 0), font=text_font)
    draw.text((width-80, y_pos+5), "Function", fill=(0, 0, 0), font=text_font)
    y_pos += 30
    
    # Table rows
    functions = ["Emollient", "Solvent", "Thickener", "Preservative", "Colorant", "Fragrance", "Antioxidant"]
    for i, ing in enumerate(ingredients[:12]):
        if y_pos > height - 40:
            break
        
        bg_color = (250, 250, 250) if i % 2 == 0 else (255, 255, 255)
        draw.rectangle([15, y_pos, width-15, y_pos+22], fill=bg_color)
        
        # Truncate long names
        display_name = ing[:35] + "..." if len(ing) > 35 else ing
        draw.text((25, y_pos+4), display_name, fill=(60, 60, 60), font=text_font)
        draw.text((width-80, y_pos+4), random.choice(functions), fill=(100, 100, 100), font=text_font)
        y_pos += 22
    
    draw.rectangle([10, 10, width-10, height-10], outline=(200, 200, 200), width=1)
    
    img.save(output_path)
    return output_path

def generate_minimalist_label(product_name, brand, ingredients, output_path):
    """Generate minimalist modern label."""
    width, height = 300, 400
    img = Image.new('RGB', (width, height), (252, 252, 252))
    draw = ImageDraw.Draw(img)
    
    brand_font = get_font(18)
    text_font = get_font(9)
    
    # Centered brand
    draw.text((width//2, 40), brand.upper(), fill=(30, 30, 30), font=brand_font, anchor="mm")
    
    # Thin line
    draw.line([(60, 70), (width-60, 70)], fill=(220, 220, 220), width=1)
    
    # Product name
    draw.text((width//2, 95), product_name[:30], fill=(100, 100, 100), font=text_font, anchor="mm")
    
    # Ingredients as flowing text
    y_pos = 130
    text = " · ".join(ingredients[:8])
    words = text.split()
    line = ""
    for word in words:
        test_line = line + word + " "
        if draw.textlength(test_line, font=text_font) < width - 50:
            line = test_line
        else:
            draw.text((width//2, y_pos), line.strip(), fill=(120, 120, 120), font=text_font, anchor="mm")
            y_pos += 16
            line = word + " "
            if y_pos > height - 50:
                break
    if line:
        draw.text((width//2, y_pos), line.strip(), fill=(120, 120, 120), font=text_font, anchor="mm")
    
    img.save(output_path)
    return output_path

def generate_dense_label(product_name, brand, ingredients, output_path):
    """Generate dense multi-language style label."""
    width, height = 400, 550
    img = Image.new('RGB', (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    header_font = get_font(11)
    text_font = get_font(8)
    
    y_pos = 15
    
    # Multi-language headers
    languages = [
        ("INGREDIENTS:", ingredients),
        ("INGRÉDIENTS:", ingredients),
        ("INHALTSSTOFFE:", ingredients),
    ]
    
    for header, ings in languages:
        draw.text((15, y_pos), header, fill=(0, 0, 0), font=header_font)
        y_pos += 18
        
        text = ", ".join(ings)
        words = text.split()
        line = ""
        for word in words:
            test_line = line + word + " "
            if draw.textlength(test_line, font=text_font) < width - 30:
                line = test_line
            else:
                draw.text((15, y_pos), line.strip(), fill=(70, 70, 70), font=text_font)
                y_pos += 12
                line = word + " "
                if y_pos > height - 60:
                    break
        if line:
            draw.text((15, y_pos), line.strip(), fill=(70, 70, 70), font=text_font)
        y_pos += 25
        
        if y_pos > height - 80:
            break
    
    draw.rectangle([5, 5, width-5, height-5], outline=(200, 200, 200), width=1)
    
    img.save(output_path)
    return output_path

def generate_luxury_label(product_name, brand, ingredients, output_path):
    """Generate luxury/premium style label."""
    width, height = 320, 450
    img = Image.new('RGB', (width, height), (20, 20, 25))  # Dark background
    draw = ImageDraw.Draw(img)
    
    brand_font = get_font(16)
    text_font = get_font(9)
    
    # Gold color
    gold = (212, 175, 55)
    
    # Brand name centered
    draw.text((width//2, 50), brand.upper(), fill=gold, font=brand_font, anchor="mm")
    
    # Decorative lines
    draw.line([(50, 80), (width-50, 80)], fill=gold, width=1)
    draw.line([(50, 84), (width-50, 84)], fill=gold, width=1)
    
    # Product name
    draw.text((width//2, 110), product_name[:28], fill=(200, 200, 200), font=text_font, anchor="mm")
    
    # Ingredients
    y_pos = 150
    draw.text((width//2, y_pos), "— FORMULATION —", fill=gold, font=text_font, anchor="mm")
    y_pos += 30
    
    text = ", ".join(ingredients[:10])
    words = text.split()
    line = ""
    for word in words:
        test_line = line + word + " "
        if draw.textlength(test_line, font=text_font) < width - 60:
            line = test_line
        else:
            draw.text((width//2, y_pos), line.strip(), fill=(180, 180, 180), font=text_font, anchor="mm")
            y_pos += 16
            line = word + " "
            if y_pos > height - 50:
                break
    if line:
        draw.text((width//2, y_pos), line.strip(), fill=(180, 180, 180), font=text_font, anchor="mm")
    
    # Decorative border
    draw.rectangle([10, 10, width-10, height-10], outline=gold, width=2)
    draw.rectangle([15, 15, width-15, height-15], outline=gold, width=1)
    
    img.save(output_path)
    return output_path

# ============================================================================
# MAIN GENERATION
# ============================================================================

def generate_all_swatches():
    """Generate swatch images for all product variants."""
    print("\n" + "="*60)
    print("GENERATING SWATCH IMAGES")
    print("="*60)
    
    # Read product variants
    variants_file = CSV_OUTPUT_DIR / "product_variants.csv"
    if not variants_file.exists():
        print(f"  ❌ Variants file not found: {variants_file}")
        return
    
    with open(variants_file, 'r') as f:
        reader = csv.DictReader(f)
        variants = list(reader)
    
    print(f"  Generating {len(variants)} swatch images...")
    
    generated = 0
    for variant in variants:
        color_hex = variant.get('color_hex', '#FF0000')
        sku = variant.get('sku', f'unknown_{generated}')
        
        if not color_hex or not color_hex.startswith('#'):
            continue
        
        output_path = SWATCHES_OUTPUT_DIR / f"{sku}.png"
        
        # Use circular for lips, square for others
        if 'LIP' in sku.upper():
            generate_circular_swatch(color_hex, output_path)
        else:
            generate_swatch(color_hex, output_path)
        
        generated += 1
        
        if generated % 500 == 0:
            print(f"    Generated {generated} swatches...")
    
    print(f"  ✅ Generated {generated} swatch images")

def generate_all_labels():
    """Generate label images for all products."""
    print("\n" + "="*60)
    print("GENERATING LABEL IMAGES")
    print("="*60)
    
    # Read products and ingredients
    products_file = CSV_OUTPUT_DIR / "products.csv"
    ingredients_file = CSV_OUTPUT_DIR / "product_ingredients.csv"
    
    if not products_file.exists():
        print(f"  ❌ Products file not found: {products_file}")
        return
    
    with open(products_file, 'r') as f:
        reader = csv.DictReader(f)
        products = list(reader)
    
    # Build ingredients lookup
    ingredients_by_product = {}
    if ingredients_file.exists():
        with open(ingredients_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                pid = row.get('product_id')
                if pid not in ingredients_by_product:
                    ingredients_by_product[pid] = []
                ingredients_by_product[pid].append(row.get('ingredient_name', ''))
    
    # Label generators
    generators = {
        'vertical': generate_vertical_label,
        'horizontal': generate_horizontal_label,
        'tabular': generate_tabular_label,
        'minimalist': generate_minimalist_label,
        'dense': generate_dense_label,
        'luxury': generate_luxury_label,
    }
    
    print(f"  Generating labels for {len(products)} products...")
    
    generated = 0
    for product in products:
        product_id = product.get('product_id')
        sku = product.get('sku', f'unknown_{generated}')
        name = product.get('name', 'Product')
        brand = product.get('brand', 'Brand')
        
        # Get ingredients for this product
        ings = ingredients_by_product.get(product_id, [
            "Water", "Glycerin", "Dimethicone", "Phenoxyethanol"
        ])
        
        # Generate with random format
        format_name = random.choice(list(generators.keys()))
        generator = generators[format_name]
        
        output_path = LABELS_OUTPUT_DIR / f"{sku}_{format_name}.png"
        generator(name, brand, ings, output_path)
        
        generated += 1
        
        if generated % 200 == 0:
            print(f"    Generated {generated} labels...")
    
    print(f"  ✅ Generated {generated} label images")

def main():
    print("\n" + "="*70)
    print("  AGENT COMMERCE - IMAGE GENERATION")
    print("="*70)
    
    if not HAS_PIL:
        print("❌ Cannot generate images without PIL. Install with: pip install Pillow")
        return
    
    # Generate swatches
    generate_all_swatches()
    
    # Generate labels
    generate_all_labels()
    
    # Summary
    print("\n" + "="*70)
    print("  IMAGE GENERATION COMPLETE")
    print("="*70)
    
    swatch_count = len(list(SWATCHES_OUTPUT_DIR.glob("*.png")))
    label_count = len(list(LABELS_OUTPUT_DIR.glob("*.png")))
    
    print(f"\n  📁 Output directories:")
    print(f"     Swatches: {SWATCHES_OUTPUT_DIR} ({swatch_count} images)")
    print(f"     Labels: {LABELS_OUTPUT_DIR} ({label_count} images)")

if __name__ == "__main__":
    main()

