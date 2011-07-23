(* web frontend for stages *)

open Eliom_services
open Eliom_parameters 


module Frontend = 
  struct
    let home = service [ "" ] unit () (* problem list *)

    (* Challenge *)
    let challenge_view = service [ "challenge"; "view" ] (suffix (string "id")) ()

    let challenge_new = service [ "challenge"; "new" ] unit ()
    let challenge_new_post = post_service challenge_new (string "author" ** string "title" ** string "description" ** int "difficulty" ** string "hints") () (* add tags + control_code file sending, and maybe create facebook comment *)

    let challenge_verif = service [ "challenge"; "verification" ] (suffix (string "id")) ()
    let challenge_verif_update = service [ "challenge"; "update" ] any ()

    let delete_challenge = service [ "challenge"; "delete" ] (suffix (string "id")) ()

    (* Solution *)
    let solution_new = service [ "solution"; "new" ] unit ()
    let solution_verif = service [ "solution"; "verif"] unit ()

    let solution_list = service [ "challenge"; "solution"; "list" ] (suffix (string "challenge_id")) ()

end
