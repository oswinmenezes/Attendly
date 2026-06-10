import { useParams } from "react-router-dom";
import BackBtn from "../components/backButton";
import Navbar from "../components/navbar";
import {useState,useEffect} from "react"
import { supabase } from "../../supabaseClient";

export default function StudentAttendance(){
    const {name}=useParams();
    console.log(name);
    const [attendanceData,setAttendanceData] =useState([]);
    const [attendance_percent,setAttendancePercent]=useState(0);
    useEffect(() => {
        const fetchAttendance = async () => {
            const { data, error } = await supabase
                .from("attendance")
                .select("*").eq("name",name);

            if (error) {
                console.log("Error:", error);
            } else {
                console.log(data);
                setAttendanceData(data);
                const total = data.length;
                const present = data.filter(
                (item) => item.status === "Present"
                ).length;

                const percent =
                total === 0 ? 0 : Math.floor((present / total) * 100);

                setAttendancePercent(percent);
                console.log(percent);
            }
            };

            fetchAttendance();
        }, []);

    return <div className="studentAttendancePage">
        <Navbar />
        <BackBtn />
        <div className="studentDet">
            <div className="profile"></div>
            <div className="studentName">{name}</div>
            <div className="sd">Attendance :{attendance_percent}</div> 
            {/* can remove the attendance 80 line if it fucks up */}
        </div>
        
        <div className="attendanceContainer">
            {
            attendanceData.map((curr)=>{
                return <div className="attendance" key={curr.session_id}>
                    <span>{curr.date}</span>
                    <span className={`attendanceStatus ${curr.status=="Present"?'green':'red'}`}>{curr.status}</span>
                    <div className="presentAbsentBtns">
                        <button className="presentBtn" onClick={async()=>{
                            await supabase.from("attendance").update({status:"Present"}).eq("session_id",curr.session_id)
                        }}>Present</button>
                        <button className="absentBtn" onClick={async()=>{
                            await supabase.from("attendance").update({status:"Absent"}).eq("session_id",curr.session_id)
                        }}>Absent</button>
                    </div>
                </div>
            })
            }
        </div>
    </div>
}