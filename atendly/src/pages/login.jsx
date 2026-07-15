import LoginForm from "../components/loginForm"
import Navbar from "../components/navbar"


export default function Login({setIsAuthenticated}){
    return <div className="loginMainContainer">
        <LoginForm setIsAuthenticated={setIsAuthenticated}/>
    </div>
}