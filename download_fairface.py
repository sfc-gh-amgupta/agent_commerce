#!/usr/bin/env python3
"""
FairFace Dataset Downloader
Downloads 1000 diverse face images from the FairFace dataset (Creative Commons licensed)
"""

import os
import urllib.request
import zipfile
import pandas as pd
import shutil
from pathlib import Path
from tqdm import tqdm

class DownloadProgressBar(tqdm):
    """Progress bar for downloads"""
    def update_to(self, b=1, bsize=1, tsize=None):
        if tsize is not None:
            self.total = tsize
        self.update(b * bsize - self.n)

def download_url(url, output_path):
    """Download file with progress bar"""
    with DownloadProgressBar(unit='B', unit_scale=True, miniters=1, desc=url.split('/')[-1]) as t:
        urllib.request.urlretrieve(url, filename=output_path, reporthook=t.update_to)

def download_fairface_dataset(base_dir="fairface_data"):
    """Download FairFace dataset files"""
    
    # Create directories
    base_path = Path(base_dir)
    base_path.mkdir(exist_ok=True)
    
    # URLs for FairFace dataset (from official GitHub)
    urls = {
        'train_labels': 'https://github.com/dchen236/FairFace/raw/master/fairface_label_train.csv',
        'val_labels': 'https://github.com/dchen236/FairFace/raw/master/fairface_label_val.csv',
        'images': 'https://drive.google.com/uc?export=download&id=1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86'  # margin 0.25 version (smaller)
    }
    
    print("📥 Downloading FairFace dataset...")
    print("=" * 60)
    
    # Download label files
    train_labels_path = base_path / 'fairface_label_train.csv'
    val_labels_path = base_path / 'fairface_label_val.csv'
    
    if not train_labels_path.exists():
        print("\n📊 Downloading training labels...")
        download_url(urls['train_labels'], str(train_labels_path))
    else:
        print("\n✅ Training labels already downloaded")
    
    if not val_labels_path.exists():
        print("\n📊 Downloading validation labels...")
        download_url(urls['val_labels'], str(val_labels_path))
    else:
        print("\n✅ Validation labels already downloaded")
    
    # Note about images
    print("\n" + "=" * 60)
    print("📌 IMAGE DOWNLOAD INSTRUCTIONS:")
    print("=" * 60)
    print("Due to the large size of FairFace images, please download manually:")
    print("\n1. Visit: https://github.com/dchen236/FairFace")
    print("2. Download one of these image archives:")
    print("   - fairface-img-margin025-trainval.zip (551 MB - RECOMMENDED)")
    print("   - fairface-img-margin125-trainval.zip (2.49 GB)")
    print(f"\n3. Extract the zip file into: {base_path.absolute()}/")
    print("   The extracted folder should be named 'train' or 'val'")
    print("\nAlternatively, images are available at:")
    print("https://drive.google.com/file/d/1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86/")
    print("=" * 60)
    
    return base_path, train_labels_path, val_labels_path

def select_diverse_images(train_labels_path, val_labels_path, num_images=1000):
    """Select diverse images balanced across demographics"""
    
    print("\n🔍 Analyzing dataset for diversity...")
    
    # Load labels
    train_df = pd.read_csv(train_labels_path)
    val_df = pd.read_csv(val_labels_path)
    df = pd.concat([train_df, val_df], ignore_index=True)
    
    print(f"\n📊 Dataset statistics:")
    print(f"   Total images: {len(df)}")
    print(f"\n   Gender distribution:")
    print(df['gender'].value_counts())
    print(f"\n   Race distribution:")
    print(df['race'].value_counts())
    print(f"\n   Age distribution:")
    print(df['age'].value_counts())
    
    # Strategy: Sample proportionally from each race-gender-age combination
    # to ensure maximum diversity
    
    # Calculate samples per group (proportional to group size)
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
            
            # Sample min of requested samples or available images
            n = min(n_samples, len(group_data))
            sampled = group_data.sample(n=n, random_state=42)
            selected_images.append(sampled)
    
    selected_df = pd.concat(selected_images, ignore_index=True)
    
    print(f"\n✅ Selected {len(selected_df)} diverse images:")
    print(f"\n   Gender distribution:")
    print(selected_df['gender'].value_counts())
    print(f"\n   Race distribution:")
    print(selected_df['race'].value_counts())
    print(f"\n   Age distribution:")
    print(selected_df['age'].value_counts())
    
    return selected_df

