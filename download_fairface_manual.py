#!/usr/bin/env python3
"""
FairFace Manual Selection Script
Use this after manually downloading FairFace from Kaggle
"""

import pandas as pd
import shutil
from pathlib import Path
from tqdm import tqdm

def find_fairface_data():
    """Find FairFace data in common locations"""
    
    possible_dirs = [
        Path('fairface_data'),
        Path('fairface-dataset'),
        Path('fairface'),
        Path('.'),
    ]
    
    for dir_path in possible_dirs:
        if dir_path.exists():
            label_files = list(dir_path.rglob('*label*.csv'))
            if label_files:
                print(f"✅ Found FairFace data in: {dir_path.absolute()}")
                return dir_path
    
    return None

def select_diverse_images(base_dir, num_images=1000):
    """Select diverse images from FairFace dataset"""
    
    base_path = Path(base_dir)
    
    # Find label files
    train_labels = list(base_path.rglob('*train*.csv'))
    val_labels = list(base_path.rglob('*val*.csv'))
    
    if not train_labels or not val_labels:
        print("❌ Could not find label CSV files")
        print(f"   Looking in: {base_path.absolute()}")
        print("   Please ensure the dataset is extracted correctly")
        return None
    
    train_path = train_labels[0]
    val_path = val_labels[0]
    
    print(f"📊 Loading labels from:")
    print(f"   Training: {train_path.name}")
    print(f"   Validation: {val_path.name}")
    
    # Load data
    train_df = pd.read_csv(train_path)
    val_df = pd.read_csv(val_path)
    df = pd.concat([train_df, val_df], ignore_index=True)
    
    print(f"\n📊 Dataset Statistics:")
    print(f"   Total images: {len(df)}")
    
    print(f"\n   Gender:")
    for gender, count in df['gender'].value_counts().items():
        print(f"      {gender}: {count:,}")
    
    print(f"\n   Race:")
    for race, count in df['race'].value_counts().items():
        print(f"      {race}: {count:,}")
    
    print(f"\n   Age groups:")
    for age, count in df['age'].value_counts().items():
        print(f"      {age}: {count:,}")
    
    # Sample proportionally
    print(f"\n🎯 Selecting {num_images} diverse images...")
    
    grouped = df.groupby(['race', 'gender', 'age'])
    group_sizes = grouped.size()
    
    # Calculate proportional samples
    total = len(df)
    samples_per_group = (group_sizes / total * num_images).round().astype(int)
    
    # Adjust to exactly num_images
    while samples_per_group.sum() > num_images:
        max_idx = samples_per_group.idxmax()
        samples_per_group[max_idx] -= 1
    
    while samples_per_group.sum() < num_images:
        positive_groups = samples_per_group[samples_per_group > 0]
        if len(positive_groups) > 0:
            min_idx = positive_groups.idxmin()
            samples_per_group[min_idx] += 1
        else:
            break
    
    # Sample images
    selected_images = []
    
    for (race, gender, age), n_samples in samples_per_group.items():
        if n_samples > 0:
            group_data = df[(df['race'] == race) & 
                           (df['gender'] == gender) & 
                           (df['age'] == age)]
            
            n = min(n_samples, len(group_data))
            if n > 0:
                sampled = group_data.sample(n=n, random_state=42)
                selected_images.append(sampled)
    
    selected_df = pd.concat(selected_images, ignore_index=True)
    
    print(f"✅ Selected {len(selected_df)} images")
    print(f"\n📊 Selected Distribution:")
    
    print(f"\n   Gender:")
    for gender, count in selected_df['gender'].value_counts().items():
        print(f"      {gender}: {count}")
    
    print(f"\n   Race:")
    for race, count in selected_df['race'].value_counts().items():
        print(f"      {race}: {count}")
    
    return selected_df, base_path

