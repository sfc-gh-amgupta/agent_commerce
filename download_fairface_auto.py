#!/usr/bin/env python3
"""
FairFace Dataset Automatic Downloader
Fully automated download including images using gdown
"""

import os
import zipfile
import pandas as pd
import shutil
from pathlib import Path
from tqdm import tqdm

def download_with_gdown(file_id, output_path):
    """Download from Google Drive using gdown"""
    try:
        import gdown
    except ImportError:
        print("❌ gdown not installed. Installing now...")
        import subprocess
        subprocess.check_call(['pip', 'install', 'gdown'])
        import gdown
    
    url = f'https://drive.google.com/uc?id={file_id}'
    print(f"📥 Downloading from Google Drive...")
    gdown.download(url, output_path, quiet=False)

def download_fairface_full(base_dir="fairface_data"):
    """Download complete FairFace dataset automatically"""
    
    base_path = Path(base_dir)
    base_path.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("FairFace Full Automatic Downloader")
    print("=" * 60)
    
    # Download labels
    import urllib.request
    
    train_labels_path = base_path / 'fairface_label_train.csv'
    val_labels_path = base_path / 'fairface_label_val.csv'
    
    # Try multiple possible URLs for the labels
    label_urls = [
        ('https://raw.githubusercontent.com/joojs/fairface/master/fairface_label_train.csv',
         'https://raw.githubusercontent.com/joojs/fairface/master/fairface_label_val.csv'),
        ('https://raw.githubusercontent.com/dchen236/FairFace/master/fairface_label_train.csv',
         'https://raw.githubusercontent.com/dchen236/FairFace/master/fairface_label_val.csv'),
    ]
    
    if not train_labels_path.exists():
        print("\n📊 Downloading training labels...")
        for train_url, _ in label_urls:
            try:
                urllib.request.urlretrieve(train_url, str(train_labels_path))
                print("✅ Downloaded training labels")
                break
            except Exception as e:
                print(f"   Trying alternative URL...")
                continue
        
        if not train_labels_path.exists():
            raise Exception("Could not download training labels from any source")
    
    if not val_labels_path.exists():
        print("\n📊 Downloading validation labels...")
        for _, val_url in label_urls:
            try:
                urllib.request.urlretrieve(val_url, str(val_labels_path))
                print("✅ Downloaded validation labels")
                break
            except Exception as e:
                print(f"   Trying alternative URL...")
                continue
        
        if not val_labels_path.exists():
            raise Exception("Could not download validation labels from any source")
    
    # Download images (margin 0.25 version - smaller)
    images_zip = base_path / 'fairface-img-margin025-trainval.zip'
    
    if not images_zip.exists():
        print("\n📦 Downloading FairFace images (551 MB)...")
        print("This may take several minutes depending on your connection...")
        file_id = '1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86'
        download_with_gdown(file_id, str(images_zip))
        print("✅ Downloaded images archive")
    else:
        print("\n✅ Images archive already downloaded")
    
    # Extract images
    print("\n📂 Extracting images...")
    with zipfile.ZipFile(images_zip, 'r') as zip_ref:
        zip_ref.extractall(base_path)
    print("✅ Images extracted")
    
    return base_path, train_labels_path, val_labels_path

