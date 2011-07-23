open CalendarLib 
open Types

open Lwt
open HTML5.M
open Eliom_output.Html5

type t = 
    {
      uid : sdb_key ; 

      author : string ;

      active : bool ; 
      submission_date : Date.t ; 

      title : string ; 
      description : s3_path ; 
      difficulty : int ; (* 1 - 10 *)
      
      hints : s3_path list ; 
      tags : string list ; 
      
      sample_solution : s3_path ; 

      control_code : s3_path ; 
      
      submitted_solutions : sdb_key list ; 
      
      facebook_id : string ;
    }

let new_challenge_form (author ,(title ,(description, (difficulty, hints)))) =
  [
    int_input ~input_type:`Hidden ~value:0 ~name:difficulty () ;
    string_input ~input_type:`Text ~name:title () ;
    string_input ~input_type:`Text ~name:author () ;
    textarea ~rows:10 ~cols:50 ~name:description () ;
    string_input ~input_type:`Text ~name:hints () ;
  ]

let new_handler _ _ =
  Eliom_services.onload {{
    post_form ~service:%Services.Frontend.challenge_new new_challenge_form ()
  }};
  Nutshell.home []
  

let _ = 
  Appl.register Services.Frontend.challenge_new new_handler