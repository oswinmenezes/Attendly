import matlab.engine

eng = None

def start_matlab():
    global eng

    if eng is None:
        print("Starting MATLAB Engine...")
        eng = matlab.engine.start_matlab()
        eng.addpath(
            r"C:\Users\Lenovo\Documents\MATLAB\smart-attendance-test2",
            nargout=0
        )
    return eng


def scan_faces(base64_images):
    eng = start_matlab()
    result = eng.faceRecognitionApi(base64_images)
    return list(result)