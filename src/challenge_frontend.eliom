{shared{
  open Lwt

  open HTML5.M
  open Eliom_output.Html5

  open Types

  open Challenge
}}

{client{

  open Misc

  let new_challenge_form (author, (title, (description, (difficulty, (hints, (tags, (control_code, (sample_solution, signature)))))))) =
    [
      string_input ~a:([a_id "signature_challenge" ]) ~input_type:`Hidden ~name:signature () ;
      table ~columns:[ (colgroup [
          col ~a:([a_style "text-align: center"; a_span 3]) ();
        ])] (
          tr [
            td [ label ~a:([a_for "title_challenge"]) [ pcdata "Title" ]; ];
            td ~a:([a_colspan 2]) [ string_input ~a:([a_id "title_challenge"; a_required `Required]) ~input_type:`Text ~name:title () ; ]
          ];
        ) [
          tr [
            td [ label ~a:([a_for "author_challenge"]) [ pcdata "Author" ]; ];
            td ~a:([a_colspan 2]) [ string_input ~a:([a_id "author_challenge"; a_required `Required]) ~input_type:`Text ~name:author () ; ];
          ];
          tr [
            td [ 
                span [ pcdata "Difficulty = " ];
                span ~a:([a_id "difficulty_value"]) [ pcdata "5" ];
              ];
            td ~a:([a_colspan 2]) [ int_input ~a:([a_id "difficulty_slider"; a_step 1.0; a_input_max 10; a_input_min 1 ]) ~input_type:`Range ~value:5 ~name:difficulty (); ];
          ];
          tr [
            td [ label ~a:([a_for "desc_challenge"]) [ pcdata "Describe your problem" ]; ];
            td ~a:([a_colspan 2]) [ textarea ~a:([ a_id "desc_challenge"; a_required `Required]) ~rows:10 ~cols:50 ~name:description () ; ];
          ];
          tr [
            td [ label ~a:([a_for "control_code_challenge"]) [ pcdata "Controle code" ]; ];
            td ~a:([a_colspan 2]) [ textarea ~a:([ a_id "control_code_challenge"; a_required `Required ]) ~rows:25 ~cols:50 ~name:control_code () ; ];
          ];
          tr [
            td [ label ~a:([a_for "solution_sample_code"]) [ pcdata "Solution sample" ]; ];
            td ~a:([a_colspan 2]) [ textarea ~a:([a_id "solution_sample_code"; a_required `Required ]) ~rows:25 ~cols:50 ~name:sample_solution () ; ];
          ];
          tr [
            td ~a:([a_style "vertical-align:top"]) [ span [ pcdata "Some hints" ]; ];
            td ~a:([a_style "width: 400px"]) [ 
                ul ~a:([a_id "hints_challenge"])  [
                  li [ raw_input ~a:([a_id "first_hint_challenge"]) ~input_type:`Text ~name:"hints.value[0]" () ];
                ];
              ];
            td ~a:([a_style "vertical-align:bottom"]) [ button ~a:([a_id "add_hint"]) ~button_type:`Button [ span [ pcdata "Add"] ] ];
          ];
          tr [
            td [ label ~a:([a_for "tags_challenge"]) [ pcdata "tags" ] ; ];
            td ~a:([a_colspan 2]) [ string_input ~a:([ a_id "tags_challenge" ]) ~input_type:`Text ~name:tags () ; ];
          ];
          tr [
            td ~a:([a_colspan 3; a_style "text-align:right"]) [ button ~a:([a_id "new_challenge_submit_btn"]) ~button_type:`Submit [ span [ pcdata "Submit" ] ] ]
          ]
        ]
    ]

  let init_new container s_challenge_new s_check_interprete =

    let rec extend_hint_list hint_ul =
      let name = Printf.sprintf "hints.value[%d]" ((hint_ul ## childNodes) ## length) in
      let input = Eliom_client.Html5.of_input (raw_input ~input_type:`Text ~name:name ()) in
      let li = Eliom_client.Html5.of_li (li []) in
      let key_return = 13 in

      Dom.appendChild li input;
      Dom.appendChild hint_ul li;

      input ## focus ();
      input ## onkeypress <- Dom_html.handler (key_press_action hint_ul key_return);

      Js._false
    and key_press_action hint_ul key_return e =
      match e ## keyCode = key_return with 
        | true -> extend_hint_list hint_ul
        | false -> Js._true
    in

    let form = post_form ~a:[ a_id "create_challenge_form" ] ~no_appl:true ~service:s_challenge_new new_challenge_form () in
    Dom.appendChild container (Eliom_client.Html5.of_element form);

    (* event *)

    (Dom_html.document ## getElementById (Js.string "hints_challenge"))
      >|< (fun hint_ul ->
        (Dom_html.document ## getElementById (Js.string "first_hint_challenge"))
          >|< (fun first_hint -> first_hint ## onkeypress <- Dom_html.handler (key_press_action hint_ul 13));
        (Dom_html.document ## getElementById (Js.string "add_hint"))
          >|< (fun button -> button ## onclick <- Dom_html.handler (fun _ -> extend_hint_list hint_ul)));
    
    Js.Opt.iter (Dom_html.document ## getElementById (Js.string "tags_challenge")) (
      fun tags ->
        tags ## onkeypress <- Dom_html.handler (
          fun e ->
            let space = 32 in
            let semicolon = 59 in
            if (e ## keyCode) = space then (
              let t = Js.Opt.get (Dom_html.CoerceTo.input tags) (fun _ -> failwith "oups... Sorry for that") in
              let value = Js.to_string (t ## value) in
              let len = String.length value in
              if len > 0 && value.[len - 1] <> ' ' && value.[len - 1] <> ';' then
                t ## value <- Js.string (value ^ "; ");
              Js._false
            )
            else (
              if (e ## keyCode) = semicolon then
                Js._false
              else
                Js._true
            )
        )
      );

    Js.Opt.iter (Dom_html.document ## getElementById (Js.string "difficulty_slider")) (
    fun diff ->
      Js.Opt.iter (Dom_html.CoerceTo.input diff) (
      fun diff_input ->
        Js.Opt.iter (Dom_html.document ## getElementById (Js.string "difficulty_value")) (
        fun diff_value ->
          diff_input ## onchange <- Dom_html.handler (
          fun _ ->
            diff_value ## innerHTML <- diff_input ## value;
            Js._true
          )
        )
      )
    );

    let launch_interpreter control_code sample_solution =
      let create_error_div div_instruction form_challenge s message =
        let m = div ~a:([a_id "div_error_processing"]) [ p ~a:([a_style "color:red"]) [ pcdata (Printf.sprintf "%s : %s" s message) ]] in
        let m2 = div ~a:([a_id "div_error_processing2"]) [ p ~a:([a_style "color:red"]) [ pcdata (Printf.sprintf "%s : %s" s message) ]] in
        Js.Opt.iter (Dom_html.document ## getElementById (Js.string "div_error_processing")) (
          fun div_error_processing ->
            Dom.removeChild div_instruction div_error_processing
        );
        Js.Opt.iter (Dom_html.document ## getElementById (Js.string "div_error_processing2")) (
          fun div_error_processing ->
            Dom.removeChild form_challenge div_error_processing
        );
        Dom.appendChild div_instruction (Eliom_client.Html5.of_element m);
        Dom.appendChild form_challenge (Eliom_client.Html5.of_element m2)
      in
      
      Eliom_client.call_caml_service ~service:s_check_interprete (Js.to_string control_code, Js.to_string sample_solution) ()
        >>= fun resp ->
          Js.Opt.iter (Dom_html.document ## getElementById (Js.string "challenge_instruction")) (
          fun div_instruction ->
            Js.Opt.iter (Dom_html.document ## getElementById (Js.string "create_challenge_form")) (
            fun form_challenge ->
              match resp with
                | `Invalid_code message -> create_error_div div_instruction form_challenge "Invalid code" message
                | `Panic message -> create_error_div div_instruction form_challenge "An error as occured" message
                | `Signature signature -> Js.Opt.iter (Dom_html.document ## getElementById (Js.string "create_challenge_form")) (
                                          fun form ->
                                            Js.Opt.iter (Dom_html.CoerceTo.form form) (
                                            fun form ->
                                              Js.Opt.iter (Dom_html.document ## getElementById (Js.string "signature_challenge")) (
                                              fun sign ->
                                                Js.Opt.iter (Dom_html.CoerceTo.input sign) (
                                                fun sign ->
                                                  sign ## value <- Js.string signature;
                                                  form ## submit ()
                                                )
                                              )
                                            )
                                          )
            )
          );
        Lwt.return ()

    in

    Js.Opt.iter (Dom_html.document ## getElementById (Js.string "new_challenge_submit_btn")) (
    fun submit_button ->
      Js.Opt.iter (Dom_html.document ## getElementById (Js.string "control_code_challenge")) (
      fun control_code ->
        Js.Opt.iter (Dom_html.CoerceTo.textarea control_code) (
        fun control_code ->
          Js.Opt.iter (Dom_html.document ## getElementById (Js.string "solution_sample_code")) (
          fun sample_solution ->
            Js.Opt.iter (Dom_html.CoerceTo.textarea sample_solution) (
            fun sample_solution ->
              submit_button ## onclick <- Dom_html.handler (fun _ ->
                Lwt.ignore_result (launch_interpreter (control_code ## value) (sample_solution ## value));
                Js._false
              )
            )
          )
        )
      )
    )

  let init_visualisation container challenge description sample_solution control_code hint_list signature =
    let hints_list = 
      List.fold_left (
        fun acc el ->
          li [ pcdata el ] :: acc
      ) [] hint_list
    in
    let tags_list = String.concat "; " challenge.tags in
    let content = 
      div [
        h3 [ pcdata challenge.title ];
        table (
          tr [ 
              td [ pcdata "Author"];
              td [ pcdata challenge.author ]]
          ) [
              tr [ td [ pcdata "Description"]; td [ pcdata description ]];
              tr [ td [ pcdata "Sample solution"]; td [ pcdata sample_solution ]];
              tr [ td [ pcdata "Control code"]; td [ pcdata control_code ]];
              tr [ td [ pcdata "Signature" ]; td [ pcdata signature ]];
              tr [
                td [ pcdata "hints" ];
                (match hints_list with
                  | t::h -> td [ ul hints_list ]
                  | _ -> td [ pcdata "No hints entered" ])
              ];
              tr [ td [ pcdata "Tags" ]; td [ pcdata (match tags_list with "" -> "No tags entered" | _ -> tags_list) ]]
          ]
      ] in
    Dom.appendChild (Eliom_client.Html5.of_element container) (Eliom_client.Html5.of_element content)

}}

let new_handler _ _ =
  let c = unique (div []) in

  Eliom_services.onload  {{
    init_new (Eliom_client.Html5.of_element %c) %Services.Frontend.challenge_new_post %Services.Frontend.new_challenge_interprete
  }};

  Nutshell.home [ 
    h2 [ pcdata "Sharing a challenge" ]; 
    div ~a:[ a_class [ "challenge_sharing_instructions" ]; a_id "challenge_instruction"] 
      [
        pcdata "Thanks for contributing! Please submit along with your challenge a piece of code that checks solutions and a sample solution" ;
        br () ; 
        h3 [ pcdata "Submission guidelines" ] ;
        ul [
          li [ pcdata "State a precise description of the problem. The actual signature of the solution will be inferred from the control code" ] ; 
          li [ pcdata "If the expected solution has type `a -> `b, your control code should have signature: "; br () ; 
               div ~a:[ a_class [ "centered" ]] [ pcdata "val benchmark : (`a -> `b) -> [ `Success of int * string | `Failure of string ]" ]] ;
          li [ pcdata "In case of success, the integer returned is a mark, and the higher the better (used to rank solutions)" ] 
        ]
      ] ;

    c ]
    
let build_s3_from_list s3_f generate_uid_f l =
  let l =
    let regexp = Str.regexp "^[ \t]*$" in
    List.filter (
      fun el ->
        (Str.string_match regexp el 0) <> true
    ) l
  in
  Lwt_list.map_s (
    fun el ->
      let uid = generate_uid_f () in
      s3_f uid el;
      return uid
  ) l

let build_list_from_s3 s3_f l =
  Lwt_list.map_s (fun el ->
    s3_f el
  ) l


let new_challenge_interprete_handler (control_code, sample_solution) _ =
  Interpreter.check_and_infer_signature control_code sample_solution

let new_post_handler _ (author, (title, (description, (difficulty, (hints, (tags, (control_code, (sample_solution, signature)))))))) =

  let regexp = Str.regexp "[; \t]+" in
  let tags_list = Str.split regexp tags in

  lwt s3_hints_list = build_s3_from_list Persistency.S3.set Uid.generate hints in

  let s3_description = Uid.generate () in
  let s3_control_code = Uid.generate () in
  let s3_sample_solution = Uid.generate () in
  let uid = Uid.generate () in
    
  let challenge = {
    uid;
    author ;
    active = false ;
    submission_date = Date.now () ;
    title = title ;
    description = s3_description ;
    signature ;
    difficulty = difficulty ;
    hints = s3_hints_list ;
    tags = tags_list ;
    sample_solution = s3_sample_solution ;
    control_code = s3_control_code ;
    submitted_solutions = [];
    facebook_id = "";
  } in

  Persistency.S3.set s3_description description >>= fun _ ->
  Persistency.S3.set s3_control_code control_code >>= fun _ ->
  Persistency.S3.set s3_sample_solution sample_solution >>= fun _ ->
  Persistency.Challenges.update challenge >>= fun _ ->
    let c = unique (div []) in
    Eliom_services.onload {{
      init_visualisation %c %challenge %description %sample_solution %control_code %hints %signature
    }};
    Nutshell.home [
      h2 [ pcdata "You just create a challenge !" ];
      c
    ]


let _ =
  Appl.register Services.Frontend.challenge_new new_handler;
  Appl.register Services.Frontend.challenge_new_post new_post_handler;
  Eliom_output.Caml.register Services.Frontend.new_challenge_interprete new_challenge_interprete_handler
