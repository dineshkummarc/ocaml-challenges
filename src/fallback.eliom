open HTML5.M  
open Eliom_output.Html5

open Misc

let fallback _ _ =
  [
    div [
      p [
        pcdata "Hey this is not a regestrated service ! Dumb dumb !"
      ]
    ]
  ] >>> Nutshell.home

let _ =
  
  (* Appl.register Services.Frontend.challenge_new fallback; *)
  Appl.register Services.Frontend.challenge_new_post fallback;

  Appl.register Services.Frontend.challenge_verif fallback;
  Appl.register Services.Frontend.challenge_verif_update fallback;

  Appl.register Services.Frontend.delete_challenge fallback;

  Appl.register Services.Frontend.solution_new fallback;
  Appl.register Services.Frontend.solution_verif fallback;

  Appl.register Services.Frontend.solution_list fallback ; 
  Appl.register Services.Frontend.solution_check_fallback fallback ; 
  Appl.register Services.Frontend.solution_check fallback
  
