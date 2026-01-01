"""
Agent Commerce - SPCS Backend
==============================
FastAPI backend for face recognition, skin analysis, and color matching.
Deployed as Snowpark Container Service.

Endpoints:
    - POST /health - Health check
    - POST /extract-embedding - Extract face embedding from image
    - POST /analyze-skin - Analyze skin tone and type
    - POST /match-products - Find matching products by color
    - POST /batch-extract - Batch process multiple images
"""

import os
import io
import json
import base64
import logging
from typing import List, Optional
from datetime import datetime

import numpy as np
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Agent Commerce Backend",
    description="Face recognition and skin analysis service",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# LAZY LOADING OF ML MODELS
# ============================================================================
# Models are loaded on first use to reduce cold start time

_face_recognition = None
_mediapipe_face_mesh = None

def get_face_recognition():
    """Lazy load face_recognition library."""
    global _face_recognition
    if _face_recognition is None:
        try:
            import face_recognition
            _face_recognition = face_recognition
            logger.info("✅ face_recognition loaded successfully")
        except ImportError as e:
            logger.error(f"❌ Failed to load face_recognition: {e}")
            raise HTTPException(status_code=500, detail="Face recognition not available")
    return _face_recognition

def get_mediapipe():
    """Lazy load MediaPipe."""
    global _mediapipe_face_mesh
    if _mediapipe_face_mesh is None:
        try:
            import mediapipe as mp
            _mediapipe_face_mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                min_detection_confidence=0.5
            )
            logger.info("✅ MediaPipe Face Mesh loaded successfully")
        except ImportError as e:
            logger.error(f"❌ Failed to load MediaPipe: {e}")
            raise HTTPException(status_code=500, detail="MediaPipe not available")
    return _mediapipe_face_mesh

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class HealthResponse(BaseModel):
    status: str
    timestamp: str
    version: str

class EmbeddingRequest(BaseModel):
    image_base64: str
    customer_id: Optional[str] = None

class EmbeddingResponse(BaseModel):
    success: bool
    embedding: Optional[List[float]] = None
    quality_score: Optional[float] = None
    face_detected: bool
    error: Optional[str] = None

class BatchEmbeddingRequest(BaseModel):
    images: List[dict]  # [{"image_path": str, "customer_id": str}, ...]

class BatchEmbeddingResponse(BaseModel):
    success: bool
    results: List[dict]
    processed: int
    failed: int

class SkinAnalysisRequest(BaseModel):
    image_base64: str

class SkinAnalysisResponse(BaseModel):
    success: bool
    skin_hex: Optional[str] = None
    skin_rgb: Optional[List[int]] = None
    skin_lab: Optional[List[float]] = None
    lip_hex: Optional[str] = None
    lip_rgb: Optional[List[int]] = None
    fitzpatrick_type: Optional[int] = None
    monk_shade: Optional[int] = None
    undertone: Optional[str] = None
    ita_angle: Optional[float] = None
    confidence_score: Optional[float] = None
    error: Optional[str] = None

class ColorMatchRequest(BaseModel):
    target_hex: str
    color_type: str  # "lipstick", "foundation", "eyeshadow"
    limit: int = 10

class ColorMatchResponse(BaseModel):
    success: bool
    matches: List[dict]
    error: Optional[str] = None

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def decode_base64_image(base64_str: str) -> np.ndarray:
    """Decode base64 string to numpy array (RGB)."""
    try:
        # Handle data URL format
        if "," in base64_str:
            base64_str = base64_str.split(",")[1]
        
        image_bytes = base64.b64decode(base64_str)
        
        from PIL import Image
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if necessary
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        return np.array(image)
    except Exception as e:
        logger.error(f"Failed to decode image: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid image: {str(e)}")

def rgb_to_hex(rgb: tuple) -> str:
    """Convert RGB tuple to hex string."""
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"

