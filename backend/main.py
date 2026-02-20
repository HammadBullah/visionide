# backend/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np
import logging
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import threading

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ──────────────────────────────────────────────
# Load HandLandmarker model
# ──────────────────────────────────────────────
BaseOptions = python.BaseOptions
HandLandmarker = vision.HandLandmarker
HandLandmarkerOptions = vision.HandLandmarkerOptions
VisionRunningMode = vision.RunningMode

options = HandLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path='/Users/hammadsafi/Library/Mobile Documents/com~apple~CloudDocs/VisionIDE/visionide/backend/hand_landmarker.task'
    ),
    running_mode=VisionRunningMode.VIDEO,  # ← use VIDEO mode
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
# Store last normalized finger position
# ──────────────────────────────────────────────
last_index_finger = {"x": 0.5, "y": 0.5}

def camera_loop():
    global last_index_finger

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1400)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    if not cap.isOpened():
        print("Cannot open camera")
        return

    timestamp = 0
    print("Camera loop started")

    while True:
        ret, frame = cap.read()
        if not ret:
            continue
        frame = cv2.flip(frame, 1)  # ← ADD THIS
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=frame_rgb
        )

        timestamp += 1
        result = landmarker.detect_for_video(mp_image, timestamp)

        if result.hand_landmarks:
            hand_landmarks = result.hand_landmarks[0]
            index_tip = hand_landmarks[8]

            last_index_finger["x"] = float(index_tip.x)
            last_index_finger["y"] = float(index_tip.y)

            print("Updated:", last_index_finger)
# ──────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────
@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "running",
        "endpoints": [
            "/process_frame (POST) - send JPEG frame for hand tracking",
            "/finger (GET) - get last normalized index finger"
        ]
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

@app.route('/finger', methods=['GET'])
def finger():
    return jsonify(last_index_finger)  # normalized x/y (0..1) for Flutter

threading.Thread(target=camera_loop, daemon=True).start()
# ──────────────────────────────────────────────
if __name__ == '__main__':
    logger.info("Starting hand-tracking server on http://127.0.0.1:8000")
    app.run(host='0.0.0.0', port=8000, debug=False, threaded=True)