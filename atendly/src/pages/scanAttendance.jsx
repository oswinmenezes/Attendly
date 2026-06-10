import { useState, useEffect, useRef } from "react";
import BackBtn from "../components/backButton";
import Navbar from "../components/navbar";
import axios from "axios";
import { supabase } from "../../supabaseClient";
import { useParams } from "react-router-dom";

export default function ScanAttendance() {
    const { session_id } = useParams();

    const [scanned, setScan] = useState(false);
    const [loading, setLoading] = useState(false);
    const [students, setStudents] = useState([]);
    const [detectedFaces, setDetectedFaces] = useState([]);

    const currentSessionId = useRef(session_id || null);
    const [presentNames, setPresentNames] = useState(new Set());

    useEffect(() => {
        const fetchStudents = async () => {
            const { data, error } = await supabase
                .from("student_details")
                .select("*");
            if (error) { console.error(error); return; }
            setStudents(data || []);
        };
        fetchStudents();
    }, []);

    const normalize = (str) =>
        typeof str === "string" ? str.toLowerCase().trim() : "";

    const incrementAttendance = async (name, newSessionId) => {
        const { data: sd } = await supabase
            .from("student_details")
            .select("attendance")
            .eq("name", name)
            .single();

        const currentCount = Math.round((sd.attendance / 100) * (newSessionId - 1));
        const newCount = currentCount + 1;
        const percentage = Math.round((newCount / newSessionId) * 100);

        await supabase
            .from("student_details")
            .update({ attendance: percentage })
            .eq("name", name);
    };

    const decrementAttendance = async (name, sessionId) => {
        const { data: sd } = await supabase
            .from("student_details")
            .select("attendance")
            .eq("name", name)
            .single();

        const currentCount = Math.round((sd.attendance / 100) * sessionId);
        const newCount = Math.max(currentCount - 1, 0);
        const percentage = Math.round((newCount / sessionId) * 100);

        await supabase
            .from("student_details")
            .update({ attendance: percentage })
            .eq("name", name);
    };

    async function startScan() {
        try {
            setLoading(true);
            setScan(false);

            // 1. FACE API CALL
            const result = await axios.post("http://192.168.29.25:3000/scan");
            const faces = result.data.present || [];
            console.log("RAW API:", faces);
            setDetectedFaces(faces);

            const presentSet = new Set(faces.map(normalize));

            // 2. GET NEW SESSION ID
            const { data: sessions } = await supabase
                .from("attendance")
                .select("session_id")
                .order("session_id", { ascending: false })
                .limit(1);

            const newSessionId =
                sessions && sessions.length > 0
                    ? sessions[0].session_id + 1
                    : 1;

            currentSessionId.current = newSessionId;

            const today = new Date().toISOString().split("T")[0];

            // 3. BUILD FULL SNAPSHOT
            const attendanceRows = students.map((s) => ({
                session_id: newSessionId,
                date: today,
                name: s.name,
                status: presentSet.has(normalize(s.name)) ? "Present" : "Absent",
            }));

            // 4. INSERT ONCE
            const { error: insertError } = await supabase
                .from("attendance")
                .insert(attendanceRows);

            if (insertError) {
                console.error("Insert error:", insertError);
                return;
            }

            // 5. UPDATE student_details attendance as integer percentage
            for (const s of students) {
                if (presentSet.has(normalize(s.name))) {
                    await incrementAttendance(s.name, newSessionId);
                } else {
                    const { data: sd } = await supabase
                        .from("student_details")
                        .select("attendance")
                        .eq("name", s.name)
                        .single();

                    const currentCount = Math.round((sd.attendance / 100) * (newSessionId - 1));
                    const percentage = Math.round((currentCount / newSessionId) * 100);

                    await supabase
                        .from("student_details")
                        .update({ attendance: percentage })
                        .eq("name", s.name);
                }
            }

            // 6. Seed local present state
            setPresentNames(new Set(faces.map(normalize)));

            setScan(true);
            console.log("Session saved:", newSessionId);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    }

    const updateAttendance = async (name, status) => {
        const today = new Date().toISOString().split("T")[0];
        const sid = currentSessionId.current;

        const { error } = await supabase
            .from("attendance")
            .update({ status })
            .eq("session_id", sid)
            .eq("name", name)
            .eq("date", today);

        if (error) {
            console.error("Update error:", error);
            return;
        }

        if (status === "Present") {
            await incrementAttendance(name, sid);
        } else {
            await decrementAttendance(name, sid);
        }

        setPresentNames((prev) => {
            const next = new Set(prev);
            if (status === "Present") {
                next.add(normalize(name));
            } else {
                next.delete(normalize(name));
            }
            return next;
        });
    };

    const markPresent = (name) => updateAttendance(name, "Present");
    const markAbsent = (name) => updateAttendance(name, "Absent");

    const presentStudents = students.filter((s) =>
        presentNames.has(normalize(s.name))
    );
    const absentStudents = students.filter(
        (s) => !presentNames.has(normalize(s.name))
    );

    return (
        <div>
            <Navbar />
            <BackBtn />

            {!scanned && (
                <button
                    className="startScan"
                    disabled={loading}
                    onClick={startScan}
                >
                    Start Scan
                </button>
            )}

            {loading && (
                <div className="scanPopup">
                    <div className="scanBox">
                        <h2>Scanning in Progress...</h2>
                        <div className="loader"></div>
                    </div>
                </div>
            )}

            {scanned && (
                <>
                    <div className="studentsPresent scannedStudent">
                        <h2>Students Present</h2>
                        <div className="studContainer">
                            {presentStudents.map((curr, i) => (
                                <div className="stud" key={i}>
                                    <div>
                                        <span>{curr.name}</span>
                                        <br />
                                        <span>{curr.usn}</span>
                                    </div>
                                    <button
                                        className="revokeAttendance"
                                        onClick={() => markAbsent(curr.name)}
                                    >
                                        Revoke
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="studentsAbsent scannedStudent">
                        <h2>Students Absent</h2>
                        <div className="studContainer">
                            {absentStudents.map((curr, i) => (
                                <div className="stud" key={i}>
                                    <div>
                                        <span>{curr.name}</span>
                                        <br />
                                        <span>{curr.usn}</span>
                                    </div>
                                    <button
                                        className="addAttendance"
                                        onClick={() => markPresent(curr.name)}
                                    >
                                        Mark Present
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="studentsAbsent scannedStudent">
                        <h2>ID detected but face not detected</h2>
                        <div className="studContainer">
                            {absentStudents.map((curr, i) => (
                                <div className="stud" key={i}>
                                    <div>
                                        <span>{curr.name}</span>
                                        <br />
                                        <span>{curr.usn}</span>
                                    </div>
                                    <button
                                        className="addAttendance"
                                        onClick={() => markPresent(curr.name)}
                                    >
                                        Mark Present
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>
                </>
            )}
        </div>
    );
}