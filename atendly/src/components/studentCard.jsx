import { useNavigate } from "react-router-dom"

export default function StudentCard({name,percentage,usn}){
    const navigate=useNavigate();
    return <div className="studentCard" onClick={()=>navigate(`/student-attendance/${name}`)}>
        <span className="name">{name} <br /><span>{usn}</span></span>
        <span className={`percentage ${percentage >= 80 ? "green" : "red"}`}>{percentage}</span>
    </div>
}