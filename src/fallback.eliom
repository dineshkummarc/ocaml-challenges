open HTML5.M  
open Eliom_output.Html5

open Misc

let fallback _ _ =
  [
    div [
      p [
        pcdata "Hey this is not a registrated service ! Dumb dumb !"
      ]
    ]
  ] >>> Nutshell.home

let _ =

  Appl.register Services.Frontend.challenge_confirmation_update fallback;

  Appl.register Services.Frontend.delete_challenge fallback;

  Appl.register Services.Frontend.solution_new fallback;
  Appl.register Services.Frontend.solution_verif fallback;

  Appl.register Services.Frontend.solution_list fallback ; 
  Appl.register Services.Frontend.solution_check_fallback fallback; 

  
