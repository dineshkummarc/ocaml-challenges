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
    | `Invalid_code msg -> div ~a:[ a_class [ "result_error" ]] [ pcdata "Error "; span [ pcdata msg ] ] 
    | `Success (mark, msg) -> div ~a:[ a_class [ "result_success" ]] [ pcdata "Congratulation, your code is correct with score " ; 
                                      pcdata (string_of_int mark)  ; 
                                  ]
    | `Failure msg -> div ~a:[ a_class [ "result_error" ]] [ span [ pcdata msg ]]
    | `Panic msg -> div ~a:[ a_class [ "result_error" ]] [ pcdata "Panic " ; span [ pcdata msg ]]                                                                
     
  let solution_form (solver_name, solution) = 
    [
      div [
        label ~a:([a_for "solver_name"]) [ pcdata "Your name or email (optional)" ];
        string_input ~a:([a_id "solver_name" ]) ~input_type:`Text ~name:solver_name () 
      ];
      div ~a:[ a_class [ "clearall" ]] [] ; 
      div [
        label ~a:([a_for "solution"]) [ pcdata "Your code" ];
        textarea ~a:([ a_id "solution"; a_required `Required]) ~rows:30 ~cols:70 ~name:solution ()
      ];
      div ~a:[ a_class [ "clearall" ]] [] ; 
      raw_input ~input_type:`Submit ~value:"Submit" ()
    ]
 
  let evaluate () = 
    let solver_name = Dom_html.document##getElementById (Js.string "solver_name") in 
    let solution_input = Dom_html.document##getElementById (Js.string "solution") in
    let v1 = ref "" in 
    let v2 = ref "" in
    solver_name >< Dom_html.CoerceTo.input >|< (fun e -> v1 := Js.to_string e ## value) ; 
    solution_input >< Dom_html.CoerceTo.textarea >|< (fun e -> v2 := Js.to_string e ## value) ;     
    !v1, !v2


  let rec send_solution submit_solution_box result_box service1 service2 challenge_id (solver_name, solution) = 
    
    empty result_box ; 
    Dom.appendChild result_box (Eliom_client.Html5.of_element evaluation_in_progress) ; 
    
    Eliom_client.call_caml_service ~service:service2 challenge_id (solver_name, solution) 
    >>= fun r -> 

    empty result_box ; 
    Dom.appendChild result_box (Eliom_client.Html5.of_element (format_result r)) ; 
  (*  build_solution_box challenge_id submit_solution_box result_box service1 service2  ; *)
    return () 


  and build_solution_box challenge_id submit_solution_btn result_box submit_solution_service1 submit_solution_service2 = 
    let submit_handler =
      Dom_html.handler
        (fun ev -> 
          Lwt.ignore_result (send_solution submit_solution_btn result_box submit_solution_service1 submit_solution_service2 challenge_id (evaluate ())) ; 
          Js._false) in
    
    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service1 solution_form challenge_id) in 
    
    let _ = Dom_html.addEventListener form Dom_html.Event.submit submit_handler Js._false in 
    
    Dom.appendChild submit_solution_btn form 
    
  (* we can't use event_arrows here as cancel seems to be broken *)
  let init challenge_id submit_solution_btn result_box submit_solution_service1 submit_solution_service2 = 

    let submit_handler =
      Dom_html.handler
        (fun ev -> 
          Lwt.ignore_result (send_solution submit_solution_btn result_box submit_solution_service1 submit_solution_service2 challenge_id (evaluate ())) ; 
          Js._false) in

    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service1 solution_form challenge_id) in 
    
    let _ = Dom_html.addEventListener form Dom_html.Event.submit submit_handler Js._false in 

    build_solution_box challenge_id submit_solution_btn result_box  submit_solution_service1 submit_solution_service2 
(*    let canceller = ref None in

    let toggle =
      Dom_html.handler
        (fun _ ->  
          (match !canceller with 
              None -> ()
            | Some c -> Dom_html.removeEventListener c) ; 
          empty submit_solution_btn ; 
          build_solution_box challenge_id submit_solution_btn submit_solution_service1 submit_solution_service2  ;
          Js._false) in
    (* canceller := Some (Event_arrows.run (Event_arrows.clicks submit_solution_btn (Event_arrows.arr toggle)) ()) ; *)
    canceller := Some (Dom_html.addEventListener submit_solution_btn Dom_html.Event.click toggle Js._false)
*) 
}}

(* handler *******************************************************************************)

open Challenge

let handler_check challenge_id (name, source) = 
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
    
    catch 
    (fun () -> 
      Interpreter.run_benchmark challenge source 
        >>= function 
          | `Success _ as r -> Activity.post
            (match name with 
                "" -> `Anonymous_participating (challenge.title, challenge.uid) 
              | _ as name -> `Someone_participating (name, challenge.title, challenge.uid)) ; return r
          | _ as r -> return r)
    (fun e -> return (`Panic (Printf.sprintf "Ooops, exception caught: %s" (Printexc.to_string e))))
  
  

let handler challenge_id _ =
  Persistency.Challenges.get challenge_id 
  >>= fun challenge -> 
  Persistency.S3.get challenge.description 
  >>= fun challenge_description ->

  Activity.post (`Anonymous_viewing (challenge.title, challenge.uid)); 
 
  let headline = div ~a:[ a_id "challenge_descr" ] 
    [ 
      span ~a:[ a_class [ "challenge_descr_title" ]] [ pcdata challenge.title ] ; 
      span ~a:[ a_class [ "challenge_descr_author" ]] [ pcdata "by " ; pcdata challenge.author] ; 
    ] in 
  
  let description = div ~a:[ a_id "challenge_descr_description" ] 
    [ 
      b [ pcdata "Puzzle description:" ] ; 
      pcdata " "; 
      pcdata challenge_description
    ] in 
  let signature = div ~a:[ a_id "challenge_descr_signature" ] 
    [ 
      b [ pcdata "Expected solution signature:" ] ;
      pcdata " " ; 
      pcdata challenge.signature
    ] in 
  let submit_a_solution = unique (div []) in
  
  (* hack to overcome explicit typing ... *)
  let s1 = Services.Frontend.solution_check in 
  let s2 = Services.Frontend.solution_check in

  let result_box = unique (div ~a:[ a_id "result"] []) in

  Eliom_services.onload {{ 
    
    init 
    %challenge_id 
    (Eliom_client.Html5.of_element %submit_a_solution)
    (Eliom_client.Html5.of_element %result_box)
    %s1 %s2

  }} ; 

  Nutshell.home
    [
      headline; 
      description ; 
      signature ; 
      div ~a:[ a_id "solution_box" ] [ result_box ; 
                                       h2 [ pcdata "Your solution" ] ; 
                                       submit_a_solution ] ;
    ]


(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Frontend.challenge_view handler ; 
  Eliom_output.Caml.register Services.Frontend.solution_check handler_check
