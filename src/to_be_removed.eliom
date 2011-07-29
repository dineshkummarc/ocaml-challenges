(* inserting a few dummy challenges *)

open Lwt
open Misc
open Types

let _ = 
  display "> inserting dummy values" ; 
  let open Challenge in 
      let s3_solution = Uid.generate () in
      let s3_control_code = Uid.generate () in 
      let s3_description = Uid.generate () in
      let c1 = {
        uid = Uid.generate () ; 
        author = "William" ; 
        active = true ; 
        submission_date = Date.now () ;
        title = "challenge #1" ; 
        description = s3_description ; 
        signature = "val main: int -> int" ; 
        difficulty = 10 ; 
        hints = [] ; 
        tags = [ "test" ; "ocaml"; "first"; "fact" ] ; 
        sample_solution = s3_solution ; 
        control_code = s3_control_code ; 
        submitted_solutions = [] ;
        facebook_id = "" 
      } in 
      Lwt_main.run 
        (Persistency.Challenges.update c1
        >>= fun _ -> Persistency.S3.set s3_solution "dummy_solution" 
        >>= fun _ -> Persistency.S3.set s3_description "Write a function main that takes an integer as an argument and return its successor" 
        >>= fun _ -> Persistency.S3.set s3_control_code "let benchmark f = match f 1 with 2 -> `Success (1, \"Not so bad dude\") | _ -> `Failure (\"Your code does not solve the challenge..\")"
        )
(*

let _ = 
  (* Generating some activity *)
  let i = ref 0 in
  let rec genac () = 
    incr i ; 
    Lwt_unix.sleep 2.0 >>= fun _ -> Activity.post (`Someone_viewing ("william", "challenge " ^ (string_of_int !i), "0")) ; genac () in 
  ignore (genac ()) 

*)
