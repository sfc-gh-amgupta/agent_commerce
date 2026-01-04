# FairFace Dataset Download Guide

This guide will help you download 1000 diverse face images from the FairFace dataset (Creative Commons licensed).

## Quick Start

### Step 1: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 2: Download FairFace Images

The FairFace images need to be downloaded manually due to their size:

1. Visit the official repository: https://github.com/dchen236/FairFace

2. Download the image archive (choose one):
   - **Recommended**: `fairface-img-margin025-trainval.zip` (551 MB)
   - Larger version: `fairface-img-margin125-trainval.zip` (2.49 GB)

3. Download links:
   - Margin 0.25: https://drive.google.com/file/d/1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86/
   - Margin 1.25: https://drive.google.com/file/d/1g7qNOZz9wC7OfOhcPqH1EZ5bk1UFGmlL/

4. Extract the downloaded zip file into `fairface_data/` directory:
   ```bash
   unzip fairface-img-margin025-trainval.zip -d fairface_data/
   ```

### Step 3: Run the Download Script

```bash
python download_fairface.py
```

The script will:
- Download the label files (CSV) automatically
- Analyze the dataset for demographic diversity
- Select 1000 images balanced across race, gender, and age
- Copy the selected images to `fairface_selected_1000/` directory
- Create metadata and attribution files

## Output

After running the script, you'll have:

```
fairface_selected_1000/
├── [1000 image files].jpg
├── image_metadata.csv          # Metadata for each image (race, gender, age)
├── ATTRIBUTION.txt             # License and attribution information
└── missing_images.txt          # List of any images not found (if applicable)
```

## Dataset Information

### FairFace Details
- **Total Images**: 108,501 face images
- **License**: Creative Commons Attribution 4.0 International (CC BY 4.0)
- **Source**: https://github.com/dchen236/FairFace

### Demographics
- **Race categories**: 7 groups (White, Black, Indian, East Asian, Southeast Asian, Middle Eastern, Latino/Hispanic)
- **Gender**: Male, Female
- **Age groups**: 0-2, 3-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70+

### Diversity Selection
The script uses stratified sampling to ensure:
- Balanced representation across all racial groups
- Equal gender representation
- Diverse age distribution
- Proportional sampling based on dataset composition

## License & Attribution

These images are licensed under **CC BY 4.0**. When using them, you must:

✅ Give appropriate credit to the FairFace dataset  
✅ Provide a link to the license  
✅ Indicate if changes were made  

### Citation

```bibtex
@inproceedings{karkkainen2021fairface,
  title={FairFace: Face Attribute Dataset for Balanced Race, Gender, and Age for Bias Measurement and Mitigation},
  author={Karkkainen, Kimmo and Joo, Jungseock},
  booktitle={Proceedings of the IEEE/CVF Winter Conference on Applications of Computer Vision},
  pages={1548--1558},
  year={2021}
}
```

## Ethical Considerations

⚠️ **Important**: When working with facial data:
- Respect individual privacy and consent
- Be aware of potential biases in facial recognition systems
- Follow ethical guidelines for AI/ML research
- Consider the implications of your use case
- Comply with local data protection regulations (GDPR, etc.)

## Troubleshooting

### Images not found after running script
- Make sure you've extracted the zip file into the `fairface_data/` directory
- Check that the extracted folder is named `train` or `val`
- Verify the image files are in `.jpg` format

### Google Drive download issues
- Google Drive may require you to confirm the download for large files
- You may need to use `gdown` for easier downloading:
  ```bash
  pip install gdown
  gdown 1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86
  ```

### Missing images in output
- Check the `missing_images.txt` file for details
- Some images from the CSV may not be in your downloaded archive
- This is normal - the script will copy all available images

## Support

For issues with the dataset itself, visit:
- GitHub: https://github.com/dchen236/FairFace
- Paper: https://arxiv.org/abs/1908.04913

---

**Remember**: Always use facial recognition data responsibly and ethically! 🤝


