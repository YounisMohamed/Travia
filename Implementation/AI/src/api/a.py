from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl
import torch
from transformers import pipeline, BlipProcessor, BlipForConditionalGeneration
from PIL import Image
from ultralytics import YOLO
import requests
import tempfile
import os
from typing import Dict, Any
import uvicorn

app = FastAPI(title="Image Classification API", version="1.0.0")

# Global models - loaded once at startup
vision_processor = None
vision_model = None
classifier = None
yolo_describer = None

class ImageRequest(BaseModel):
    image_url: HttpUrl
    caption: str

class ImageResponse(BaseModel):
    attributes: Dict[str, bool]
    confidence_scores: Dict[str, float]
    blip_description: str
    yolo_description: str
    caption: str

class YoloDescriber:
    def __init__(self, model_path="yolov8n.pt"):
        self.yolo_model = YOLO(model_path)

    def get_yolo_description(self, image_path):
        """Generate natural language description from YOLO detections"""
        # Run YOLO detection
        results = self.yolo_model(image_path, verbose=False)
        detected_objects = []

        # Extract high-confidence objects
        for result in results:
            boxes = result.boxes
            if boxes is not None:
                for box in boxes:
                    class_id = int(box.cls[0])
                    confidence = float(box.conf[0])
                    class_name = self.yolo_model.names[class_id]

                    if confidence > 0.0:  # Only confident detections
                        detected_objects.append(class_name)

        # Convert objects to natural description
        if not detected_objects:
            return ""

        # Group similar objects
        object_counts = {}
        for obj in detected_objects:
            object_counts[obj] = object_counts.get(obj, 0) + 1

        # Create natural language description
        descriptions = []
        for obj, count in object_counts.items():
            if count == 1:
                descriptions.append(f"a {obj}")
            else:
                descriptions.append(f"{count} {obj}s")

        # Join naturally
        if len(descriptions) == 1:
            yolo_description = f"contains {descriptions[0]}"
        elif len(descriptions) == 2:
            yolo_description = f"contains {descriptions[0]} and {descriptions[1]}"
        else:
            yolo_description = f"contains {', '.join(descriptions[:-1])}, and {descriptions[-1]}"

        return yolo_description

def load_models():
    """Load all models at startup"""
    global vision_processor, vision_model, classifier, yolo_describer
    
    print("Loading BLIP model...")
    vision_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
    vision_model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")
    
    print("Loading zero-shot classifier...")
    classifier = pipeline(
        "zero-shot-classification",
        model="facebook/bart-large-mnli",
        device=0 if torch.cuda.is_available() else -1
    )
    
    print("Loading YOLO model...")
    yolo_describer = YoloDescriber()
    
    print("All models loaded successfully!")

def get_blip_description(image_path):
    """Generate a natural language caption from an image using BLIP"""
    image = Image.open(image_path).convert('RGB')
    inputs = vision_processor(image, return_tensors="pt")
    output = vision_model.generate(**inputs, max_length=50)
    blip_caption = vision_processor.decode(output[0], skip_special_tokens=True)
    return blip_caption

def zero_shot_classify(caption: str, blip_text: str, yolo_objects: str) -> dict:
    """Classify text using zero-shot classification"""
    # Combine all text sources for context
    combined_text = f"{caption} {blip_text} {yolo_objects}"

    # The mutually exclusive labels you want
    labels = ["romantic", "good_for_kids", "classy", "casual"]

    # Run zero-shot classification
    result = classifier(combined_text, labels, multi_label=True)

    # Build a dict of label -> confidence (threshold 0.5 can be adjusted)
    attributes = {label: score > 0.5 for label, score in zip(result['labels'], result['scores'])}

    return {
        'attributes': attributes,
        'confidence_scores': dict(zip(result['labels'], result['scores'])),
        'raw_output': result
    }

def download_image(url: str) -> str:
    """Download image from URL and save to temporary file"""
    try:
        response = requests.get(str(url), stream=True, timeout=30)
        response.raise_for_status()
        
        # Create temporary file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.jpg')
        
        # Download and save image
        for chunk in response.iter_content(chunk_size=8192):
            temp_file.write(chunk)
        
        temp_file.close()
        return temp_file.name
        
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=400, detail=f"Failed to download image: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")

@app.on_event("startup")
async def startup_event():
    """Load models when the application starts"""
    load_models()

@app.get("/")
async def root():
    return {"message": "Image Classification API", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "models_loaded": all([
        vision_processor is not None,
        vision_model is not None,
        classifier is not None,
        yolo_describer is not None
    ])}

@app.post("/classify", response_model=ImageResponse)
async def classify_image(request: ImageRequest):
    """
    Classify an image from URL with the provided caption
    
    - **image_url**: URL of the image to classify
    - **caption**: Text caption describing the context
    
    Returns classification attributes: romantic, good_for_kids, classy, casual
    """
    temp_image_path = None
    
    try:
        # Download image
        temp_image_path = download_image(request.image_url)
        
        # Get BLIP description
        blip_description = get_blip_description(temp_image_path)
        
        # Get YOLO description
        yolo_description = yolo_describer.get_yolo_description(temp_image_path)
        
        # Perform zero-shot classification
        classification_result = zero_shot_classify(
            request.caption, 
            blip_description, 
            yolo_description
        )
        
        return ImageResponse(
            attributes=classification_result['attributes'],
            confidence_scores=classification_result['confidence_scores'],
            blip_description=blip_description,
            yolo_description=yolo_description,
            caption=request.caption
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if temp_image_path and os.path.exists(temp_image_path):
            try:
                os.unlink(temp_image_path)
            except:
                pass  # Ignore cleanup errors

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)