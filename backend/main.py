from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from matlab_engine import scan_faces
from camera_service import capture_scan_images

app = FastAPI()


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000)
