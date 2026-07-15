export default function Navbar() {
    function handleLogout() {
        localStorage.removeItem("isAuthenticated");
        setIsAuthenticated(false);
        navigate("/login");
    }
    return <div className="navbarMainContainer">
        <span>Attendly</span>
        <button onClick={handleLogout}>Logout</button>
    </div>
}