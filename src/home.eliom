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

  open Lwt 
  open HTML5.M

  (* Challenges pages ********************************************************************)

  let current_challenges_page = ref 0
  
  let render_challenges_list gets3 service challenges_list challenges = 
    (* XXX empty challenges_list ? *)
    Lwt_list.iter_s 
      (fun challenge -> 
        Challenge.render_html5 gets3 challenge
        >>= fun challenge_elt -> 
        alert "challenge rendered" ; 
        let js_challenge_elt = Eliom_client.Html5.of_element (unique challenge_elt) in
        Dom.appendChild challenges_list js_challenge_elt; 
        let _ = Event_arrows.run (Event_arrows.clicks js_challenge_elt (Event_arrows.lwt_arr (fun _ -> Eliom_client.change_page ~service (Challenge.uid challenge) ()))) () in
        
        return ()) challenges
        
  let load_challenges_page container page = 
    current_challenges_page := page 

  let init gets3 service_challenge_view challenges_list challenges = 
    alert "registering handlers on the home page" ;
    Lwt.ignore_result (render_challenges_list gets3 service_challenge_view challenges_list challenges) 

}}
    
(* main handler **************************************************************************)

let home_handler _ _ =
  let challenges_cardinal = Persistency.Challenges.cardinal () in
  let challenges = Persistency.Challenges.list () in 
  let challenges_list = unique (div []) in 
  
  let challenges_next = div [ pcdata "next" ] in 
  let challenges_before = div [ pcdata "before" ] in
  
  let challenges_block = 
    div [
      h2 [ pcdata "Current challenges" ; space () ; pcdata (Printf.sprintf "(%d)" challenges_cardinal) ] ;     
      div [  challenges_next ;  challenges_before ] ;
      challenges_list ;
    ] in
  
  Eliom_services.onload {{ 
    init 
       (Persistency.fetch_from_s3 %Services.Hidden.s3_get) 
       %Services.Frontend.challenge_view
       (Eliom_client.Html5.of_element %challenges_list) %challenges }} ; 

  Nutshell.home
    [ 
      description ;
      submit_a_challenge ; 
      challenges_block ; 
    ]

(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.home home_handler
