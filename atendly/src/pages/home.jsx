import Footer from "../components/footer"
import HomeDecor from "../components/homeDecoration"
import Navbar from "../components/navbar"
import NavigateAttendanceButton from "../components/navigateAttendanceBtn"
import StudentGallery from "../components/studentGallery"


export default function Home(){
    return <div className="homeMainContainer">
        <Navbar />
        <HomeDecor />
        <NavigateAttendanceButton />
        <StudentGallery />
        <Footer />
    </div>
}