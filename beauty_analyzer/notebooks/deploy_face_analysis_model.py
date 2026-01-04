"""
Face Analysis Model - Model Registry Deployment
================================================

This notebook deploys the Face Analysis Model to Snowflake Model Registry.
Run this in a Snowflake Notebook with ML Runtime.

The model provides:
- 128-dimensional face embedding (for customer identification)
- Skin tone hex color
- Fitzpatrick skin type (1-6)
- Monk skin shade (1-10)
- Undertone (warm/cool/neutral)
- Lip color hex

Prerequisites:
- Snowflake account with Model Registry enabled
- Compute pool: AGENT_COMMERCE_POOL
- Database: AGENT_COMMERCE
- The face_analysis_model.py file in the same repo

After running this notebook:
- Model logged to: AGENT_COMMERCE.MODELS.FACE_ANALYSIS_MODEL
- Service created: AGENT_COMMERCE.UTIL.ML_FACE_ANALYSIS_SERVICE
- Service function: UTIL.ML_FACE_ANALYSIS_SERVICE!PREDICT(image_input)
- Tool function: CUSTOMERS.TOOL_ANALYZE_FACE(image_input)
"""

# ============================================================================
# Cell 1: Setup and Imports
# ============================================================================

from snowflake.snowpark import Session
from snowflake.ml.registry import Registry
import pandas as pd

# Get active session (in Snowflake Notebook)
session = get_active_session()

# Configuration
DATABASE = "AGENT_COMMERCE"
SCHEMA = "MODELS"
MODEL_NAME = "FACE_ANALYSIS_MODEL"
SERVICE_NAME = "ML_FACE_ANALYSIS_SERVICE"
COMPUTE_POOL = "AGENT_COMMERCE_POOL"

print(f"📦 Deploying {MODEL_NAME} to {DATABASE}.{SCHEMA}")
print(f"🖥️  Using compute pool: {COMPUTE_POOL}")

# ============================================================================
# Cell 2: Create Models Schema if not exists
# ============================================================================

session.sql(f"CREATE SCHEMA IF NOT EXISTS {DATABASE}.{SCHEMA}").collect()
session.sql(f"USE SCHEMA {DATABASE}.{SCHEMA}").collect()
print(f"✅ Using schema: {DATABASE}.{SCHEMA}")

# ============================================================================
# Cell 3: Define the Face Analysis Model
# ============================================================================

import json
import numpy as np
from sklearn.base import BaseEstimator


