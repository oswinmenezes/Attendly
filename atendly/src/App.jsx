import { Routes, Route } from "react-router-dom";
import Home from "./pages/home";
import "./index.css"
import Login from "./pages/login";
import StudentAttendance from "./pages/studentAttendance";
import ScanAttendance from "./pages/scanAttendance";
import { useState } from "react";
import { Navigate } from "react-router-dom";

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(() => localStorage.getItem("isAuthenticated") === "true");
  return (
    <Routes>
      <Route path="/login" element={<Login setIsAuthenticated={setIsAuthenticated}/>}/>
      <Route path="/" element={isAuthenticated ? <Home /> : <Navigate to="/login" />} />
      <Route path="/student-attendance/:name" element={isAuthenticated ? <StudentAttendance /> : <Navigate to="/login" />} />
      <Route path="/scan" element={isAuthenticated ? <ScanAttendance /> : <Navigate to="/login" />} />
    </Routes>
  );
}