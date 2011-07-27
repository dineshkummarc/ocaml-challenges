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
  let temp = Filename.temp_file "ochall" ".ml" in
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

let run_benchmark challenge solution = 
  Persistency.S3.get challenge.Challenge.control_code 
  >>= fun control_code -> 
  with_temporary 
    (fun source -> 
     (* generate source file *)
     lwt oc = Lwt_io.open_file ~mode:Lwt_io.output source in 
     lwt _ = 
       Lwt_list.iter_s 
         (fun s -> display "%s" s ; Lwt_io.write_line oc s)  
         [ 
           stubber ;
           "module B = struct" ; 
           control_code ;
           "end" ; 
           "module S = struct" ; 
           solution ; 
           "end" ; 
           "let _ = 
             let outfile = Sys.argv.(1) in 
             let json : Yojson.Basic.json = 
                try 
                  match B.benchmark S.main with 
                    | `Success (code, msg) -> `Assoc [ \"kind\", `Int 1 ; \"code\", `Int code ; \"msg\", `String msg ]
                    | `Failure msg -> `Assoc [ \"kind\", `Int 2 ; \"msg\", `String msg ]
               with e -> `Assoc [ \"kind\", `Int 0; \"msg\", `String (Printexc.to_string e) ] in 
             Yojson.Basic.to_file outfile json"; 
             
         ] in 
     lwt _ = Lwt_io.close oc in 
     (* compile source *)
     with_temporary 
       (fun binary -> 
         Lwt_process.exec
           ~timeout 
           ~stdout: `Keep 
           ~stderr: `Keep
           (ocamlfind, [| ocamlfind; "ocamlopt" ; "-package" ; "yojson"; source; "-o"; binary; "-linkpkg" |])
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
    