export default function Footer(){
    const d=new Date()
    let year=d.getFullYear()
    return<footer className="footer">
    © {year} Attendly. All rights reserved.
</footer>
}