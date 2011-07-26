open Lwt
open Misc
open Types
open HTML5.M


(* client logic **************************************************************************)

{client{
  open Lwt
  open Misc
  open HTML5.M
  open Eliom_output.Html5 

  let evaluation_in_progress = 
    div [
      pcdata "We are benchmarking your solution ... be patient"  
    ]

  let format_result = function 
    | `Invalid_code msg -> div [ pcdata "Error "; span [ pcdata msg ] ] 
    | `Result_ok (mark, msg) -> div [ pcdata "Awesome" ; 
                                      span [ pcdata "your code passed the test and got result "; pcdata (string_of_int mark) ] ; 
                                      span (match msg with Some t -> [ pcdata t ] | None -> []) ]
    | `Result_notok (msg) -> div [ pcdata "Ooops"  ;
                                   span [ pcdata msg ]]
                                                                
     
  let send_solution submit_solution_box service challenge_id (solver_name, solution) = 
    empty submit_solution_box ;
    Dom.appendChild submit_solution_box (Eliom_client.Html5.of_element evaluation_in_progress) ; 
    
    Eliom_client.call_caml_service ~service challenge_id (solver_name, solution) 
    >>= fun r -> 
    empty submit_solution_box ; 
    Dom.appendChild submit_solution_box (Eliom_client.Html5.of_element (format_result r)) ; 
    return () 

  let solution_form (solver_name, solution) = 
    [
      div [
        label ~a:([a_for "solver_name"]) [ pcdata "Your name or email (optional):" ];
        string_input ~a:([a_id "solver_name" ]) ~input_type:`Text ~name:solver_name () 
      ];
      div [
        label ~a:([a_for "solution"]) [ pcdata "Your implementation of a solution: " ];
        textarea ~a:([ a_id "solution"; a_required `Required]) ~rows:10 ~cols:50 ~name:solution ()
      ];
      raw_input ~input_type:`Submit ~value:"Submit" ()
    ]
 
  let evaluate () = 
    let solver_name = Dom_html.document##getElementById (Js.string "solver_name") in 
    let solution_input = Dom_html.document##getElementById (Js.string "solution") in
    let v1 = ref "" in 
    let v2 = ref "" in
    solver_name >< Dom_html.CoerceTo.input >|< (fun e -> v1 := Js.to_string e ## value) ; 
    solution_input >< Dom_html.CoerceTo.input >|< (fun e -> v2 := Js.to_string e ## value) ;     
    !v1, !v2

  (* we can't use event_arrows here as cancel seems to be broken *)
  let init challenge_id submit_solution_btn submit_solution_service1 submit_solution_service2 = 

    let submit_handler =
      Dom_html.handler
        (fun ev -> 
          Lwt.ignore_result (send_solution submit_solution_btn submit_solution_service2 challenge_id (evaluate ())) ; 
          Js._false) in

    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service1 solution_form challenge_id) in 
    
    let _ = Dom_html.addEventListener form Dom_html.Event.submit submit_handler Js._false in 

    let canceller = ref None in

    let toggle =
      Dom_html.handler
        (fun _ ->  
          (match !canceller with 
              None -> ()
            | Some c -> Dom_html.removeEventListener c) ; 
          empty submit_solution_btn ; 
          Dom.appendChild submit_solution_btn form ; 
          Js._false) in
    (* canceller := Some (Event_arrows.run (Event_arrows.clicks submit_solution_btn (Event_arrows.arr toggle)) ()) ; *)
    canceller := Some (Dom_html.addEventListener submit_solution_btn Dom_html.Event.click toggle Js._false)
 
}}

(* handler *******************************************************************************)

open Challenge

let handler_check challenge_id (name, source) = 
  display "GOT A SOLUTION" ; 
  Persistency.Challenges.get challenge_id 
  >>= fun challenge -> 
  
  let content_path = Uid.generate () in 
  Persistency.S3.set content_path source 
  >>= fun _ -> 

  let solution = 
    let open Solution in 
        {
          uid = Uid.generate () ; 
          author = name ; 
          challenge_id ; 
          date = Date.now () ; 
          content = content_path ; 
          status = `Pending ;
        } in 

    Persistency.Solutions.update solution 
    >>= fun _ -> 
    
    Activity.post
      (match name with 
          "" -> `Anonymous_participating (challenge.title, challenge.uid) 
        | _ as name -> `Someone_participating (name, challenge.title, challenge.uid)) ; 
    
    catch 
    (fun () -> 
      Toplevel.run_benchmark challenge.control_code source 
      >>= fun _ -> return (`Invalid_code "not_implemented")
    )
    (fun e -> return (`Invalid_code (Printf.sprintf "Ooops, exception caught: %s" (Printexc.to_string e))))
  
  

let handler challenge_id _ =
  Persistency.Challenges.get challenge_id 
  >>= fun challenge -> 
  
  Activity.post (`Anonymous_viewing (challenge.title, challenge.uid)) ;
  
  let title = div [ h2 [ pcdata challenge.title ]] in 
  let author = div [ pcdata challenge.author ] in
  let description = div [ pcdata challenge.description ] in 
  let signature = div [ pcdata challenge.signature ] in 
  let submit_a_solution = unique (div [ pcdata "submit a solution" ]) in
  
  (* hack to overcome explicit typing ... *)
  let s1 = Services.Frontend.solution_check in 
  let s2 = Services.Frontend.solution_check in
  Eliom_services.onload {{ 
    
    init 
    %challenge_id 
    (Eliom_client.Html5.of_element %submit_a_solution)
    %s1 %s2

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
  Appl.register Services.Frontend.challenge_view handler ; 
  Eliom_output.Caml.register Services.Frontend.solution_check handler_check