def rgb_to_lab(rgb: tuple) -> List[float]:
    """Convert RGB to CIELAB color space."""
    # Normalize RGB
    r, g, b = [x / 255.0 for x in rgb]
    
    # Convert to XYZ
    def gamma_correct(c):
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    
    r, g, b = gamma_correct(r), gamma_correct(g), gamma_correct(b)
    
    x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
    
    # Reference white (D65)
    x, y, z = x / 0.95047, y / 1.0, z / 1.08883
    
    def f(t):
        return t ** (1/3) if t > 0.008856 else 7.787 * t + 16/116
    
    L = 116 * f(y) - 16
    a = 500 * (f(x) - f(y))
    b_val = 200 * (f(y) - f(z))
    
    return [round(L, 2), round(a, 2), round(b_val, 2)]

def calculate_ita_angle(lab: List[float]) -> float:
    """Calculate Individual Typology Angle (ITA) for skin classification."""
    L, a, b = lab
    import math
    ita = math.atan2(L - 50, b) * 180 / math.pi
    return round(ita, 2)

def ita_to_fitzpatrick(ita: float) -> int:
    """Convert ITA angle to Fitzpatrick skin type."""
    if ita > 55:
        return 1  # Very fair
    elif ita > 41:
        return 2  # Fair
    elif ita > 28:
        return 3  # Medium
    elif ita > 10:
        return 4  # Olive
    elif ita > -30:
        return 5  # Brown
    else:
        return 6  # Dark brown/black

def ita_to_monk_shade(ita: float) -> int:
    """Convert ITA angle to Monk Skin Tone scale (1-10)."""
    if ita > 55:
        return 1
    elif ita > 48:
        return 2
    elif ita > 41:
        return 3
    elif ita > 34:
        return 4
    elif ita > 28:
        return 5
    elif ita > 19:
        return 6
    elif ita > 10:
        return 7
    elif ita > -10:
        return 8
    elif ita > -30:
        return 9
    else:
        return 10

def determine_undertone(lab: List[float]) -> str:
    """Determine skin undertone from LAB values."""
    L, a, b = lab
    
    # a* positive = red/warm, negative = green/cool
    # b* positive = yellow/warm, negative = blue/cool
    
    warm_score = a + b
    
    if warm_score > 15:
        return "warm"
    elif warm_score < 5:
        return "cool"
    else:
        return "neutral"

# ============================================================================
# FACE DETECTION AND EMBEDDING
# ============================================================================

def extract_face_embedding(image: np.ndarray) -> dict:
    """Extract 128-dimensional face embedding using dlib."""
    face_recognition = get_face_recognition()
    
    # Detect face locations
    face_locations = face_recognition.face_locations(image)
    
    if not face_locations:
        return {
            "success": False,
            "face_detected": False,
            "error": "No face detected"
        }
    
    # Get face encoding (128-dim embedding)
    face_encodings = face_recognition.face_encodings(image, face_locations)
    
    if not face_encodings:
        return {
            "success": False,
            "face_detected": True,
            "error": "Could not extract embedding"
        }
    
    embedding = face_encodings[0].tolist()
    
    # Calculate quality score based on face size
    top, right, bottom, left = face_locations[0]
    face_width = right - left
    face_height = bottom - top
    face_area = face_width * face_height
    image_area = image.shape[0] * image.shape[1]
    face_ratio = face_area / image_area
    
    # Quality score: larger face = better quality
    quality_score = min(1.0, face_ratio * 10)
    
    return {
        "success": True,
        "face_detected": True,
        "embedding": embedding,
        "quality_score": round(quality_score, 3),
        "face_location": {
            "top": top,
            "right": right,
            "bottom": bottom,
            "left": left
        }
    }

# ============================================================================
# SKIN ANALYSIS
# ============================================================================

