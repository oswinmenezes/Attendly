import { useEffect, useState } from "react";
import { supabase } from "../../supabaseClient";

export default function HomeDecor(){

    const d = new Date();

    let day = d.getDay();

    let date = d.getDate();

    if(day === 0){
        day = "Sunday";
    }
    else if(day === 1){
        day = "Monday";
    }
    else if(day === 2){
        day = "Tuesday";
    }
    else if(day === 3){
        day = "Wednesday";
    }
    else if(day === 4){
        day = "Thursday";
    }
    else if(day === 5){
        day = "Friday";
    }
    else{
        day = "Saturday";
    }
    const [count,setCount]=useState(0);
    useEffect(() => {
        const getCount = async () => {
            const { count, error } = await supabase
            .from("student_details")
            .select("*", { count: "exact", head: true })
            .lt("attendance", 80);

            if (error) {
            console.log("Error:", error);
            } else {
            setCount(count);
            }
        };

        getCount();
        }, []);

    return(
        <div>

            <div className="dateDay">

                <div className="date">
                    {date}
                </div>

                <div className="day">
                    {day}
                </div>

            </div>

            <div className="below80Count">
                Students below 80% attendance : {count}
            </div>

        </div>
    );
}