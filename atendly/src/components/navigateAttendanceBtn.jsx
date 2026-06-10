import {useNavigate} from "react-router-dom" 

export default function NavigateAttendanceButton(){
    const navigate = useNavigate();
    return <button className="navigateAttendanceBtn" onClick={()=>navigate("/scan")}>Scan Attendance</button>
}