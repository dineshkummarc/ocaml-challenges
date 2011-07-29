open Lwt 
open Eliom_pervasives
open Misc

open HTML5.M
open Eliom_output.Html5
    
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
        let js_challenge_elt = Eliom_client.Html5.of_element (unique challenge_elt) in
        Dom.appendChild challenges_list js_challenge_elt; 
        let _ = Event_arrows.run (Event_arrows.clicks js_challenge_elt (Event_arrows.lwt_arr (fun _ -> Eliom_client.change_page ~service (Challenge.uid challenge) ()))) () in
        
        return ()) challenges
        
  let load_challenges_page container page = 
    current_challenges_page := page 

  let init_challenges gets3 service_challenge_view challenges_list challenges = 
    Lwt.ignore_result (render_challenges_list gets3 service_challenge_view challenges_list challenges) 
      
}}
    
(* main handler **************************************************************************)

let home_handler _ _ =
  let challenges_cardinal = Persistency.Challenges.cardinal () in
  let challenges = Persistency.Challenges.list () in 
  let challenges_list = unique (div []) in 
  (*
  let challenges_next = div ~a:[ a_id "challenge_nav_right" ] [ ] in 
  let challenges_before = div ~a:[ a_id "challenge_nav_left" ] [ ] in
  *)
  let challenges_block = 
    div ~a:[ a_id "challenges_block" ] [
      h2 [ pcdata "Puzzle box" ; space () ; pcdata (Printf.sprintf "(%d)" challenges_cardinal) ] ;     
      challenges_list ;
    (*  div ~a:[ a_id "challenge_nav" ] [  challenges_next ;  challenges_before ] ; *)
      div ~a:[ a_class [ "clearall" ]] [] ; 
       
    ] in

  (* quick and dirty hack to overcome the stupid type annotation issue *)
 
  let cv2 = Services.Frontend.challenge_view in
  
  Eliom_services.onload {{ 
    
    init_challenges 
      (Persistency.fetch_from_s3 %Services.Hidden.s3_get) 
      %cv2
      (Eliom_client.Html5.of_element %challenges_list) %challenges 

  }} ; 

lwt description = Cms.get "home_description" in 
  Nutshell.home
   
    [
      div description ;
      challenges_block ;
    ] 

(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.home home_handler
