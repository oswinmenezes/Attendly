from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from matlab_engine import scan_faces
from camera_service import capture_scan_images

app = FastAPI()

# 🔥 MUST be immediately after app creation
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://192.168.29.25:5173"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"status": "CCTV ready"}

@app.post("/scan")
def scan():
    print("SCAN TRIGGERED")
    images = capture_scan_images()
    result = scan_faces(images)

    return {
        "present": result,
        "count": len(result)
    }