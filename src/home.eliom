open Lwt 
open Eliom_pervasives
open Misc

open HTML5.M
open Eliom_output.Html5


(* static blocks *************************************************************************)

let description = 
  div ~a:[ a_id "puzzles_description" ]
    [ 
      h2 [ pcdata "Take up the gauntlet!" ] ; 
      span [ pcdata "Here are some contributed OCaml puzzles of various difficulties to refresh your ocaml knowledge - or set up a new record!" ] ; 
      br () ; 
      br () ;
      span [ pcdata "If you now a good problem for us to twist our brains, don't hesitate to share it!" ]
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
        let js_challenge_elt = Eliom_client.Html5.of_element (unique challenge_elt) in
        Dom.appendChild challenges_list js_challenge_elt; 
        let _ = Event_arrows.run (Event_arrows.clicks js_challenge_elt (Event_arrows.lwt_arr (fun _ -> Eliom_client.change_page ~service (Challenge.uid challenge) ()))) () in
        
        return ()) challenges
        
  let load_challenges_page container page = 
    current_challenges_page := page 

  let init_challenges gets3 service_challenge_view challenges_list challenges = 
    Lwt.ignore_result (render_challenges_list gets3 service_challenge_view challenges_list challenges) 

  (* activity stuff *)
  let init_activity activity_container bus view_challenge_service max_size = 
    Activity.widget activity_container bus view_challenge_service max_size 
      
}}
    
(* main handler **************************************************************************)

let home_handler _ _ =
  let activity_container = unique (div []) in 
  let activity_max_size = 6 in
  let activity_init = List.fold_left (fun acc -> function None -> acc | Some v -> v :: acc) [] (RR.dump Activity.rr) in
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
  let cv1 = Services.Frontend.challenge_view in
  let cv2 = Services.Frontend.challenge_view in
  
  Eliom_services.onload {{ 
    
    init_challenges 
      (Persistency.fetch_from_s3 %Services.Hidden.s3_get) 
      %cv2
      (Eliom_client.Html5.of_element %challenges_list) %challenges ; 
      
    init_activity 
      (Eliom_client.Html5.of_element %activity_container)
      %Activity.bus 
      %cv1
      %activity_max_size 
      %activity_init
          
  }} ; 

  Nutshell.home
    [ 
      div ~a:[ a_id "home_left" ] 
        [
          description ;
          challenges_block ;
        ] ; 
      div ~a:[ a_id "home_right" ]
        [
          img ~src:"/img/caml_race.jpg" ~alt:"caml race" () ; 
          div ~a:[ a_id "out_activity_container" ] 
            [
              h3 [ pcdata "Recent activity" ] ;
              activity_container ; 
            ]
        ] ; 
      div ~a:[ a_class [ "clearall" ]] [] ; 
    ]

(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.home home_handler
