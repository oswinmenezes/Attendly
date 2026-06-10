import { Routes, Route } from "react-router-dom";
import Home from "./pages/home";
import "./index.css"
import Login from "./pages/login";
import StudentAttendance from "./pages/studentAttendance";
import ScanAttendance from "./pages/scanAttendance";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login/>}/>
      <Route path="/" element={<Home />} />
      <Route path="/student-attendance/:name" element={<StudentAttendance />} />
      <Route path="/scan" element={<ScanAttendance />} />
    </Routes>
  );
}