class FaceAnalysisModel(BaseEstimator):
    """
    Face Analysis Model for beauty product recommendations.
    
    Analyzes face images to extract:
    - 128-dimensional face embedding (for customer identification)
    - Skin tone hex color
    - Fitzpatrick skin type (1-6)
    - Monk skin shade (1-10)
    - Undertone (warm/cool/neutral)
    - Lip color hex
    """
    
    def __init__(self):
        pass
    
    def fit(self, X, y=None):
        return self
    
    def predict(self, X):
        """
        Analyze face images.
        
        Args:
            X: DataFrame with 'input_feature_0' column containing:
               - stage path (e.g., "@CUSTOMERS.FACE_UPLOAD_STAGE/img.jpg")
               - OR base64 encoded image string
        
        Returns:
            Array of JSON strings with analysis results
        """
        results = []
        
        for idx in range(len(X)):
            try:
                # Get input value
                if hasattr(X, 'iloc'):
                    row = X.iloc[idx]
                    image_input = row['input_feature_0'] if 'input_feature_0' in row.index else row[0]
                else:
                    image_input = X[idx]
                
                # Get image bytes
                image_bytes = self._get_image_bytes(image_input)
                
                if image_bytes is None:
                    results.append(json.dumps({
                        "success": False,
                        "error": "Could not read image"
                    }))
                    continue
                
                # Decode image
                image = self._decode_image(image_bytes)
                
                if image is None:
                    results.append(json.dumps({
                        "success": False,
                        "error": "Could not decode image"
                    }))
                    continue
                
                # Extract face embedding
                embedding_result = self._extract_embedding(image)
                
                # Analyze skin tone
                skin_result = self._analyze_skin(image)
                
                # Combine results
                result = {
                    "success": True,
                    "face_detected": embedding_result.get("face_detected", False),
                    "embedding": embedding_result.get("embedding", []),
                    "embedding_json": json.dumps(embedding_result.get("embedding", [])),
                    "quality_score": embedding_result.get("quality_score", 0.0),
                    "skin_hex": skin_result.get("skin_hex"),
                    "skin_rgb": skin_result.get("skin_rgb"),
                    "skin_lab": skin_result.get("skin_lab"),
                    "lip_hex": skin_result.get("lip_hex"),
                    "lip_rgb": skin_result.get("lip_rgb"),
                    "fitzpatrick_type": skin_result.get("fitzpatrick_type"),
                    "monk_shade": skin_result.get("monk_shade"),
                    "undertone": skin_result.get("undertone")
                }
                
                results.append(json.dumps(result))
                
            except Exception as e:
                results.append(json.dumps({
                    "success": False,
                    "error": str(e)
                }))
        
        return np.array(results)
    
    def _get_image_bytes(self, image_input):
        """Get image bytes from stage path or base64."""
        try:
            image_input = str(image_input)
            
            # Check for stage path
            if image_input.startswith('@') or '.FACE_UPLOAD_STAGE' in image_input:
                from snowflake.snowpark.files import SnowflakeFile
                with SnowflakeFile.open(image_input, 'rb') as f:
                    return f.read()
            
            # Assume it's base64
            import base64
            # Remove data URL prefix if present
            if ',' in image_input:
                image_input = image_input.split(',')[1]
            return base64.b64decode(image_input)
                
        except Exception as e:
            print(f"Error getting image bytes: {e}")
            return None
    
    def _decode_image(self, image_bytes):
        """Decode image bytes to numpy array."""
        try:
            import cv2
            import numpy as np
            
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is not None:
                # Convert BGR to RGB
                image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            return image
        except Exception as e:
            print(f"Error decoding image: {e}")
            return None
    
    def _extract_embedding(self, image):
        """Extract 128-dim face embedding using face_recognition."""
        try:
            import face_recognition
            
            # Find face locations
            face_locations = face_recognition.face_locations(image)
            
            if not face_locations:
                return {
                    "face_detected": False,
                    "embedding": [],
                    "quality_score": 0.0
                }
            
            # Get face encoding (128-dim embedding)
            face_encodings = face_recognition.face_encodings(image, face_locations)
            
            if not face_encodings:
                return {
                    "face_detected": False,
                    "embedding": [],
                    "quality_score": 0.0
                }
            
            # Use the first (largest) face
            embedding = face_encodings[0].tolist()
            
            # Calculate quality score based on face size
            top, right, bottom, left = face_locations[0]
            face_size = (bottom - top) * (right - left)
            image_size = image.shape[0] * image.shape[1]
            quality_score = min(1.0, face_size / (image_size * 0.1))
            
            return {
                "face_detected": True,
                "embedding": embedding,
                "quality_score": round(quality_score, 3)
            }
            
        except Exception as e:
            print(f"Error extracting embedding: {e}")
            return {
                "face_detected": False,
                "embedding": [],
                "quality_score": 0.0,
                "error": str(e)
            }
    
    def _analyze_skin(self, image):
        """Analyze skin tone from face region."""
        try:
            import cv2
            import face_recognition
            
            # Find face landmarks
            face_landmarks = face_recognition.face_landmarks(image)
            
            if not face_landmarks:
                return self._fallback_skin_analysis(image)
            
            landmarks = face_landmarks[0]
            
            # Extract skin from cheek region
            skin_color = self._extract_skin_color(image, landmarks)
            
            # Extract lip color
            lip_color = self._extract_lip_color(image, landmarks)
            
            # Convert to LAB for classification
            skin_lab = self._rgb_to_lab(skin_color)
            
            # Classify Fitzpatrick type
            fitzpatrick = self._classify_fitzpatrick(skin_lab)
            
            # Classify Monk shade
            monk = self._classify_monk(skin_lab)
            
            # Determine undertone
            undertone = self._determine_undertone(skin_lab)
            
            return {
                "skin_hex": self._rgb_to_hex(skin_color),
                "skin_rgb": list(skin_color),
                "skin_lab": list(skin_lab),
                "lip_hex": self._rgb_to_hex(lip_color) if lip_color else None,
                "lip_rgb": list(lip_color) if lip_color else None,
                "fitzpatrick_type": fitzpatrick,
                "monk_shade": monk,
                "undertone": undertone
            }
            
        except Exception as e:
            print(f"Error analyzing skin: {e}")
            return self._fallback_skin_analysis(image)
    
    def _fallback_skin_analysis(self, image):
        """Fallback skin analysis without face landmarks."""
        try:
            import cv2
            
            # Use center region of image
            h, w = image.shape[:2]
            center_region = image[h//3:2*h//3, w//3:2*w//3]
            
            # Get dominant color
            avg_color = center_region.mean(axis=(0, 1)).astype(int)
            skin_color = tuple(avg_color)
            
            skin_lab = self._rgb_to_lab(skin_color)
            
            return {
                "skin_hex": self._rgb_to_hex(skin_color),
                "skin_rgb": list(skin_color),
                "skin_lab": list(skin_lab),
                "lip_hex": None,
                "lip_rgb": None,
                "fitzpatrick_type": self._classify_fitzpatrick(skin_lab),
                "monk_shade": self._classify_monk(skin_lab),
                "undertone": self._determine_undertone(skin_lab)
            }
        except:
            return {
                "skin_hex": "#C68642",
                "skin_rgb": [198, 134, 66],
                "skin_lab": [60, 20, 40],
                "lip_hex": None,
                "lip_rgb": None,
                "fitzpatrick_type": 4,
                "monk_shade": 5,
                "undertone": "warm"
            }
    
    def _extract_skin_color(self, image, landmarks):
        """Extract skin color from cheek region."""
        import numpy as np
        
        if 'nose_bridge' in landmarks:
            nose_points = landmarks['nose_bridge']
            x = int(np.mean([p[0] for p in nose_points]))
            y = int(np.mean([p[1] for p in nose_points]))
            
            region = image[max(0, y-10):y+10, max(0, x-10):x+10]
            if region.size > 0:
                return tuple(region.mean(axis=(0, 1)).astype(int))
        
        return (198, 134, 66)  # Default
    
    def _extract_lip_color(self, image, landmarks):
        """Extract lip color."""
        import numpy as np
        
        if 'top_lip' in landmarks and 'bottom_lip' in landmarks:
            all_lip_points = landmarks['top_lip'] + landmarks['bottom_lip']
            x_coords = [p[0] for p in all_lip_points]
            y_coords = [p[1] for p in all_lip_points]
            
            x_center = int(np.mean(x_coords))
            y_center = int(np.mean(y_coords))
            
            region = image[max(0, y_center-5):y_center+5, max(0, x_center-5):x_center+5]
            if region.size > 0:
                return tuple(region.mean(axis=(0, 1)).astype(int))
        
        return None
    
    def _rgb_to_hex(self, rgb):
        """Convert RGB tuple to hex string."""
        if rgb is None:
            return None
        return "#{:02x}{:02x}{:02x}".format(int(rgb[0]), int(rgb[1]), int(rgb[2]))
    
    def _rgb_to_lab(self, rgb):
        """Convert RGB to LAB color space."""
        import cv2
        import numpy as np
        
        pixel = np.uint8([[list(rgb)]])
        pixel_bgr = cv2.cvtColor(pixel, cv2.COLOR_RGB2BGR)
        pixel_lab = cv2.cvtColor(pixel_bgr, cv2.COLOR_BGR2LAB)
        
        return tuple(pixel_lab[0][0].tolist())
    
    def _classify_fitzpatrick(self, lab):
        """Classify Fitzpatrick skin type (1-6) based on LAB values."""
        L = lab[0]
        
        if L >= 200:
            return 1
        elif L >= 170:
            return 2
        elif L >= 140:
            return 3
        elif L >= 110:
            return 4
        elif L >= 80:
            return 5
        else:
            return 6
    
    def _classify_monk(self, lab):
        """Classify Monk Skin Tone scale (1-10) based on LAB values."""
        L = lab[0]
        monk = 10 - int((L / 255) * 9)
        return max(1, min(10, monk))
    
    def _determine_undertone(self, lab):
        """Determine skin undertone (warm/cool/neutral)."""
        L, a, b = lab
        
        if b > 140:
            if a > 130:
                return "warm"
            else:
                return "neutral"
        elif b < 120:
            return "cool"
        else:
            if a > 135:
                return "warm"
            elif a < 125:
                return "cool"
            else:
                return "neutral"


print("✅ FaceAnalysisModel class defined")

# ============================================================================
# Cell 4: Log Model to Registry
# ============================================================================

# Create and fit the model
model = FaceAnalysisModel()
model.fit(None)

# Create sample input for schema inference
sample_input = pd.DataFrame({"input_feature_0": ["sample_base64_string"]})

# Get the registry
registry = Registry(session=session, database_name=DATABASE, schema_name=SCHEMA)

# Log the model
model_version = registry.log_model(
    model=model,
    model_name=MODEL_NAME,
    version_name="v1",
    sample_input_data=sample_input,
    conda_dependencies=["opencv", "pillow", "numpy"],
    pip_requirements=["face_recognition", "dlib"],
    comment="Face analysis model for beauty recommendations"
)

print(f"✅ Model logged: {DATABASE}.{SCHEMA}.{MODEL_NAME}")
print(f"   Version: v1")

# ============================================================================
# Cell 5: Deploy Model as Service
# ============================================================================

# Deploy the model as a service
model_version.create_service(
    service_name=SERVICE_NAME,
    service_compute_pool=COMPUTE_POOL,
    image_build_compute_pool=COMPUTE_POOL,
    ingress_enabled=True,
    max_instances=1,
    gpu=False
)

print(f"✅ Service deployment initiated: UTIL.{SERVICE_NAME}")
print("   ⏳ This may take 5-10 minutes...")

# Wait for service to be ready
import time
for i in range(30):
    result = session.sql(f"SHOW SERVICES LIKE '{SERVICE_NAME}' IN SCHEMA UTIL").collect()
    if result and result[0]['status'] == 'RUNNING':
        print(f"✅ Service is RUNNING!")
        break
    print(f"   Waiting... ({i+1}/30)")
    time.sleep(20)

# ============================================================================
# Cell 6: Create TOOL_ANALYZE_FACE Function
# ============================================================================

session.sql(f"""
CREATE OR REPLACE FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(image_input VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT PARSE_JSON(
        UTIL.{SERVICE_NAME}!PREDICT(image_input):"output_feature_0"::VARCHAR
    )
$$
""").collect()

session.sql("""
COMMENT ON FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(VARCHAR) IS 
'Analyze face from image. Input: stage path or base64. Uses ML Model Registry service function.'
""").collect()

print("✅ TOOL_ANALYZE_FACE updated to use Model Registry service function!")

# ============================================================================
# Cell 7: Test the Function
# ============================================================================

# Using a simple 1x1 red pixel test image (base64)
test_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

result = session.sql(f"""
SELECT CUSTOMERS.TOOL_ANALYZE_FACE('{test_base64}') as result
""").collect()

print("Test result:", result[0][0])

# Expected output (for 1x1 pixel - no face detected):
# {
#   "embedding": "[]",
#   "face_detected": false,
#   "fitzpatrick_type": 6,
#   "lip_hex": null,
#   "monk_shade": 10,
#   "quality_score": 0,
#   "skin_hex": "#...",
#   "success": true,
#   "undertone": "neutral"
# }

print("""
============================================================
  DEPLOYMENT COMPLETE!
============================================================

✅ Model: {DATABASE}.{SCHEMA}.{MODEL_NAME}
✅ Service: UTIL.{SERVICE_NAME}
✅ Function: CUSTOMERS.TOOL_ANALYZE_FACE(image_input)

Usage:
  SELECT CUSTOMERS.TOOL_ANALYZE_FACE('@CUSTOMERS.FACE_UPLOAD_STAGE/photo.jpg');
  SELECT CUSTOMERS.TOOL_ANALYZE_FACE('base64_encoded_image_string');

The Cortex Agent can now call AnalyzeFace tool which uses this function.
""")