def select_diverse_images(train_labels_path, val_labels_path, num_images=1000):
    """Select diverse images balanced across demographics"""
    
    print("\n🔍 Analyzing dataset for diversity...")
    
    # Load labels
    train_df = pd.read_csv(train_labels_path)
    val_df = pd.read_csv(val_labels_path)
    df = pd.concat([train_df, val_df], ignore_index=True)
    
    print(f"\n📊 Total images available: {len(df)}")
    
    # Sample proportionally from each demographic group
    grouped = df.groupby(['race', 'gender', 'age'])
    group_sizes = grouped.size()
    
    # Calculate sampling weights
    total = len(df)
    samples_per_group = (group_sizes / total * num_images).round().astype(int)
    
    # Adjust to exactly num_images
    while samples_per_group.sum() > num_images:
        max_idx = samples_per_group.idxmax()
        samples_per_group[max_idx] -= 1
    
    while samples_per_group.sum() < num_images:
        min_idx = samples_per_group[samples_per_group > 0].idxmin()
        samples_per_group[min_idx] += 1
    
    # Sample images
    selected_images = []
    
    for (race, gender, age), n_samples in samples_per_group.items():
        if n_samples > 0:
            group_data = df[(df['race'] == race) & 
                           (df['gender'] == gender) & 
                           (df['age'] == age)]
            
            n = min(n_samples, len(group_data))
            sampled = group_data.sample(n=n, random_state=42)
            selected_images.append(sampled)
    
    selected_df = pd.concat(selected_images, ignore_index=True)
    
    print(f"\n✅ Selected {len(selected_df)} diverse images")
    print(f"\n📊 Distribution:")
    print(f"\n   Gender:")
    for gender, count in selected_df['gender'].value_counts().items():
        print(f"      {gender}: {count}")
    
    print(f"\n   Race:")
    for race, count in selected_df['race'].value_counts().items():
        print(f"      {race}: {count}")
    
    return selected_df

def copy_selected_images(selected_df, source_base, output_dir="fairface_selected_1000"):
    """Copy selected images to output directory"""
    
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    print(f"\n📁 Copying {len(selected_df)} images...")
    
    # Save metadata
    metadata_path = output_path / 'image_metadata.csv'
    selected_df.to_csv(metadata_path, index=False)
    
    # Copy images
    source_base = Path(source_base)
    copied = 0
    
    for idx, row in tqdm(selected_df.iterrows(), total=len(selected_df), desc="Copying"):
        file_name = row['file']
        
        # Find source file
        possible_paths = [
            source_base / file_name,
            source_base / 'train' / file_name.split('/')[-1],
            source_base / 'val' / file_name.split('/')[-1],
        ]
        
        source_file = None
        for path in possible_paths:
            if path.exists():
                source_file = path
                break
        
        if source_file:
            dest_file = output_path / source_file.name
            shutil.copy2(source_file, dest_file)
            copied += 1
    
    # Create attribution
    attribution = """FairFace Dataset Attribution
============================

License: Creative Commons Attribution 4.0 International (CC BY 4.0)
Source: https://github.com/dchen236/FairFace

Citation:
Karkkainen, K., & Joo, J. (2021). FairFace: Face Attribute Dataset for 
Balanced Race, Gender, and Age for Bias Measurement and Mitigation.

When using these images, you must:
✓ Give appropriate credit
✓ Provide a link to the license  
✓ Indicate if changes were made

Use ethically and responsibly!
"""
    
    with open(output_path / 'ATTRIBUTION.txt', 'w') as f:
        f.write(attribution)
    
    print(f"\n✅ Copied {copied} images successfully!")
    print(f"📁 Output directory: {output_path.absolute()}")
    print(f"📊 Metadata: {metadata_path.name}")
    print(f"📄 Attribution: ATTRIBUTION.txt")
    
    return output_path

def main():
    """Main execution"""
    
    print("\n" + "=" * 60)
    print("🎭 FairFace Automatic Downloader")
    print("Downloading 1000 diverse face images")
    print("=" * 60)
    
    try:
        # Download full dataset
        base_dir, train_labels, val_labels = download_fairface_full()
        
        # Select diverse images
        selected_df = select_diverse_images(train_labels, val_labels, num_images=1000)
        
        # Copy to output directory
        output_dir = copy_selected_images(selected_df, base_dir)
        
        print("\n" + "=" * 60)
        print("✅ SUCCESS! Download complete!")
        print("=" * 60)
        print(f"\n📁 Your images are in: {output_dir.absolute()}")
        print("\n⚖️  License: CC BY 4.0 - Remember to provide attribution!")
        print("🤝 Use responsibly and ethically")
        print("=" * 60 + "\n")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nIf you encounter issues with automatic download,")
        print("please use the manual download method in README_FAIRFACE.md")

if __name__ == "__main__":
    main()

