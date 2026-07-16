import os
import certifi

os.environ["SSL_CERT_FILE"] = certifi.where()

import asyncio
import threading
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv
from supabase import create_client, Client
from bleak import BleakScanner

from matlab_engine import scan_faces
from camera_service import capture_scan_images

# Load environment variables
load_dotenv()
dotenv_path = os.path.join(os.path.dirname(__file__), "..", "atendly", ".env")
load_dotenv(dotenv_path)

supabase_url = os.environ.get("VITE_SUPABASE_URL")
supabase_key = os.environ.get("VITE_SUPABASE_PUBLISHABLE_KEY") or os.environ.get("VITE_SUPABASE_ANON_KEY")

supabase: Client = None
if supabase_url and supabase_key:
    supabase = create_client(supabase_url, supabase_key)
else:
    print("Warning: Supabase credentials not found in environment!")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def run_ble_scanner(ble_names):
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        detected_usns = set()
        TESTING_COMPANY_ID = 65535  # company ID 0xFFFF
        
        def callback(device, advertisement_data):
            # Check local name
            if device.name:
                detected_usns.add(device.name.strip().upper())
            # Check manufacturer data payload
            man_data = advertisement_data.manufacturer_data
            if TESTING_COMPANY_ID in man_data:
                raw_bytes = man_data[TESTING_COMPANY_ID]
                try:
                    decoded_usn = raw_bytes.decode('utf-8', errors='ignore').strip().upper()
                    if decoded_usn:
                        detected_usns.add(decoded_usn)
                except Exception:
                    pass

        async def run_scan():
            scanner = BleakScanner(detection_callback=callback)
            await scanner.start()
            await asyncio.sleep(10.0)
            await scanner.stop()

        loop.run_until_complete(run_scan())
        loop.close()
        
        print("BLE Detected USNs:", detected_usns)
        
        if not detected_usns or not supabase:
            return
            
        response = supabase.table("student_details").select("name", "usn").execute()
        for student in response.data:
            usn = student.get("usn")
            if usn and usn.strip().upper() in detected_usns:
                ble_names.append(student.get("name"))
    except Exception as e:
        print("Error during BLE scan:", e)

@app.get("/")
def home():
    return {"status": "CCTV ready"}

@app.post("/scan")
def scan():
    print("SCAN TRIGGERED")
    
    # Run BLE scanning in parallel with face capture
    ble_names = []
    ble_thread = threading.Thread(target=run_ble_scanner, args=(ble_names,))
    ble_thread.start()
    
    # Capture face images (takes 15s)
    images = capture_scan_images()
    
    # Analyze faces using matlab engine
    face_names = scan_faces(images)
    
    # Wait for BLE scan to finish
    ble_thread.join()
    
    print("Result - Face:", face_names, "BLE:", ble_names)
    
    return {
        "present": face_names,
        "face_present": face_names,
        "ble_present": ble_names
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000)

