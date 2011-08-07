(* the usual gloomy stuff *)

open Lwt
open Misc
open Types

(*
let _ = 
  display "> inserting dummy values" ; 
  let open Challenge in 
      let s3_solution = Uid.generate () in
      let s3_control_code = Uid.generate () in 
      let s3_description = Uid.generate () in

      Lwt_main.run 
        (
          Persistency.S3.set s3_solution "dummy_solution" >>= fun _ -> 
          Persistency.S3.set s3_description "Write a function main that takes an integer as an argument and return its successor" >>= fun _ -> 
          Persistency.S3.set s3_control_code "let benchmark f = match f 1 with 2 -> `Success (1, \"Not so bad dude\") | _ -> `Failure (\"Your code does not solve the challenge..\")"
          >>= fun _ ->
        let hints = [ "hint 1"; "hint 2"; "hint 3";] in
        lwt s3_hints_list = Misc.build_s3_from_list Persistency.S3.set Uid.generate (List.rev hints) in
        
          let c1 = {
            uid = Uid.generate () ; 
            author = "William" ; 
            active = true ; 
            submission_date = Date.now () ;
            title = "challenge #1" ; 
            description = s3_description ; 
            signature = "val main: int -> int" ; 
            difficulty = 10 ; 
            hints = s3_hints_list;
            tags = [ "test" ; "ocaml"; "first"; "fact" ] ; 
            sample_solution = s3_solution ; 
            control_code = s3_control_code ; 
            submitted_solutions = [] ;
            facebook_id = "" 
          } in
          Persistency.Challenges.update c1
        )
*)

(*

let _ = 
  (* Generating some activity *)
  let i = ref 0 in
  let rec genac () = 
    incr i ; 
    Lwt_unix.sleep 2.0 >>= fun _ -> Activity.post (`Someone_viewing ("william", "challenge " ^ (string_of_int !i), "0")) ; genac () in 
  ignore (genac ()) 

*)

(* Extending solutions *)

let rec insert_ordered e l = 
  match l with 
      [] -> return [ e.Solution.uid ]
    | t::q -> 
      Persistency.Solutions.get t >>= fun solution -> 
      match solution.Solution.status, e.Solution.status with 
          `Score s1, `Score s2 -> 
            (if s1 > s2 then
                (insert_ordered e q) >>= fun ls -> return (t::ls) 
             else 
                (insert_ordered solution q) >>= fun ls -> return (e.Solution.uid ::ls))
        | _, `Score _ -> return (e.Solution.uid :: t :: q)
        | _, _ -> insert_ordered e q >>= fun ls -> return (t::ls)
        
 
let compute_score () = 
  let solutions = Persistency.Solutions.list () in 
  Lwt_list.iter_s 
    (fun solution -> 
      display "> investing solution %s" (Solution.uid solution) ;
      Persistency.Challenges.get solution.Solution.challenge_id 
      >>= fun challenge -> 
      Persistency.S3.get solution.Solution.content 
      >>= fun source ->
      Interpreter.run_benchmark challenge source
      >>= fun r -> 
      let status = 
        match r with 
            `Success (mark, _) -> display "> a success with mark %d" mark ; `Score (mark) 
          | _ -> display "> a failure" ; `Failed ("","") in 
      
      let solution = let open Solution in { solution with status } in 
                     Persistency.Solutions.update solution
                     >>= fun _ -> (* now we insert *)
                     Persistency.S3.get challenge.Challenge.submitted_solutions 
                     >>= Misc.s3_to_string_list 
                     >>= fun current_solutions ->
                     insert_ordered solution current_solutions
                     >>= fun submitted_solutions -> 
                     Persistency.S3.set challenge.Challenge.submitted_solutions (string_list_to_s3 submitted_solutions)

) solutions 


module StringSet = Set.Make (String)

let list_unique l = 
  let rec iter acc = function 
    | [] -> []
    | t::q when (not (StringSet.mem t acc)) -> t:: (iter (StringSet.add t acc) q) 
    | t::q -> iter acc q in
  iter StringSet.empty l 
  
let clean_list () = 
  let challenges = Persistency.Challenges.list () in 
  Lwt_list.iter_s
    (fun challenge -> 
      Persistency.S3.get challenge.Challenge.submitted_solutions 
      >>= Misc.s3_to_string_list 
      >>= fun current_solutions ->
      let submitted_solutions = list_unique current_solutions in 
      Persistency.S3.set challenge.Challenge.submitted_solutions (string_list_to_s3 submitted_solutions)
    ) challenges

let reset () =
let challenges = Persistency.Challenges.list () in 
  Lwt_list.iter_s
    (fun challenge ->
      Persistency.S3.set challenge.Challenge.submitted_solutions (string_list_to_s3 [])) challenges
    

let rec reset_from_sdb ?(token=None) () = 
  SDB.select ~token Persistency.creds ("select * from " ^ Challenge.domain) 
  >>=  function 
        | `Ok (elements, token) -> 
          (
            Lwt_list.iter_s
              (fun (name, attrs) -> 
                let submitted_solutions = Uid.generate () in 
                display "resetting %s" name;
                let attrs = List.filter (fun (k, _) -> try String.sub k 0 (String.length "submitted_solutions") <> "submitted_solutions" with _ -> true) attrs in
                Persistency.S3.set submitted_solutions (Misc.string_list_to_s3 []) 
                >>= fun _ -> 
                SDB.delete_attributes Persistency.creds Challenge.domain name [ ]
                >>= fun _ ->
                SDB.put_attributes ~replace:true Persistency.creds Challenge.domain name (("submitted_solutions", Some submitted_solutions) :: attrs)
                >>= function `Ok -> return ()
                  | `Error (_, msg) -> failwith msg 
              ) elements 
              >>= fun _ -> 
            match token with 
                None -> return () 
              | Some _ -> reset_from_sdb ~token () 
             
            
          )
        | `Error _ -> display "> error while selecting ;("; return () 

let rec strip ?(token=None) ()= 
  SDB.select ~token Persistency.creds ("select * from " ^ Challenge.domain) 
  >>=  function 
        | `Ok (elements, token) -> 
          (
            Lwt_list.iter_s
              (fun (name, attrs) -> 
                if (int_of_string name > 20000) then 
                  SDB.delete_attributes Persistency.creds Challenge.domain name [ ] >>= fun _ -> return ()
                else return ()
              ) elements 
              >>= fun _ -> 
            match token with 
                None -> return () 
              | Some _ -> strip ~token () 
             
            
          )
        | `Error _ -> display "> error while selecting ;("; return () 
  (*
let _ = 
  display "> resetting" ; 
  (* Lwt_main.run (strip ()); *) 
  display "> renumbering solutions";   
  Lwt_main.run (compute_score ()) ; 
  display "> ok it's done and it ran fine" ; 
  display "> now cleaning the list" ;
  Lwt_main.run (clean_list ()); 
  display "> system cleaned"
 
  *)