def analyze_skin(image: np.ndarray) -> dict:
    """Analyze skin tone using MediaPipe face mesh."""
    try:
        import cv2
        face_mesh = get_mediapipe()
        
        # Convert to RGB for MediaPipe
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB) if len(image.shape) == 3 else image
        
        # Process image
        results = face_mesh.process(rgb_image)
        
        if not results.multi_face_landmarks:
            return {
                "success": False,
                "error": "No face detected"
            }
        
        landmarks = results.multi_face_landmarks[0]
        h, w = image.shape[:2]
        
        # Cheek landmarks for skin tone (left and right cheeks)
        # MediaPipe landmark indices for cheeks
        cheek_indices = [50, 101, 118, 119, 47, 100]  # Left cheek
        cheek_indices += [280, 330, 347, 348, 277, 329]  # Right cheek
        
        # Lip landmarks
        lip_indices = [13, 14, 78, 308]  # Upper and lower lip center
        
        # Sample skin colors from cheek regions
        skin_colors = []
        for idx in cheek_indices:
            landmark = landmarks.landmark[idx]
            x, y = int(landmark.x * w), int(landmark.y * h)
            if 0 <= x < w and 0 <= y < h:
                color = image[y, x]
                if len(color) == 3:
                    skin_colors.append(color)
        
        if not skin_colors:
            return {
                "success": False,
                "error": "Could not sample skin colors"
            }
        
        # Average skin color
        avg_skin = np.mean(skin_colors, axis=0).astype(int)
        skin_rgb = tuple(avg_skin.tolist())
        skin_hex = rgb_to_hex(skin_rgb)
        skin_lab = rgb_to_lab(skin_rgb)
        
        # Sample lip colors
        lip_colors = []
        for idx in lip_indices:
            landmark = landmarks.landmark[idx]
            x, y = int(landmark.x * w), int(landmark.y * h)
            if 0 <= x < w and 0 <= y < h:
                color = image[y, x]
                if len(color) == 3:
                    lip_colors.append(color)
        
        lip_rgb = None
        lip_hex = None
        if lip_colors:
            avg_lip = np.mean(lip_colors, axis=0).astype(int)
            lip_rgb = tuple(avg_lip.tolist())
            lip_hex = rgb_to_hex(lip_rgb)
        
        # Calculate skin metrics
        ita_angle = calculate_ita_angle(skin_lab)
        fitzpatrick = ita_to_fitzpatrick(ita_angle)
        monk_shade = ita_to_monk_shade(ita_angle)
        undertone = determine_undertone(skin_lab)
        
        return {
            "success": True,
            "skin_hex": skin_hex,
            "skin_rgb": list(skin_rgb),
            "skin_lab": skin_lab,
            "lip_hex": lip_hex,
            "lip_rgb": list(lip_rgb) if lip_rgb else None,
            "fitzpatrick_type": fitzpatrick,
            "monk_shade": monk_shade,
            "undertone": undertone,
            "ita_angle": ita_angle,
            "confidence_score": 0.9
        }
        
    except Exception as e:
        logger.error(f"Skin analysis failed: {e}")
        return {
            "success": False,
            "error": str(e)
        }

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/health", response_model=HealthResponse)
@app.post("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0"
    )

@app.post("/extract-embedding", response_model=EmbeddingResponse)
async def extract_embedding(request: EmbeddingRequest):
    """Extract face embedding from base64 image."""
    try:
        image = decode_base64_image(request.image_base64)
        result = extract_face_embedding(image)
        
        return EmbeddingResponse(
            success=result.get("success", False),
            embedding=result.get("embedding"),
            quality_score=result.get("quality_score"),
            face_detected=result.get("face_detected", False),
            error=result.get("error")
        )
    except Exception as e:
        logger.error(f"Embedding extraction failed: {e}")
        return EmbeddingResponse(
            success=False,
            face_detected=False,
            error=str(e)
        )

