# Attendly – Smart Attendance System

Attendly is an intelligent attendance management system that combines **Facial Recognition** and **Bluetooth Low Energy (BLE)** technology to provide secure, automated, and reliable attendance tracking.

Traditional attendance systems often suffer from proxy attendance, manual errors, and time-consuming verification processes. Attendly addresses these challenges through a **dual-verification mechanism**, ensuring that attendance is marked only when both the student's face and BLE identity are verified.

---

## Problem Statement

Conventional attendance systems face several limitations:

* Proxy attendance by classmates
* Manual attendance errors
* Time-consuming roll calls
* Lack of automated verification mechanisms
* Difficulty in monitoring large classrooms efficiently

Attendly aims to solve these issues by introducing a secure, automated, and scalable attendance solution.

---

# Key Features

### Dual Verification System

* Facial recognition using deep learning models.
* BLE-based proximity verification using student devices or BLE tags.
* Significantly reduces chances of proxy attendance.

### Automated Attendance Marking

* Attendance is recorded automatically without manual intervention.
* Real-time processing and status updates.

### Real-Time Dashboard

Displays:

* Present Students
* Absent Students
* Manual Review Cases (BLE detected but face not recognized)

### Intelligent Face Recognition Pipeline

* Face detection and preprocessing using computer vision techniques.
* Deep facial embeddings generated through MATLAB-based recognition models.
* Similarity matching against stored student embeddings.

### Cross Verification Using BLE

* Detects nearby BLE devices asynchronously.
* Adds an additional layer of verification beyond facial recognition.

### Cloud Database Integration

* Stores student information, facial embeddings, and attendance records using Supabase.

---

# System Architecture

```text
                    ┌──────────────────┐
                    │ Teacher Dashboard│
                    │    (React App)   │
                    └────────┬─────────┘
                             │
                             ▼
               ┌────────────────────────┐
               │ Central Camera Server  │
               │     FastAPI Backend    │
               └──────────┬─────────────┘
                          │
      ┌───────────────────┼───────────────────┐
      ▼                   ▼                   ▼
 OpenCV Camera      MATLAB Engine        BLE Scanner
(Face Capture)    (Face Recognition)       (Bleak)
      │                   │                   │
      └───────────────────┼───────────────────┘
                          ▼
                ┌──────────────────┐
                │    Supabase      │
                │ Database & APIs  │
                └──────────────────┘
```

---

# Technology Stack

| Layer            | Technologies                      |
| ---------------- | --------------------------------- |
| Frontend         | React, Vite                       |
| Backend          | FastAPI, Python                   |
| Computer Vision  | OpenCV                            |
| Face Recognition | MATLAB Engine, ArcFace Embeddings |
| BLE Integration  | Bleak                             |
| Database         | Supabase (PostgreSQL)             |

---

# Project Structure

```text
Attendly/
│
├── atendly/                  # React Frontend
│
├── backend/                  # FastAPI Backend
│   ├── main.py
│   ├── camera_service.py
│   ├── matlab_engine.py
│   ├── ble_scanner.py
│   └── requirements.txt
│
├── dataset/                  # Raw student images
├── processed_dataset/        # Cropped face images
├── README.md
└── .env
```

---

# Workflow

### 1. Scan Initiation

The teacher initiates attendance scanning through the dashboard.

### 2. Face Capture

The backend captures classroom images through the central camera device.

### 3. Face Recognition

Captured images are analyzed using MATLAB-based facial recognition models and matched against stored embeddings.

### 4. BLE Detection

Simultaneously, nearby BLE devices are scanned asynchronously.

### 5. Attendance Verification

Results from both systems are merged:

* **Face + BLE Match → Present**
* **BLE Only → Manual Review**
* **No Match → Absent**

### 6. Dashboard Update

Attendance results are displayed in real time.

---

# Setup Instructions

## Prerequisites

* Python 3.9+
* Node.js and npm
* MATLAB with Python Engine API installed
* Supabase Project
* Webcam or External Camera
* BLE-enabled devices or tags

---

# Backend Installation

## Clone Repository

```bash
git clone https://github.com/oswinmenezes/Attendly.git
cd Attendly/backend
```

## Install Dependencies

```bash
pip install -r requirements.txt
```

## Configure Environment Variables

Create a `.env` file:

```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key
VITE_IP_ADDRESS=192.168.x.x
```

---

# Configure Backend IP Address

Attendly is designed such that the machine running the backend acts as a **central camera server**, similar to a CCTV system inside a classroom.

Other devices on the same network communicate with this server to initiate scans and retrieve attendance results.

### Find Local IPv4 Address

**Windows**

```bash
ipconfig
```

Locate:

```text
IPv4 Address . . . . . . . . . . : 192.168.x.x
```

Add this IP to the frontend `.env` file:

```env
VITE_BACKEND_URL=http://192.168.x.x:3000
```

Example:

```env
VITE_BACKEND_URL=http://192.168.1.15:3000
```

> **Note:** If the machine reconnects to a different network, its IP address may change and the `.env` file should be updated accordingly.

---

# Start Backend

```bash
python main.py
```

Backend Server:

```text
http://localhost:3000
```

---

# Frontend Installation

```bash
cd ../atendly
npm install
npm run dev
```

Frontend Server:

```text
http://localhost:5173
```

---

# Attendance States

| Status        | Description                          |
| ------------- | ------------------------------------ |
| Present       | Face and BLE successfully matched    |
| Manual Review | BLE detected but face not recognized |
| Absent        | Neither face nor BLE detected        |

---

# Future Enhancements

* Mobile application integration
* Multi-camera classroom support
* Anti-spoofing and liveness detection
* Face recognition optimization and edge deployment
* Attendance analytics dashboard
* Classroom-wise attendance reports
* IP camera and CCTV stream integration

---

# Impact

Attendly demonstrates how **Computer Vision**, **Artificial Intelligence**, and **IoT technologies** can be integrated to build secure and efficient attendance systems.

The system helps institutions:

* Reduce proxy attendance
* Minimize manual effort
* Improve attendance accuracy
* Enable automated and real-time attendance monitoring
* Scale attendance management for larger classrooms



