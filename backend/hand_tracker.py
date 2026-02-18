import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# ──────────────────────────────────────────────
# Setup
# ──────────────────────────────────────────────

BaseOptions = python.BaseOptions
HandLandmarker = vision.HandLandmarker
HandLandmarkerOptions = vision.HandLandmarkerOptions
VisionRunningMode = vision.RunningMode

options = HandLandmarkerOptions(
    base_options=BaseOptions(model_asset_path='hand_landmarker.task'),
    running_mode=VisionRunningMode.VIDEO,
    num_hands=2,
    min_hand_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

landmarker = HandLandmarker.create_from_options(options)

cap = cv2.VideoCapture(0)  # 0 = default camera, 1 = external, etc.

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        print("Failed to grab frame")
        break

    # Convert BGR to RGB
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)

    # Timestamp in milliseconds (required for VIDEO mode)
    timestamp_ms = int(cv2.getTickCount() / cv2.getTickFrequency() * 1000)

    # Detect hands
    detection_result = landmarker.detect_for_video(mp_image, timestamp_ms)

    # Draw if hands found
    if detection_result.hand_landmarks:
        for hand_landmarks_list in detection_result.hand_landmarks:
            # Draw all 21 landmarks as small green dots
            for lm in hand_landmarks_list:
                x = int(lm.x * frame.shape[1])
                y = int(lm.y * frame.shape[0])
                cv2.circle(frame, (x, y), 5, (0, 255, 0), -1)

            # Index finger tip (landmark 8) – always exists if hand_landmarks is present
            index_tip = hand_landmarks_list[8]
            ix = int(index_tip.x * frame.shape[1])
            iy = int(index_tip.y * frame.shape[0])
            cv2.circle(frame, (ix, iy), 15, (0, 0, 255), -1)  # big red circle
            cv2.putText(frame, "Index", (ix + 20, iy), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    # Show result
    cv2.imshow('MediaPipe Hand Landmarker', frame)

    # Quit on 'q'
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()