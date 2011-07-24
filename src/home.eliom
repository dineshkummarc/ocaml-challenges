open Lwt 
open Eliom_pervasives

open HTML5.M
open Eliom_output.Html5


(* static blocks *************************************************************************)

let description = 
  div
    [ 
      h2 [ pcdata "Take up the gauntlet!" ] ; 
      span [ pcdata "Here are some contributed OCaml puzzle of various difficulties to refresh your ocaml knowledge - or set up a new record!" ]
    ]
    
let submit_a_challenge = 
  div 
    [
      h2 [ pcdata "Submit a challenge" ] ; 
      span [ pcdata "Contribute a new puzzle" ]
    ]


(* client logic **************************************************************************)

{client{

  (* Challenges pages ********************************************************************)

  let current_challenges_page = ref 0
  
  let load_challenges_page container page = 
    current_challenges_page := page 

   


}}
    
(* main handler **************************************************************************)

let home_handler _ _ =
  let challenges_cardinal = Persistency.Challenges.cardinal () in
  let challenges_list = Persistency.Challenges.list () in
  Lwt_list.map_s (Challenge.render_html5 Persistency.S3.get) challenges_list
  >>= fun challenges ->
  let challenges_list = div challenges in 
  
  let challenges_next = div [ pcdata "next" ] in 
  let challenges_before = div [ pcdata "before" ] in
  
  let challenges_block = 
    div [
      h2 [ pcdata "Current challenges" ; space () ; pcdata (Printf.sprintf "(%d)" challenges_cardinal) ] ;     
      div [  challenges_next ;  challenges_before ] ; 
      challenges_list ;
    ] in
      
  Nutshell.home
    [ 
      description ;
      submit_a_challenge ; 
      challenges_block ; 
    ]

(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.home home_handler
