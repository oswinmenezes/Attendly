import { supabase } from "../../supabaseClient";
import { useState } from "react";
import { useNavigate } from "react-router-dom";

export default function LoginForm({setIsAuthenticated}) {
    const [courseCode, setCourseCode] = useState("");
    const [password, setPassword] = useState("");
    const navigate = useNavigate();

    async function handleSubmit() {
        try {
            const {data} = await supabase.from("users").select("password").eq("course_code", courseCode.toUpperCase());
            if(data && data.length > 0 && data[0].password === password){
                console.log("Login Success");
                localStorage.setItem("isAuthenticated", "true");
                setIsAuthenticated(true);
                navigate("/");
            }
            else{
                console.log("Login Failed");
            }
        }
        catch (error) {
            console.log(error);
        }
    }
    return (
        <div className="loginContainer">
            <h2>
                Welcome to <br /> Attendly
            </h2>

            <span>Course Code</span>
            <input type="text" placeholder="Enter Course Code" value={courseCode} onChange={(e) => setCourseCode(e.target.value)} />

            <span>Password</span>
            <input type="password" placeholder="Enter your password" value={password} onChange={(e) => setPassword(e.target.value)} />

            <button onClick={handleSubmit}>Login</button>
        </div>
    );
}