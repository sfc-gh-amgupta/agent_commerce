# Quick Start Guide: Download 1000 Diverse Face Images

Get 1000 diverse, balanced face images from FairFace (Creative Commons licensed) in 3 simple steps!

## 🚀 Fastest Method (Fully Automated)

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run the automatic downloader
python download_fairface_auto.py
```

**That's it!** The script will:
- ✅ Download labels and images automatically (~551 MB)
- ✅ Select 1000 diverse images (balanced across race, gender, age)
- ✅ Save to `fairface_selected_1000/` folder
- ✅ Create metadata and attribution files

**Time**: ~10-20 minutes depending on your internet speed

---

## 📦 Alternative: Manual Download Method

If automatic download doesn't work:

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Manually download images from:
#    https://drive.google.com/file/d/1Z1RqRo0_JiavaZw2yzZG6WETdZQ8qX86/
#    Save to: fairface_data/

# 3. Extract the zip file
unzip fairface-img-margin025-trainval.zip -d fairface_data/

# 4. Run the selection script
python download_fairface.py
```

See `README_FAIRFACE.md` for detailed manual instructions.

---

## 📁 What You'll Get

```
fairface_selected_1000/
├── image_000001.jpg           # 1000 diverse face images
├── image_000002.jpg
├── ...
├── image_metadata.csv         # Metadata: race, gender, age for each image
└── ATTRIBUTION.txt            # License & attribution info
```

## 📊 Image Diversity

The 1000 images are balanced across:
- **7 racial groups**: White, Black, Indian, East Asian, Southeast Asian, Middle Eastern, Latino/Hispanic
- **2 genders**: Male, Female
- **9 age groups**: 0-2, 3-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70+

## ⚖️ License: CC BY 4.0

These images are **free to use** for commercial and non-commercial purposes, you just need to:
- ✅ Give credit to the FairFace dataset
- ✅ Link to the license
- ✅ Note if you modified the images

## 🤝 Ethical Use

Please use responsibly:
- Respect privacy and consent
- Be aware of bias in facial recognition
- Follow ethical AI/ML guidelines
- Comply with data protection laws

---

## 🆘 Troubleshooting

### Google Drive download fails
Try installing a specific version of gdown:
```bash
pip install gdown==4.7.1
```

### Images not found after extraction
Make sure the extracted folder structure looks like:
```
fairface_data/
├── train/
│   ├── image1.jpg
│   └── ...
└── val/
    ├── image2.jpg
    └── ...
```

### Still having issues?
Check the detailed guide in `README_FAIRFACE.md` or visit:
https://github.com/dchen236/FairFace

---

**Ready to start? Run:**
```bash
python download_fairface_auto.py
```

🎉 Happy coding!


