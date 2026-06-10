import cv2
import base64
import time

cap = cv2.VideoCapture(0)


def capture_scan_images():
    duration=15
    interval=3
    images = []

    start = time.time()
    last = 0

    while time.time() - start < duration:

        ret, frame = cap.read()
        if not ret:
            continue

        if time.time() - last >= interval:

            success, buffer = cv2.imencode(".jpg", frame)

            if success:
                img_b64 = base64.b64encode(buffer).decode("utf-8")
                images.append(img_b64)

            last = time.time()

    return images