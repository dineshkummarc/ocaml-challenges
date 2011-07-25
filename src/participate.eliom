open Lwt
open Misc
open HTML5.M


(* client logic **************************************************************************)

{client{
  open Lwt
  open Misc
  open HTML5.M
  open Eliom_output.Html5 

  let send_solution service challenge_id solver_name solution = 
    Eliom_client.call_caml_service ~service challenge_id (solver_name, solution) 
    >>= function
      | `Invalid_code msg -> alert "Invalid code: %s" msg ; return ()  
      | `Result mark -> alert "Your code ran smoothly, result is %d" mark ; return () 
  
  let solution_form (solver_name, solution) = 
    [
      div [
        label ~a:([a_for "solver_name"]) [ pcdata "Your name or email (optional):" ];
        string_input ~a:([a_id "solver_name" ]) ~input_type:`Text ~name:solver_name () ;
      ];
      div [
        label ~a:([a_for "solution"]) [ pcdata "Your implementation of a solution: " ];
        textarea ~a:([ a_id "solution"; a_required `Required]) ~rows:10 ~cols:50 ~name:solution () ;
      ];
      raw_input ~input_type:`Submit ~value:"Submit" ()
    ]

  let evaluate = Dom_html.handler (fun ev -> alert "submit" ; Js._false)
  
  (* we can't use event_arrows here as cancel seems to be broken *)
  let init challenge_id submit_solution_btn submit_solution_service = 
    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service solution_form challenge_id) in 
    let _ = Dom_html.addEventListener form Dom_html.Event.submit evaluate Js._false in 
    let canceller = ref None in
    let toggle =
      Dom_html.handler
        (fun _ ->  
          (match !canceller with 
              None -> alert "none" 
            | Some c -> alert "cancel!" ; Dom_html.removeEventListener c) ; 
          empty submit_solution_btn ; 
          Dom.appendChild submit_solution_btn form ; 
          Js._false) in
    (* canceller := Some (Event_arrows.run (Event_arrows.clicks submit_solution_btn (Event_arrows.arr toggle)) ()) ; *)
    canceller := Some (Dom_html.addEventListener submit_solution_btn Dom_html.Event.click toggle Js._false)
 
}}

(* handler *******************************************************************************)

open Challenge

let handler challenge_id _ =
  Persistency.Challenges.get challenge_id 
  >>= fun challenge -> 
  
  let title = div [ h2 [ pcdata challenge.title ]] in 
  let author = div [ pcdata challenge.author ] in
  let description = div [ pcdata challenge.description ] in 
  let signature = div [ pcdata challenge.signature ] in 
  let submit_a_solution = unique (div [ pcdata "submit a solution" ]) in

  Eliom_services.onload {{ 
    init 
    %challenge_id 
    (Eliom_client.Html5.of_element %submit_a_solution)
    %Services.Frontend.solution_check
  }} ; 
  Nutshell.home
    [
      title ; 
      author ; 
      description ; 
      signature ; 
      submit_a_solution ;
    ]


(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.challenge_view handler
