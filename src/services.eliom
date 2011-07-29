(* web frontend for stages *)

open Eliom_services
open Eliom_parameters 

module Frontend = 
  struct
    let home = service [ "" ] unit () (* problem list *)

    (* Challenge *)
    let challenge_view = service [ "challenge"; "view" ] (suffix (string "id")) ()

    let challenge_new = service [ "challenge"; "new" ] unit ()
    let challenge_new_post = post_service challenge_new (string "author" ** string "title" ** string "description" ** int "difficulty" ** list "hints" (string "value") ** string "tags" ** string "control_code" ** string "sample_solution" ** string "signature") () (* add tags + control_code file sending, and maybe create facebook comment *)

    let new_challenge_interprete = service [ "challenge"; "inteprete" ] (suffix (string "control_code" ** string "sample_solution")) ()

    let delete_challenge = service [ "challenge"; "delete" ] (suffix (string "id")) ()

    (* Solution *)
    let solution_new = service [ "solution"; "new" ] unit ()
    let solution_verif = service [ "solution"; "verif"] unit ()

    let solution_list = service [ "challenge"; "solution"; "list" ] (suffix (string "challenge_id")) ()

    let solution_check_fallback = service [ "solution"; "check" ] (suffix (string "challenge_id")) () 
    let solution_check = post_service solution_check_fallback (string "name" ** string "solution") ()

      (* CMS *)
    let cms = service [ "cms" ] (suffix (string "key")) () 
         
end

module Backend = 
  struct 
    let home = service [ "backend" ; Config.get_param "salt"; "home" ] unit () 
  end

module Hidden = 
struct 
  let s3_get = service [ "hidden" ; "s3" ] (suffix (string "key")) () 
  end
  
