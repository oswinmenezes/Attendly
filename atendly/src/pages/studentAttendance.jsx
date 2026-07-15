import { useParams } from "react-router-dom";
import BackBtn from "../components/backButton";
import Navbar from "../components/navbar";
import { useState, useEffect } from "react";
import { supabase } from "../../supabaseClient";

export default function StudentAttendance() {
    const { name } = useParams();

    const [attendanceData, setAttendanceData] = useState([]);
    const [attendancePercent, setAttendancePercent] = useState(0);

    useEffect(() => {
        const fetchAttendance = async () => {
            const { data, error } = await supabase
                .from("attendance")
                .select("*")
                .eq("name", name)
                .order("session_id", { ascending: true });

            if (error) {
                console.log("Error:", error);
                return;
            }

            setAttendanceData(data);
            recalcPercent(data);
        };

        fetchAttendance();
    }, []);

    // -----------------------------
    // RECALC PERCENT FROM LOCAL DATA
    // -----------------------------
    const recalcPercent = (data) => {
        const total = data.length;
        const present = data.filter((i) => i.status === "Present").length;
        const percent = total === 0 ? 0 : Math.round((present / total) * 100);
        setAttendancePercent(percent);
        return { present, total, percent };
    };

    // -----------------------------
    // UPDATE STATUS
    // -----------------------------
    const updateStatus = async (sessionId, newStatus) => {
        // 1. Update attendance table
        const { error } = await supabase
            .from("attendance")
            .update({ status: newStatus })
            .eq("session_id", sessionId)
            .eq("name", name);

        if (error) { console.error(error); return; }

        // 2. Update local state immediately
        const updatedData = attendanceData.map((item) =>
            item.session_id === sessionId
                ? { ...item, status: newStatus }
                : item
        );
        setAttendanceData(updatedData);

        // 3. Recalc percent locally
        const { present, total } = recalcPercent(updatedData);

        // 4. Update student_details.attendance percentage
        await supabase
            .from("student_details")
            .update({ attendance: Math.round((present / total) * 100) })
            .eq("name", name);
    };

    // -----------------------------
    // UI
    // -----------------------------
    return (
        <div className="studentAttendancePage">
            <Navbar />
            <BackBtn />

            <div className="studentDet">
                <div className="profile"></div>
                <div className="studentName">{name}</div>
                <div className="sd">Attendance: {attendancePercent}%</div>
            </div>

            <div className="attendanceContainer">
                {attendanceData.map((curr) => (
                    <div className="attendance" key={curr.session_id}>
                        <span>{curr.date}</span>
                        <span
                            className={`attendanceStatus ${
                                curr.status === "Present" ? "green" : "red"
                            }`}
                        >
                            {curr.status}
                        </span>
                        <div className="presentAbsentBtns">
                            <button
                                className="presentBtn"
                                disabled={curr.status === "Present"}
                                onClick={() => updateStatus(curr.session_id, "Present")}
                            >
                                Present
                            </button>
                            <button
                                className="absentBtn"
                                disabled={curr.status === "Absent"}
                                onClick={() => updateStatus(curr.session_id, "Absent")}
                            >
                                Absent
                            </button>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}