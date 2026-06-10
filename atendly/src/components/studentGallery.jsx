import { useEffect, useState } from "react";
import NavigateAttendanceButton from "./navigateAttendanceBtn";
import StudentCard from "./studentCard";
import { supabase } from "../../supabaseClient";

export default function StudentGallery() {
  const [students, setStudents] = useState([]);

  useEffect(() => {
    const fetchStudents = async () => {
        const { data, error } = await supabase
            .from("student_details")
            .select("name,usn,attendance");

        if (error) {
            console.log("Error:", error);
        } else {
            console.log(data);
            setStudents(data);
        }
        };

        fetchStudents();
    }, []);

  return (
    <div className="studentGalleryContainer">
      {students.map((student, index) => (
        <StudentCard
          key={index}
          name={student.name}
          usn={student.usn}
          percentage={student.attendance}
        />
      ))}
    </div>
  );
}