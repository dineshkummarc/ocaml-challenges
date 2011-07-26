(* new shot for the interpreter *)
(* at some point, sandboxing matters *)

open Lwt
open Types
open Misc

let timeout = float_of_string (Config.get_param "ocaml_timeout")
let ocamlfind = Config.get_param "ocamlfind"


(* stubber ***********************************************************************************)

let stubber = "" 

(* handle temporary files ********************************************************************)

let with_temporary f = 
  let temp = Filename.temp_file "ochall" "tmp" in
  finalize
    (fun () -> f temp)
    (fun () -> Lwt_unix.unlink temp)

(* build benchmarker *************************************************************************)

exception MalformedJson

let decode json_file = 
  match Yojson.Safe.from_file json_file with 
      `Assoc l -> 
        ( match List.assoc "kind" l with 
              `Int 1 -> 
                ( match List.assoc "code" l, List.assoc "msg" l with 
                    `Int code, `String msg -> `Success (code, msg)
                  | _ -> raise MalformedJson )
            | `Int 2 -> 
              ( match List.assoc "msg" l with 
                  `String msg -> `Failure msg 
                | _ -> raise MalformedJson)
            | `Int 0 -> 
              ( match List.assoc "msg" l with 
                  `String msg -> `Panic msg 
                | _ -> raise MalformedJson)
            | _ -> raise MalformedJson )
    | _ -> raise MalformedJson

let build_benchmarker challenge_id solution = 
  Persistency.Challenges.get challenge_id 
  >>= fun challenge -> 
  with_temporary 
    (fun source -> 
     (* generate source file *)
     lwt oc = Lwt_io.open_file ~mode:Lwt_io.output source in 
     lwt _ = 
       Lwt_list.iter_s 
         (Lwt_io.write_line oc)  
         [ 
           stubber ;
           "module B = struct" ; 
           challenge.Challenge.control_code ;
           "end" ; 
           "module S = struct" ; 
           solution ; 
           "end" ; 
           "let _ = 
             let outfile = Sys.argv.(1) in 
             let json = 
                try 
                  let r = B.benchmark S.main in 
                  match r with 
                    | `Success (code, msg) -> `Assoc [ \"kind\", `Int 1 ; \"code\", `String code ; \"msg\", `String msg ]
                    | `Failure msg -> `Assoc [ \"kind\", `Int 2 ]
               with e -> `Assoc [ \"kind\", `Int 0 ] in 
             Yojson.Safe.to_string outfile json "; 
             
         ] in 
     lwt _ = Lwt_io.close oc in 
     (* compile source *)
     with_temporary 
       (fun binary -> 
         Lwt_process.exec
           ~timeout 
           (ocamlfind, [| ocamlfind; "ocamlopt" ; "-package" ; "yojson"; source; "-o"; binary |])
         >>= function 
           | Unix.WEXITED 0 -> (* ok, compilation went fine, now we run *)
             (with_temporary 
                (fun json -> 
                  Lwt_process.exec 
                    ~timeout 
                    (binary, [| binary; json |])
                    >>= function 
                      | Unix.WEXITED 0 -> (* ok, execution went file, now we grab the return value *)
                        (
                          return ( decode json ) (* <- non cooperative call *)
                        )
                      | _ -> (* oops, execution failed, should never happen *)
                        return (`Panic "sorry, the benchmark couldn't be run")
                )
             )
             
           | _ -> (* oops, we fail and return the output *) return (`Invalid_code "but I don't know why")))
    
