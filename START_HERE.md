# 🎭 Download 1000 Diverse Face Images from FairFace

**Dataset**: FairFace (Creative Commons CC BY 4.0 License)  
**Source**: https://www.kaggle.com/datasets/joohoon/fairface-dataset

## ✨ Two Easy Options

---

### Option 1: Manual Download (EASIEST - Recommended!)

**Time: ~10 minutes** | No API setup needed

#### Steps:

1. **Download the dataset**:
   - Go to: https://www.kaggle.com/datasets/joohoon/fairface-dataset
   - Sign in to Kaggle (free account)
   - Click the **"Download"** button
   - Wait for download to complete (~100-500 MB depending on version)

2. **Extract the files**:
   ```bash
   # Create folder
   mkdir fairface_data
   
   # Extract the downloaded zip
   unzip ~/Downloads/fairface-dataset.zip -d fairface_data/
   ```

3. **Run the selection script**:
   ```bash
   python3 download_fairface_manual.py
   ```

**Done!** Your 1000 diverse images will be in `fairface_selected_1000/` folder.

---

### Option 2: Automatic Download via Kaggle API

**Time: ~15 minutes** | Requires one-time API setup

#### Steps:

1. **Set up Kaggle API** (one-time only):
   - Go to https://www.kaggle.com/settings
   - Scroll to "API" section
   - Click "Create New API Token"
   - This downloads `kaggle.json`

2. **Install the token**:
   ```bash
   mkdir -p ~/.kaggle
   mv ~/Downloads/kaggle.json ~/.kaggle/
   chmod 600 ~/.kaggle/kaggle.json
   ```

3. **Run the automatic downloader**:
   ```bash
   python3 download_fairface_kaggle.py
   ```

See `SETUP_KAGGLE.md` for detailed Kaggle API setup instructions.

---

## 📦 What You'll Get

After running either script, you'll have:

```
fairface_selected_1000/
├── [1000 JPG images]          # Diverse face images
├── image_metadata.csv         # Demographics for each image
└── ATTRIBUTION.txt            # License & citation info
```

### Diversity Breakdown:
- **7 racial groups**: White, Black, Indian, East Asian, Southeast Asian, Middle Eastern, Latino/Hispanic
- **2 genders**: Male, Female
- **9 age groups**: 0-2, 3-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70+

Images are selected proportionally to ensure balanced representation!

---

## ⚖️ License: CC BY 4.0

✅ **Free to use** for commercial and non-commercial purposes  
✅ Can modify and distribute  
⚠️ **Must provide attribution**

### Required Attribution:
> "Face images from FairFace dataset (Karkkainen & Joo, 2021), licensed under CC BY 4.0"

---

## 🆘 Troubleshooting

### "Dataset not found"
- Make sure you extracted the zip file to `fairface_data/` folder
- Check that CSV files are present

### "Kaggle credentials not found" (Option 2 only)
- Follow steps in `SETUP_KAGGLE.md`
- Or use Option 1 (manual download) instead

### "Images not found" during copying
- Some images might be in subfolders
- Check the `missing_images.txt` file if created
- Usually 95%+ of images copy successfully

---

## 📚 Files in This Package

- `START_HERE.md` ← You are here!
- `download_fairface_manual.py` - Manual download method (Option 1)
- `download_fairface_kaggle.py` - Automatic with Kaggle API (Option 2)
- `SETUP_KAGGLE.md` - Kaggle API setup guide
- `requirements.txt` - Python dependencies

---

## 🚀 Quick Start (TL;DR)

```bash
# Install dependencies
pip3 install pandas tqdm

# Go to Kaggle and download dataset manually
# Extract to fairface_data/ folder

# Run the script
python3 download_fairface_manual.py
```

**That's it!** 🎉

---

## 🤝 Ethical Use

Please use these images responsibly:
- Respect privacy and consent
- Be aware of bias in facial recognition systems
- Follow ethical AI/ML guidelines
- Comply with data protection laws (GDPR, etc.)

---

**Questions?** Check out:
- FairFace on Kaggle: https://www.kaggle.com/datasets/joohoon/fairface-dataset
- Original GitHub: https://github.com/joojs/fairface
- Research paper: https://arxiv.org/abs/1908.04913

**Happy coding!** 🎭✨


