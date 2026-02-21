import cv2

def check_camera():
    cap = cv2.VideoCapture(0)  # 0 = default camera
    if not cap.isOpened():
        print("❌ Camera cannot be accessed. Likely blocked by macOS privacy settings.")
        print("Make sure the app has permission in System Settings → Privacy & Security → Camera.")
        return False
    else:
        ret, frame = cap.read()
        if ret:
            print("✅ Camera is accessible!")
        else:
            print("⚠️ Camera opened but failed to read a frame.")
        cap.release()
        return True

if __name__ == "__main__":
    check_camera()