def copy_images(selected_df, source_base, output_dir="fairface_selected_1000"):
    """Copy selected images to output directory"""
    
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    print(f"\n📁 Copying images to: {output_path.absolute()}/")
    
    # Save metadata
    metadata_path = output_path / 'image_metadata.csv'
    selected_df.to_csv(metadata_path, index=False)
    print(f"📊 Saved metadata: {metadata_path.name}")
    
    # Copy images
    source_base = Path(source_base)
    copied = 0
    missing = []
    
    print(f"\n⏳ Copying {len(selected_df)} images...")
    
    for idx, row in tqdm(selected_df.iterrows(), total=len(selected_df)):
        file_name = row['file']
        
        # Try multiple possible locations
        possible_paths = [
            source_base / file_name,
            source_base / 'train' / file_name.split('/')[-1],
            source_base / 'val' / file_name.split('/')[-1],
            source_base / file_name.split('/')[-1],
            *list(source_base.rglob(file_name.split('/')[-1]))
        ]
        
        source_file = None
        for path in possible_paths:
            if path.exists() and path.is_file():
                source_file = path
                break
        
        if source_file:
            dest_file = output_path / source_file.name
            shutil.copy2(source_file, dest_file)
            copied += 1
        else:
            missing.append(file_name)
    
    print(f"\n✅ Successfully copied {copied} images!")
    
    if missing:
        print(f"⚠️  Could not find {len(missing)} images")
        if len(missing) < 50:
            print(f"   Missing: {', '.join(missing[:10])}...")
    
    # Create attribution
    attribution = """FairFace Dataset Attribution
============================

License: Creative Commons Attribution 4.0 International (CC BY 4.0)
Source: https://github.com/joojs/fairface
Kaggle: https://www.kaggle.com/datasets/joohoon/fairface-dataset

Citation:
Karkkainen, K., & Joo, J. (2021). FairFace: Face Attribute Dataset for 
Balanced Race, Gender, and Age for Bias Measurement and Mitigation.
In Proceedings of the IEEE/CVF Winter Conference on Applications of 
Computer Vision (pp. 1548-1558).

REQUIRED ATTRIBUTION:
When using these images, you MUST:
✓ Give appropriate credit to the FairFace dataset
✓ Provide a link to https://creativecommons.org/licenses/by/4.0/
✓ Indicate if you modified the images

Example attribution:
"Face images from FairFace dataset (Karkkainen & Joo, 2021), licensed under CC BY 4.0"

Use ethically and responsibly!
"""
    
    with open(output_path / 'ATTRIBUTION.txt', 'w') as f:
        f.write(attribution)
    
    return output_path, copied

def main():
    """Main execution"""
    
    print("\n" + "=" * 60)
    print("🎭 FairFace Image Selector")
    print("Select 1000 diverse images from FairFace dataset")
    print("=" * 60)
    
    # Find FairFace data
    print("\n🔍 Looking for FairFace dataset...")
    base_dir = find_fairface_data()
    
    if not base_dir:
        print("\n" + "=" * 60)
        print("❌ FairFace dataset not found!")
        print("=" * 60)
        print("\nPlease download the FairFace dataset first:")
        print("\n1. Visit: https://www.kaggle.com/datasets/joohoon/fairface-dataset")
        print("2. Click 'Download' (requires free Kaggle account)")
        print("3. Extract the zip file to one of these locations:")
        print("   - fairface_data/")
        print("   - Current directory")
        print("\n4. Then run this script again:")
        print("   python3 download_fairface_manual.py")
        print("=" * 60)
        return
    
    # Select diverse images
    result = select_diverse_images(base_dir, num_images=1000)
    
    if result is None:
        return
    
    selected_df, source_base = result
    
    # Copy images
    output_path, copied = copy_images(selected_df, source_base)
    
    print("\n" + "=" * 60)
    print("✅ SUCCESS!")
    print("=" * 60)
    print(f"\n📁 {copied} images saved to:")
    print(f"   {output_path.absolute()}/")
    print(f"\n📊 Metadata file:")
    print(f"   {output_path.name}/image_metadata.csv")
    print(f"\n📄 Attribution file:")
    print(f"   {output_path.name}/ATTRIBUTION.txt")
    print("\n⚖️  License: Creative Commons CC BY 4.0")
    print("🤝 Remember to provide attribution when using these images!")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    main()


