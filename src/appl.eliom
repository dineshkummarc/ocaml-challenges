(* stages eliom *)

module M = 
  Eliom_output.Eliom_appl
    (struct
      open HTML5.M 
      let application_name = "challenges"
     end)

include M
