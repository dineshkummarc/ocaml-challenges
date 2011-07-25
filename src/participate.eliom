open Lwt
open Misc
open HTML5.M


(* client logic **************************************************************************)

{client{
  open Lwt
  open Misc
  open HTML5.M
  open Eliom_output.Html5 
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

  let init challenge_id submit_solution_btn submit_solution_service = 
    let form = post_form submit_solution_service solution_form challenge_id in 
    let visible = ref false in 
    let toggle _ = 
      match !visible with 
          true -> ()
        | false -> empty submit_solution_btn ; Dom.appendChild submit_solution_btn (Eliom_client.Html5.of_element form) in
    let _ = Event_arrows.run (Event_arrows.clicks submit_solution_btn (Event_arrows.arr toggle)) () in 
    ()
 
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
