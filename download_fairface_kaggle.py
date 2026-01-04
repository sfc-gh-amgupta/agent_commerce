#!/usr/bin/env python3
"""
FairFace Dataset Downloader - Kaggle Version
Downloads 1000 diverse face images from FairFace dataset via Kaggle
"""

import os
import zipfile
import pandas as pd
import shutil
from pathlib import Path
from tqdm import tqdm
import subprocess
import sys

def setup_kaggle_api():
    """Check and setup Kaggle API"""
    try:
        import kaggle
        print("✅ Kaggle API is installed")
        return True
    except ImportError:
        print("📦 Installing Kaggle API...")
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-q', 'kaggle'])
        import kaggle
        return True

def check_kaggle_credentials():
    """Check if Kaggle credentials are configured"""
    kaggle_json = Path.home() / '.kaggle' / 'kaggle.json'
    
    if not kaggle_json.exists():
        print("\n" + "=" * 60)
        print("⚠️  KAGGLE CREDENTIALS NOT FOUND")
        print("=" * 60)
        print("\nTo use the Kaggle API, you need to:")
        print("\n1. Go to https://www.kaggle.com/")
        print("2. Sign in or create an account (it's free!)")
        print("3. Go to your account settings: https://www.kaggle.com/settings")
        print("4. Scroll to 'API' section and click 'Create New Token'")
        print("5. This downloads 'kaggle.json' file")
        print("6. Move it to: ~/.kaggle/kaggle.json")
        print("\nOr run these commands:")
        print(f"   mkdir -p ~/.kaggle")
        print(f"   mv ~/Downloads/kaggle.json ~/.kaggle/")
        print(f"   chmod 600 ~/.kaggle/kaggle.json")
        print("=" * 60)
        return False
    
    print("✅ Kaggle credentials found")
    return True

def download_fairface_from_kaggle(base_dir="fairface_data"):
    """Download FairFace dataset from Kaggle"""
    
    base_path = Path(base_dir)
    base_path.mkdir(exist_ok=True)
    
    print("\n" + "=" * 60)
    print("📥 Downloading FairFace from Kaggle")
    print("=" * 60)
    
    # Setup Kaggle API
    if not setup_kaggle_api():
        return None, None, None
    
    if not check_kaggle_credentials():
        return None, None, None
    
    from kaggle.api.kaggle_api_extended import KaggleApi
    api = KaggleApi()
    api.authenticate()
    
    print("\n📦 Downloading dataset (this may take several minutes)...")
    print("Dataset: joohoon/fairface-dataset")
    
    try:
        # Download the dataset
        api.dataset_download_files(
            'joohoon/fairface-dataset',
            path=str(base_path),
            unzip=True,
            quiet=False
        )
        print("✅ Download complete!")
        
    except Exception as e:
        print(f"\n❌ Error downloading from Kaggle: {e}")
        print("\nAlternative: Download manually from:")
        print("https://www.kaggle.com/datasets/joohoon/fairface-dataset")
        return None, None, None
    
    # Find the label files
    label_files = list(base_path.rglob('*label*.csv'))
    train_labels = None
    val_labels = None
    
    for file in label_files:
        if 'train' in file.name.lower():
            train_labels = file
        elif 'val' in file.name.lower():
            val_labels = file
    
    if train_labels and val_labels:
        print(f"✅ Found training labels: {train_labels.name}")
        print(f"✅ Found validation labels: {val_labels.name}")
    else:
        print("⚠️  Label files not found in expected location")
        print(f"   Searching in: {base_path}")
        print(f"   Found files: {[f.name for f in base_path.rglob('*.csv')]}")
    
    return base_path, train_labels, val_labels