def copy_selected_images(selected_df, source_base, output_dir="fairface_selected_1000"):
    """Copy selected images to output directory"""
    
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    print(f"\n📁 Copying images to {output_path.absolute()}...")
    
    # Save the metadata
    metadata_path = output_path / 'image_metadata.csv'
    selected_df.to_csv(metadata_path, index=False)
    print(f"✅ Saved metadata to {metadata_path}")
    
    # Copy images
    source_base = Path(source_base)
    copied = 0
    missing = []
    
    for idx, row in tqdm(selected_df.iterrows(), total=len(selected_df), desc="Copying images"):
        file_name = row['file']
        
        # Try different possible locations
        possible_paths = [
            source_base / file_name,
            source_base / 'train' / file_name.split('/')[-1],
            source_base / 'val' / file_name.split('/')[-1],
            source_base / file_name.split('/')[-1],
        ]
        
        source_file = None
        for path in possible_paths:
            if path.exists():
                source_file = path
                break
        
        if source_file and source_file.exists():
            dest_file = output_path / source_file.name
            shutil.copy2(source_file, dest_file)
            copied += 1
        else:
            missing.append(file_name)
    
    print(f"\n✅ Successfully copied {copied} images")
    
    if missing:
        print(f"⚠️  Could not find {len(missing)} images")
        missing_path = output_path / 'missing_images.txt'
        with open(missing_path, 'w') as f:
            f.write('\n'.join(missing))
        print(f"   List saved to {missing_path}")
    
    # Create attribution file
    create_attribution_file(output_path)
    
    return output_path

def create_attribution_file(output_path):
    """Create Creative Commons attribution file"""
    
    attribution = """
FairFace Dataset Attribution
============================

These images are from the FairFace dataset, licensed under:
Creative Commons Attribution 4.0 International License (CC BY 4.0)

Source: https://github.com/dchen236/FairFace

Citation:
Karkkainen, K., & Joo, J. (2021). 
FairFace: Face Attribute Dataset for Balanced Race, Gender, and Age for Bias Measurement and Mitigation. 
In Proceedings of the IEEE/CVF Winter Conference on Applications of Computer Vision (pp. 1548-1558).

License: CC BY 4.0
https://creativecommons.org/licenses/by/4.0/

When using these images, you must:
- Give appropriate credit
- Provide a link to the license
- Indicate if changes were made

For ethical use:
- Respect individual privacy
- Follow ethical guidelines for facial recognition research
- Consider bias implications in your applications
"""
    
    with open(output_path / 'ATTRIBUTION.txt', 'w') as f:
        f.write(attribution)
    
    print(f"\n📄 Created attribution file: {output_path / 'ATTRIBUTION.txt'}")

def main():
    """Main execution function"""
    
    print("=" * 60)
    print("FairFace Dataset Downloader")
    print("Downloading 1000 diverse face images")
    print("License: Creative Commons Attribution 4.0 (CC BY 4.0)")
    print("=" * 60)
    
    # Step 1: Download dataset metadata
    base_dir, train_labels, val_labels = download_fairface_dataset()
    
    # Check if images have been extracted
    image_dirs = list(base_dir.glob('**/train')) + list(base_dir.glob('**/val'))
    
    if not image_dirs:
        print("\n" + "=" * 60)
        print("⚠️  IMAGE FILES NOT FOUND")
        print("=" * 60)
        print("Please download and extract the image files first.")
        print("Run this script again after extracting images.")
        print("=" * 60)
        return
    
    # Step 2: Select diverse images
    selected_df = select_diverse_images(train_labels, val_labels, num_images=1000)
    
    # Step 3: Copy selected images
    output_dir = copy_selected_images(selected_df, base_dir)
    
    print("\n" + "=" * 60)
    print("✅ DOWNLOAD COMPLETE!")
    print("=" * 60)
    print(f"📁 Images saved to: {output_dir.absolute()}")
    print(f"📊 Metadata saved to: {output_dir.absolute() / 'image_metadata.csv'}")
    print(f"📄 Attribution info: {output_dir.absolute() / 'ATTRIBUTION.txt'}")
    print("\n⚖️  Remember: These images are CC BY 4.0 licensed")
    print("   Always provide proper attribution when using them!")
    print("=" * 60)

if __name__ == "__main__":
    main()


