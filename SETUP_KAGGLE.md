# Kaggle API Setup Guide

To download FairFace dataset from Kaggle automatically, follow these simple steps:

## One-Time Setup (5 minutes)

### Step 1: Get Kaggle API Token

1. Go to **https://www.kaggle.com/** and sign in (or create a free account)
2. Click on your profile picture (top right) → **Settings**
3. Scroll down to the **API** section
4. Click **"Create New API Token"**
5. This downloads a file called `kaggle.json`

### Step 2: Install the API Token

Open Terminal and run these commands:

```bash
# Create .kaggle directory in your home folder
mkdir -p ~/.kaggle

# Move the downloaded kaggle.json file
mv ~/Downloads/kaggle.json ~/.kaggle/

# Set correct permissions (important!)
chmod 600 ~/.kaggle/kaggle.json
```

### Step 3: Run the Download Script

```bash
python3 download_fairface_kaggle.py
```

That's it! The script will:
- ✅ Download FairFace dataset from Kaggle (~100 MB for the version with labels)
- ✅ Select 1000 diverse images
- ✅ Save to `fairface_selected_1000/` folder

## Alternative: Manual Download (No Kaggle API Setup Required)

If you prefer not to set up the Kaggle API:

1. Visit: https://www.kaggle.com/datasets/joohoon/fairface-dataset
2. Click **"Download"** button (you'll need to sign in)
3. Extract the downloaded zip file to `fairface_data/` folder
4. Run: `python3 download_fairface_manual.py`

## Troubleshooting

### "kaggle.json not found"
- Make sure you moved `kaggle.json` to `~/.kaggle/` directory
- Check: `ls -la ~/.kaggle/kaggle.json`

### Permission denied
- Run: `chmod 600 ~/.kaggle/kaggle.json`

### Download too slow
- Kaggle sometimes throttles downloads
- Use the manual download method instead

---

**Need help?** Check out:
- Kaggle API docs: https://github.com/Kaggle/kaggle-api
- FairFace dataset: https://www.kaggle.com/datasets/joohoon/fairface-dataset


