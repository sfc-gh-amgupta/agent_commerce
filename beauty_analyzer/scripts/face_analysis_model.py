"""
Face Analysis Model for Snowflake Model Registry
=================================================

This model is registered with Snowflake Model Registry and deployed to SPCS.
It provides face detection, embedding extraction, and skin tone analysis.

Input: image_path (stage path like @CUSTOMERS.FACE_UPLOAD_STAGE/image.jpg)
Output: JSON with embedding, skin_hex, fitzpatrick, monk_shade, undertone

Dependencies (installed via conda/pip):
- dlib (conda-forge)
- opencv (conda-forge)  
- pillow (conda-forge)
- face_recognition (pip)
- numpy (conda-forge)
"""

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
            X: DataFrame with 'image_path' column containing stage paths
               OR 'image_base64' column containing base64 encoded images
        
        Returns:
            Array of JSON strings with analysis results
        """
        results = []
        
        for idx in range(len(X)):
            try:
                row = X.iloc[idx] if hasattr(X, 'iloc') else X[idx]
                
                # Get image bytes
                image_bytes = self._get_image_bytes(row)
                
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
                    "embedding": json.dumps(embedding_result.get("embedding", [])),
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
    
    def _get_image_bytes(self, row):
        """Get image bytes from stage path or base64."""
        try:
            # Check for stage path
            if hasattr(row, 'image_path') or (isinstance(row, dict) and 'image_path' in row):
                image_path = row['image_path'] if isinstance(row, dict) else row.image_path
                if image_path and str(image_path).startswith('@'):
                    from snowflake.snowpark.files import SnowflakeFile
                    with SnowflakeFile.open(image_path, 'rb') as f:
                        return f.read()
            
            # Check for base64
            if hasattr(row, 'image_base64') or (isinstance(row, dict) and 'image_base64' in row):
                image_base64 = row['image_base64'] if isinstance(row, dict) else row.image_base64
                if image_base64:
                    import base64
                    # Remove data URL prefix if present
                    if ',' in str(image_base64):
                        image_base64 = str(image_base64).split(',')[1]
                    return base64.b64decode(image_base64)
            
            # Try treating the row value directly as base64
            if isinstance(row, str):
                import base64
                if ',' in row:
                    row = row.split(',')[1]
                return base64.b64decode(row)
                
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
            
            # Extract skin from cheek region (between eyes and mouth)
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
        
        # Use nose bridge and cheek area
        if 'nose_bridge' in landmarks:
            nose_points = landmarks['nose_bridge']
            # Sample area around nose
            x = int(np.mean([p[0] for p in nose_points]))
            y = int(np.mean([p[1] for p in nose_points]))
            
            # Get region around the point
            region = image[max(0, y-10):y+10, max(0, x-10):x+10]
            if region.size > 0:
                return tuple(region.mean(axis=(0, 1)).astype(int))
        
        # Fallback to center of face
        if 'chin' in landmarks and 'nose_tip' in landmarks:
            chin = landmarks['chin'][8]  # Bottom of chin
            nose = landmarks['nose_tip'][2]  # Tip of nose
            
            x = (chin[0] + nose[0]) // 2
            y = (chin[1] + nose[1]) // 2
            
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
        
        # Create a 1x1 image with the color
        pixel = np.uint8([[list(rgb)]])
        # RGB to BGR for OpenCV
        pixel_bgr = cv2.cvtColor(pixel, cv2.COLOR_RGB2BGR)
        # BGR to LAB
        pixel_lab = cv2.cvtColor(pixel_bgr, cv2.COLOR_BGR2LAB)
        
        return tuple(pixel_lab[0][0].tolist())
    
    def _classify_fitzpatrick(self, lab):
        """Classify Fitzpatrick skin type (1-6) based on LAB values."""
        L = lab[0]  # Lightness
        
        if L >= 200:
            return 1  # Very fair
        elif L >= 170:
            return 2  # Fair
        elif L >= 140:
            return 3  # Medium
        elif L >= 110:
            return 4  # Olive
        elif L >= 80:
            return 5  # Brown
        else:
            return 6  # Dark brown/black
    
    def _classify_monk(self, lab):
        """Classify Monk Skin Tone scale (1-10) based on LAB values."""
        L = lab[0]  # Lightness
        
        # Map L value (0-255) to Monk scale (1-10)
        # L=255 -> Monk 1, L=0 -> Monk 10
        monk = 10 - int((L / 255) * 9)
        return max(1, min(10, monk))
    
    def _determine_undertone(self, lab):
        """Determine skin undertone (warm/cool/neutral)."""
        L, a, b = lab
        
        # 'a' channel: negative = green, positive = red
        # 'b' channel: negative = blue, positive = yellow
        
        if b > 140:  # More yellow
            if a > 130:  # Also reddish
                return "warm"
            else:
                return "neutral"
        elif b < 120:  # More blue
            return "cool"
        else:
            if a > 135:
                return "warm"
            elif a < 125:
                return "cool"
            else:
                return "neutral"


# For testing locally
if __name__ == "__main__":
    import base64
    import sys
    
    model = FaceAnalysisModel()
    model.fit(None)
    
    # Test with a sample base64 (1x1 red pixel)
    test_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
    
    import pandas as pd
    test_df = pd.DataFrame([{"image_base64": test_base64}])
    
    result = model.predict(test_df)
    print("Test result:", result)

