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
import time

# ──────────────────────────────────────────────
# Setup logging
# ──────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Allow Flutter to connect from any origin

# ──────────────────────────────────────────────
# Load HandLandmarker model
# Make sure hand_landmarker.task is in the backend folder!
# ──────────────────────────────────────────────

BaseOptions = python.BaseOptions
HandLandmarker = vision.HandLandmarker
HandLandmarkerOptions = vision.HandLandmarkerOptions
VisionRunningMode = vision.RunningMode

options = HandLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path='/Users/hammadsafi/Library/Mobile Documents/com~apple~CloudDocs/VisionIDE/visionide/backend/hand_landmarker.task'  # or full absolute path if needed
    ),
    running_mode=VisionRunningMode.VIDEO,
    num_hands=1,  # we usually need only one hand for coding
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
# Global state – updated continuously by camera thread
# ──────────────────────────────────────────────

last_index_finger = {"x": 0.5, "y": 0.5}  # normalized 0..1
last_gesture = "none"

# ──────────────────────────────────────────────
# Gesture detection function
# ──────────────────────────────────────────────

def detect_gesture(hand_landmarks):
    """
    Very simple gesture detection based on landmark distances/positions
    Returns one of: 'open_palm', 'pinch', 'fist', 'point', 'none'
    """
    if len(hand_landmarks) < 21:
        return "none"

    thumb_tip   = hand_landmarks[4]
    index_tip   = hand_landmarks[8]
    middle_tip  = hand_landmarks[12]
    ring_tip    = hand_landmarks[16]
    pinky_tip   = hand_landmarks[20]

    # Distance between thumb and index tip (pinch)
    pinch_dist = ((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2) ** 0.5

    # Check if fingers are curled (fist)
    is_fist = (
        index_tip.y > middle_tip.y and
        middle_tip.y > ring_tip.y and
        ring_tip.y > pinky_tip.y
    )

    # Pointing: only index finger is extended
    is_pointing = (
        index_tip.y < middle_tip.y and
        index_tip.y < ring_tip.y and
        index_tip.y < pinky_tip.y and
        thumb_tip.y > index_tip.y
    )

    # Open palm: all fingers extended and spread
    is_open_palm = not is_fist and not is_pointing and pinch_dist > 0.05

    if pinch_dist < 0.035:
        return "pinch"        # select / grab
    elif is_fist:
        return "fist"         # delete / close menu
    elif is_pointing:
        return "point"        # move cursor
    elif is_open_palm:
        return "open_palm"    # release / normal move
    else:
        return "none"


# ──────────────────────────────────────────────
# Camera loop – runs in background thread
# Continuously updates last_index_finger and last_gesture
# ──────────────────────────────────────────────

def camera_loop():
    global last_index_finger, last_gesture

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    if not cap.isOpened():
        logger.error("Cannot open camera")
        return

    logger.info("Camera loop started – tracking hand continuously")

    timestamp = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.1)
            continue

        frame = cv2.flip(frame, 1)  # mirror horizontally

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)

        timestamp += 33  # approx 30 fps

        result = landmarker.detect_for_video(mp_image, timestamp)

        if result.hand_landmarks:
            hand_landmarks = result.hand_landmarks[0]  # first hand
            index_tip = hand_landmarks[8]

            last_index_finger["x"] = float(index_tip.x)
            last_index_finger["y"] = float(index_tip.y)

            last_gesture = detect_gesture(hand_landmarks)

            # Optional: log every few frames to see it's alive
            # if timestamp % 300 == 0:
            #     logger.info(f"Hand detected – gesture: {last_gesture}, pos: {last_index_finger}")

        time.sleep(0.033)  # ~30 fps

    cap.release()


# ──────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "running",
        "endpoints": [
            "/process_frame (POST) - send JPEG frame (optional)",
            "/finger (GET) - get latest finger position + gesture"
        ]
    })


@app.route('/process_frame', methods=['POST'])
def process_frame():
    try:
        if not request.data:
            return jsonify({"success": False, "message": "No image data"}), 400

        nparr = np.frombuffer(request.data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return jsonify({"success": False, "message": "Invalid image format"}), 400

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        timestamp_ms = int(cv2.getTickCount() / cv2.getTickFrequency() * 1000)

        result = landmarker.detect_for_video(mp_image, timestamp_ms)

        if result.hand_landmarks:
            hand_landmarks_list = result.hand_landmarks[0]
            index_tip = hand_landmarks_list[8]
            x = float(index_tip.x * frame.shape[1])
            y = float(index_tip.y * frame.shape[0])

            return jsonify({
                "success": True,
                "index_finger": {"x": x, "y": y}
            })

        return jsonify({"success": False, "message": "No hand detected"})

    except Exception as e:
        logger.error(f"Frame processing error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/finger', methods=['GET'])
def get_finger():
    """Flutter polls this endpoint to get latest finger position + gesture"""
    return jsonify({
        "x": last_index_finger["x"],
        "y": last_index_finger["y"],
        "gesture": last_gesture
    })


# ──────────────────────────────────────────────
# Start camera loop in background thread
# ──────────────────────────────────────────────

threading.Thread(target=camera_loop, daemon=True).start()

if __name__ == '__main__':
    logger.info("Starting hand-tracking server on http://0.0.0.0:8000")
    app.run(host='0.0.0.0', port=8000, debug=False, threaded=True)