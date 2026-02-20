# backend/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np
import logging
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# ──────────────────────────────────────────────
# Setup logging
# ──────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ──────────────────────────────────────────────
# Load HandLandmarker model (once, at startup)
# Download hand_landmarker.task from:
# https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker#models
# Place it in the same folder as this script
# ──────────────────────────────────────────────

BaseOptions = python.BaseOptions
HandLandmarker = vision.HandLandmarker
HandLandmarkerOptions = vision.HandLandmarkerOptions
VisionRunningMode = vision.RunningMode

options = HandLandmarkerOptions(
    base_options=BaseOptions(model_asset_path='/Users/hammadsafi/Library/Mobile Documents/com~apple~CloudDocs/VisionIDE/visionide/backend/hand_landmarker.task'),
    running_mode=VisionRunningMode.VIDEO,
    num_hands=2,
    min_hand_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

try:
    landmarker = HandLandmarker.create_from_options(options)
    logger.info("HandLandmarker model loaded successfully")
except Exception as e:
    logger.error(f"Failed to load model: {e}")
    raise RuntimeError("Model loading failed - check file path and MediaPipe installation")

# ──────────────────────────────────────────────
# Process frame function
# ──────────────────────────────────────────────

def process_frame(frame):
    try:
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        timestamp_ms = int(cv2.getTickCount() / cv2.getTickFrequency() * 1000)

        detection_result = landmarker.detect_for_video(mp_image, timestamp_ms)

        if detection_result.hand_landmarks:
            # Take the first (most prominent) hand
            hand_landmarks_list = detection_result.hand_landmarks[0]

            # Index finger tip = landmark 8
            index_tip = hand_landmarks_list[8]
            x = float(index_tip.x * frame.shape[1])
            y = float(index_tip.y * frame.shape[0])

            return {
                "success": True,
                "index_finger": {
                    "x": x,
                    "y": y
                }
            }

        return {"success": False, "message": "No hand detected"}

    except Exception as e:
        logger.error(f"Frame processing error: {e}")
        return {"success": False, "error": str(e)}

# ──────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "running",
        "endpoints": ["/process_frame (POST) - send JPEG frame for hand tracking"]
    })


@app.route('/process_frame', methods=['POST'])
def process():
    try:
        if not request.data:
            return jsonify({"success": False, "message": "No image data"}), 400

        nparr = np.frombuffer(request.data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return jsonify({"success": False, "message": "Invalid image format"}), 400

        result = process_frame(frame)
        return jsonify(result)

    except Exception as e:
        logger.error(f"Server error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting hand-tracking server on http://127.0.0.1:8000")
    app.run(host='0.0.0.0', port=8000, debug=False, threaded=True)  # ← change host to '0.0.0.0'