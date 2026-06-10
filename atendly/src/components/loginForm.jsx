export default function LoginForm(){
    return (
        <div className="loginContainer">
            <h2>
                Welcome to <br /> Attendly
            </h2>

            <span>User Name</span>
            <input type="text" placeholder="Enter your username" />

            <span>Password</span>
            <input type="password" placeholder="Enter your password" />

            <button>Login</button>
        </div>
    );
}