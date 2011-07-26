{shared{
  open Lwt

  open HTML5.M
  open Eliom_output.Html5

  open Types

  open Challenge
}}

{client{

  let new_challenge_form (author, (title, (description, (difficulty, (hints, (tags, (control_code, sample_solution))))))) =
    [
      int_input ~input_type:`Hidden ~value:0 ~name:difficulty () ;
      div [
        label ~a:([a_for "title_challenge"]) [ pcdata "Title:" ];
        string_input ~a:([a_id "title_challenge"; a_required `Required]) ~input_type:`Text ~name:title () ;
      ];
      div [
        label ~a:([a_for "author_challenge"]) [ pcdata "Author:" ];
        string_input ~a:([a_id "author_challenge"; a_required `Required]) ~input_type:`Text ~name:author () ;
      ];
      div [
        label ~a:([a_for "desc_challenge"]) [ pcdata "Describe your problem:" ];
        textarea ~a:([ a_id "desc_challenge"; a_required `Required]) ~rows:10 ~cols:50 ~name:description () ;
      ];
      div [
        label ~a:([a_for "control_code_challenge"]) [ pcdata "Controle code" ];
        textarea ~a:([ a_id "control_code_challenge"; a_required `Required ]) ~rows:10 ~cols:50 ~name:control_code () ;
      ];
      div [
        label ~a:([a_for "solution_sample_code"]) [ pcdata "solution_sample" ];
        textarea ~a:([a_id "solution_sample_code"; a_required `Required ]) ~rows:10 ~cols:50 ~name:sample_solution () ;
      ];
      div [
        span [ pcdata "Some hints" ];
        ul ~a:([a_id "hints_challenge"])  [
          li [ raw_input ~input_type:`Text ~name:"hints.[0]" () ];
        ];
        button ~a:([a_id "add_hint"]) ~button_type:`Button [ span [ pcdata "Add"] ]
      ];
      div [
        label ~a:([a_for "tags_challenge"]) [ pcdata "tags" ] ;
        string_input ~a:([ a_id "tags_challenge" ]) ~input_type:`Text ~name:tags () ;
      ];
      raw_input ~input_type:`Submit ~value:"submit" ()
    ]
      
  let init_new container service =
    let form = post_form ~service new_challenge_form () in
    Dom.appendChild container (Eliom_client.Html5.of_element form);
    Js.Opt.iter (Dom_html.document ## getElementById (Js.string "add_hint")) (
      fun button ->
        button ## onclick <- Dom_html.handler (
          fun _ -> Js.Opt.iter (Dom_html.document ## getElementById (Js.string "hints_challenge")) (
            fun hint_ul ->
              let name = Printf.sprintf "hints.[%d]" ((hint_ul ## childNodes) ## length) in
              let li = li [ raw_input ~input_type:`Text ~name:name () ] in
              Dom.appendChild hint_ul (Eliom_client.Html5.of_element li)
          );
          Js._false
        )
    );
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
    )

  let init_confirmation container challenge =
    let hints_list = 
      List.fold_left (
        fun acc el ->
          li [ pcdata el ] :: acc
      ) [] challenge.hints
    in
    let tags_list = String.concat ";" challenge.tags in
    let content = 
      div [
        h3 [ pcdata challenge.title ];
        table (
          tr [ 
              td [ pcdata "author"];
              td [ pcdata challenge.author ]]
          ) [
              tr [ td [ pcdata "description"]; td [ pcdata challenge.description ]];
              tr [ td [ pcdata "sample_solution"]; td [ pcdata challenge.sample_solution ]];
              tr [td [ pcdata "control_code"]; td [ pcdata challenge.control_code ]];
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
    init_new (Eliom_client.Html5.of_element %c) %Services.Frontend.challenge_new_post
  }};

  Nutshell.home [ c ]

let build_s3_list s3_f generate_uid_f l =
  let l =
    let regexp = Str.regexp "[ \t]+" in
    List.filter (
      fun el ->
        (Str.string_match regexp el 0) != true
    ) l
  in
  Lwt_list.map_s (
    fun el ->
      let uid = generate_uid_f () in
      s3_f uid el;
      return uid
  ) l

let new_post_handler _ (author, (title, (description, (difficulty, (hints, (tags, (control_code, sample_solution))))))) =

  let regexp = Str.regexp "[; \t]+" in
  let tags_list = Str.split regexp tags in

  lwt s3_hints_list = build_s3_list Persistency.S3.set Uid.generate hints in

  let s3_description = Uid.generate () in
  let s3_control_code = Uid.generate () in
  let s3_sample_solution = Uid.generate () in
  let uid = Uid.generate () in
  let challenge = {
    uid = uid;
    author = author ;
    active = false ;
    submission_date = Date.now () ;
    title = title ;
    description = s3_description ;
    signature = "";
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
     Lwt.return (Eliom_services.preapply ~service:Services.Frontend.challenge_confirmation uid)

let challenge_confirmation_handler uid _ =
  Persistency.Challenges.get uid >>= fun challenge ->

  let c = unique (div []) in

  Eliom_services.onload {{
    init_confirmation %c %challenge
  }};

  Nutshell.home [ c ]

let _ =
  Appl.register Services.Frontend.challenge_new new_handler;
  Eliom_output.Redirection.register Services.Frontend.challenge_new_post new_post_handler;
  Appl.register Services.Frontend.challenge_confirmation challenge_confirmation_handler
