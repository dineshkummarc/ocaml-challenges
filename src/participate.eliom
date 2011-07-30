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


  (* and build_solution_box challenge_id submit_solution_btn result_box submit_solution_service1 submit_solution_service2 = 
    let submit_handler =
      Dom_html.handler
        (fun ev -> 
          Lwt.ignore_result (send_solution submit_solution_btn result_box submit_solution_service1 submit_solution_service2 challenge_id (evaluate ())) ; 
          Js._false) in
    
    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service1 solution_form challenge_id) in 
    
    let _ = Dom_html.addEventListener form Dom_html.Event.submit submit_handler Js._false in 
    
    Dom.appendChild submit_solution_btn form  *)

  let add_event_on_hint_list () =
    Js.Opt.iter (Dom_html.document##getElementById (Js.string "btn_show_hint")) (
    fun btn_show_hint -> Js.Opt.iter (Dom_html.document##getElementById (Js.string "nb_hint_see")) (
      fun nb_hint_see-> Js.Opt.iter (Dom_html.document##getElementById (Js.string "hint_list")) (
        fun ul_hint ->
          btn_show_hint ## onclick <- Dom_html.handler (
          fun _ ->
            let li_hint_list = Misc.list_node_from_nodelist (ul_hint ## childNodes) in
            (* find in the li list if one li is hidden *)
            try
              let li_hide =
                List.find (
                  fun el ->
                    Js.Opt.case (Dom_html.CoerceTo.element el) (fun _ -> false) (
                      fun el ->
                        let s = el ## style in
                        let v = Js.to_string (s ## visibility) in
                        if v = "hidden" || v = "" then
                          let nb_view = int_of_js_string (nb_hint_see ## innerHTML) in
                          (if List.length li_hint_list > nb_view then
                              nb_hint_see ## innerHTML <- (js_string_of_int (nb_view + 1))
                            else
                              btn_show_hint ## style ## display <- Js.string "none"
                          );
                          true
                        else
                          false
                    )
                  ) li_hint_list
                in
                Js.Opt.iter (Dom_html.CoerceTo.element li_hide) (
                fun li_hide ->
                  let s = li_hide ## style in
                  s ## visibility <- Js.string "visible";
                  s ## display <- Js.string "";
                );
                Js._false
            with Not_found -> Js._false
          )
        )
      )
    )

  (* we can't use event_arrows here as cancel seems to be broken *)
  let init challenge_id submit_solution result_box hint_list submit_solution_service1 submit_solution_service2 = 

    let submit_handler =
      Dom_html.handler
        (fun ev -> 
          Lwt.ignore_result (send_solution submit_solution result_box submit_solution_service1 submit_solution_service2 challenge_id (evaluate ())) ; 
          Js._false) in

    let form = Eliom_client.Html5.of_element (Eliom_output.Html5_forms.post_form ~no_appl:true ~service:submit_solution_service1 solution_form challenge_id) in 
    let _ = Dom_html.addEventListener form Dom_html.Event.submit submit_handler Js._false in 

    let hint_list = div [
      (match List.length hint_list with
        | 0 -> div []
        | n ->
            div [
              p [ pcdata (Printf.sprintf "The author enter %d hint." n)];
              p ~a:([a_id "btn_show_hint"]) [ 
                pcdata "Click here to see ";
                span ~a:([a_id "nb_hint_see"]) [ pcdata "1" ];
                pcdata (Printf.sprintf " on %d" n);
              ]
            ]);
      ul ~a:([a_id "hint_list"]) (List.fold_left (
          fun acc el -> 
            li ~a:([a_style "display: none"]) [ pcdata el ] :: acc
          ) [] hint_list)
    ] in

    let hint_list = Eliom_client.Html5.of_element hint_list in

    Dom.appendChild submit_solution hint_list;
    add_event_on_hint_list ();
    Dom.appendChild submit_solution form
    (*     build_solution_box challenge_id submit_solution_btn result_box  submit_solution_service1 submit_solution_service2 *)
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

  Misc.build_list_from_s3 Persistency.S3.get challenge.hints
  >>= fun hint_list ->

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
    %hint_list
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