def select_diverse_images(train_labels_path, val_labels_path, num_images=1000):
    """Select diverse images balanced across demographics"""
    
    print("\n🔍 Analyzing dataset for diversity...")
    
    # Load labels
    train_df = pd.read_csv(train_labels_path)
    val_df = pd.read_csv(val_labels_path)
    df = pd.concat([train_df, val_df], ignore_index=True)
    
    print(f"\n📊 Total images available: {len(df)}")
    
    # Display distribution
    print(f"\n   Gender distribution:")
    for gender, count in df['gender'].value_counts().items():
        print(f"      {gender}: {count}")
    
    print(f"\n   Race distribution:")
    for race, count in df['race'].value_counts().items():
        print(f"      {race}: {count}")
    
    print(f"\n   Age distribution:")
    for age, count in df['age'].value_counts().items():
        print(f"      {age}: {count}")
    
    # Sample proportionally from each demographic group
    grouped = df.groupby(['race', 'gender', 'age'])
    group_sizes = grouped.size()
    
    # Calculate sampling weights (proportional representation)
    total = len(df)
    samples_per_group = (group_sizes / total * num_images).round().astype(int)
    
    # Adjust to exactly num_images
    while samples_per_group.sum() > num_images:
        max_idx = samples_per_group.idxmax()
        samples_per_group[max_idx] -= 1
    
    while samples_per_group.sum() < num_images:
        # Add to groups with positive samples
        positive_groups = samples_per_group[samples_per_group > 0]
        if len(positive_groups) > 0:
            min_idx = positive_groups.idxmin()
            samples_per_group[min_idx] += 1
        else:
            # If all groups have 0, add to largest group
            max_idx = samples_per_group.idxmax()
            samples_per_group[max_idx] += 1
    
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
    
    print(f"\n✅ Selected {len(selected_df)} diverse images")
    print(f"\n📊 Selected distribution:")
    print(f"\n   Gender:")
    for gender, count in selected_df['gender'].value_counts().items():
        print(f"      {gender}: {count}")
    
    print(f"\n   Race:")
    for race, count in selected_df['race'].value_counts().items():
        print(f"      {race}: {count}")
    
    print(f"\n   Age:")
    for age, count in selected_df['age'].value_counts().items():
        print(f"      {age}: {count}")
    
    return selected_df

def copy_selected_images(selected_df, source_base, output_dir="fairface_selected_1000"):
    """Copy selected images to output directory"""
    
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    print(f"\n📁 Copying {len(selected_df)} images to {output_path.name}/")
    
    # Save metadata
    metadata_path = output_path / 'image_metadata.csv'
    selected_df.to_csv(metadata_path, index=False)
    
    # Copy images
    source_base = Path(source_base)
    copied = 0
    missing = []
    
    for idx, row in tqdm(selected_df.iterrows(), total=len(selected_df), desc="Copying"):
        file_name = row['file']
        
        # Try different possible locations
        possible_paths = [
            source_base / file_name,
            source_base / 'train' / file_name.split('/')[-1],
            source_base / 'val' / file_name.split('/')[-1],
            source_base / file_name.split('/')[-1],
            # Look in subdirectories
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
        missing_path = output_path / 'missing_images.txt'
        with open(missing_path, 'w') as f:
            f.write('\n'.join(missing))
        print(f"   List saved to {missing_path.name}")
    
    # Create attribution file
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

When using these images, you MUST:
✓ Give appropriate credit to the FairFace dataset
✓ Provide a link to the CC BY 4.0 license  
✓ Indicate if changes were made

License: https://creativecommons.org/licenses/by/4.0/

Use these images ethically and responsibly!
"""
    
    with open(output_path / 'ATTRIBUTION.txt', 'w') as f:
        f.write(attribution)
    
    print(f"\n📄 Created attribution file: ATTRIBUTION.txt")
    print(f"📊 Created metadata file: {metadata_path.name}")
    
    return output_path, copied

def main():
    """Main execution"""
    
    print("\n" + "=" * 60)
    print("🎭 FairFace Dataset Downloader (Kaggle)")
    print("Downloading 1000 diverse face images")
    print("License: CC BY 4.0")
    print("=" * 60)
    
    try:
        # Download from Kaggle
        base_dir, train_labels, val_labels = download_fairface_from_kaggle()
        
        if not base_dir or not train_labels or not val_labels:
            print("\n" + "=" * 60)
            print("❌ Download failed. Please check the instructions above.")
            print("=" * 60)
            return
        
        # Select diverse images
        selected_df = select_diverse_images(train_labels, val_labels, num_images=1000)
        
        # Copy to output directory
        output_dir, copied = copy_selected_images(selected_df, base_dir)
        
        print("\n" + "=" * 60)
        print("✅ SUCCESS!")
        print("=" * 60)
        print(f"\n📁 {copied} images saved to: {output_dir.absolute()}")
        print(f"📊 Metadata: {output_dir.name}/image_metadata.csv")
        print(f"📄 Attribution: {output_dir.name}/ATTRIBUTION.txt")
        print("\n⚖️  License: CC BY 4.0")
        print("🤝 Remember to provide attribution when using these images!")
        print("=" * 60 + "\n")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        print("\nFor manual download:")
        print("1. Visit: https://www.kaggle.com/datasets/joohoon/fairface-dataset")
        print("2. Download the dataset")
        print("3. Extract to fairface_data/ folder")
        print("4. Run this script again")

if __name__ == "__main__":
    main()


