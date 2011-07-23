(* stages eliom *)

module M = 
  Eliom_output.Eliom_appl
    (struct
      open HTML5.M 
      let application_name = "ocaml_challenge"
     end)

include M
