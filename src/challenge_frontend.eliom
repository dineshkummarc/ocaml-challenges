open Lwt

open HTML5.M
open Eliom_output.Html5

open Types

open Challenge
{client{
  open Challenge_client
}}

let new_handler _ _ =
  let c = unique (div []) in

  Eliom_services.onload  {{
    init_new (Eliom_client.Html5.of_element %c) %Services.Frontend.challenge_new_post %Services.Frontend.new_challenge_interprete
  }};

  Nutshell.home [ c ]

let new_challenge_interprete_handler (control_code, sample_solution) _ =
  Interpreter.check_and_infer_signature control_code sample_solution

let new_post_handler _ (author, (title, (description, (difficulty, (hints, (tags, (control_code, (sample_solution, signature)))))))) =

  let regexp = Str.regexp "[; \t]+" in
  let tags_list = Str.split regexp tags in

  let hints = Misc.filter_empty_string_from_list hints in
  lwt s3_hints_list = Misc.build_s3_from_list Persistency.S3.set Uid.generate (List.rev hints) in

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
    Nutshell.home [ c ]


let _ =
  Appl.register Services.Frontend.challenge_new new_handler;
  Appl.register Services.Frontend.challenge_new_post new_post_handler;
  Eliom_output.Caml.register Services.Frontend.new_challenge_interprete new_challenge_interprete_handler