@app.post("/extract-embedding-file")
async def extract_embedding_from_file(file: UploadFile = File(...)):
    """Extract face embedding from uploaded file."""
    try:
        contents = await file.read()
        
        from PIL import Image
        image = Image.open(io.BytesIO(contents))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        image_array = np.array(image)
        result = extract_face_embedding(image_array)
        
        return EmbeddingResponse(
            success=result.get("success", False),
            embedding=result.get("embedding"),
            quality_score=result.get("quality_score"),
            face_detected=result.get("face_detected", False),
            error=result.get("error")
        )
    except Exception as e:
        logger.error(f"Embedding extraction failed: {e}")
        return EmbeddingResponse(
            success=False,
            face_detected=False,
            error=str(e)
        )

@app.post("/batch-extract", response_model=BatchEmbeddingResponse)
async def batch_extract_embeddings(request: BatchEmbeddingRequest):
    """Batch process multiple images for embedding extraction."""
    results = []
    processed = 0
    failed = 0
    
    for item in request.images:
        try:
            image_base64 = item.get("image_base64")
            customer_id = item.get("customer_id")
            
            if not image_base64:
                failed += 1
                results.append({
                    "customer_id": customer_id,
                    "success": False,
                    "error": "No image provided"
                })
                continue
            
            image = decode_base64_image(image_base64)
            result = extract_face_embedding(image)
            
            if result.get("success"):
                processed += 1
                results.append({
                    "customer_id": customer_id,
                    "success": True,
                    "embedding": result.get("embedding"),
                    "quality_score": result.get("quality_score")
                })
            else:
                failed += 1
                results.append({
                    "customer_id": customer_id,
                    "success": False,
                    "error": result.get("error")
                })
                
        except Exception as e:
            failed += 1
            results.append({
                "customer_id": item.get("customer_id"),
                "success": False,
                "error": str(e)
            })
    
    return BatchEmbeddingResponse(
        success=failed == 0,
        results=results,
        processed=processed,
        failed=failed
    )

@app.post("/analyze-skin", response_model=SkinAnalysisResponse)
async def analyze_skin_endpoint(request: SkinAnalysisRequest):
    """Analyze skin tone from base64 image."""
    try:
        image = decode_base64_image(request.image_base64)
        result = analyze_skin(image)
        
        return SkinAnalysisResponse(
            success=result.get("success", False),
            skin_hex=result.get("skin_hex"),
            skin_rgb=result.get("skin_rgb"),
            skin_lab=result.get("skin_lab"),
            lip_hex=result.get("lip_hex"),
            lip_rgb=result.get("lip_rgb"),
            fitzpatrick_type=result.get("fitzpatrick_type"),
            monk_shade=result.get("monk_shade"),
            undertone=result.get("undertone"),
            ita_angle=result.get("ita_angle"),
            confidence_score=result.get("confidence_score"),
            error=result.get("error")
        )
    except Exception as e:
        logger.error(f"Skin analysis failed: {e}")
        return SkinAnalysisResponse(
            success=False,
            error=str(e)
        )

@app.post("/analyze-skin-file")
async def analyze_skin_from_file(file: UploadFile = File(...)):
    """Analyze skin tone from uploaded file."""
    try:
        contents = await file.read()
        
        from PIL import Image
        image = Image.open(io.BytesIO(contents))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        image_array = np.array(image)
        result = analyze_skin(image_array)
        
        return SkinAnalysisResponse(
            success=result.get("success", False),
            skin_hex=result.get("skin_hex"),
            skin_rgb=result.get("skin_rgb"),
            skin_lab=result.get("skin_lab"),
            lip_hex=result.get("lip_hex"),
            lip_rgb=result.get("lip_rgb"),
            fitzpatrick_type=result.get("fitzpatrick_type"),
            monk_shade=result.get("monk_shade"),
            undertone=result.get("undertone"),
            ita_angle=result.get("ita_angle"),
            confidence_score=result.get("confidence_score"),
            error=result.get("error")
        )
    except Exception as e:
        logger.error(f"Skin analysis failed: {e}")
        return SkinAnalysisResponse(
            success=False,
            error=str(e)
        )

# ============================================================================
# STARTUP
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize on startup."""
    logger.info("🚀 Agent Commerce Backend starting...")
    logger.info(f"📁 Working directory: {os.getcwd()}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

