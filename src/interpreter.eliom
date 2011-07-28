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
         let ic, oc = Unix.pipe () in (* might be correct here, after all *)
         finalize 
           (fun () -> 
             Lwt_process.exec
               ~timeout 
               ~stdout: `Keep 
               ~stderr: (`FD_move oc)
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
                   
               | _ -> (* oops, we fail and return the output *) 
                 let buf = Buffer.create 0 in
                 let t = String.create 1024 in 
                 let i = ref 0 in 
                 while (i := Unix.read ic t 0 1024; !i > 0) do Buffer.add_string buf (String.sub t 0 !i) done ; 
                 return (`Invalid_code (Buffer.contents buf)))

           (fun () -> Unix.close ic; (* Lwt_io.close (Lwt_io.of_unix_fd ~mode:Lwt_io.output oc) *) return () )))
    


(* infer solution type from control code ************************************************************************)

let let_position file ident = 
  let lident = String.length ident in
  let std_decl = Str.regexp_string ("let " ^ ident) in 
  let rec_decl = Str.regexp_string ("let rec " ^ ident) in 
  let and_decl = Str.regexp_string ("and " ^ ident) in 
  
  Lwt_io.open_file ~mode:Lwt_io.input file 
  >>= fun ic -> 
  let rec iter ic lnumber = 
    Lwt_io.read_line ic 
    >>= fun l -> 
    display "analysing line %s" l ; 
    try 
      let pos = Str.search_forward std_decl l 0 in
      return ((lnumber, pos + 4), (lnumber, pos + 4 + lident))
    with Not_found -> 
      try 
        let pos = Str.search_forward rec_decl l 0 in 
        return ((lnumber, pos + 8), (lnumber, pos + 8 + lident))
      with Not_found -> 
        try 
          let pos = Str.search_forward and_decl l 0 in 
          return ((lnumber, pos + 4), (lnumber, pos + 4 + lident))
        with Not_found -> iter ic (lnumber + 1) in 
          
  finalize 
    (fun () -> iter ic 1)
    (fun () -> Lwt_io.close ic)


let read_annot source file (l1, c1) (l2, c2)  = 
  (* "/tmp/test.ml" 1 0 4 "/tmp/test.ml" 1 0 13 *)
  display "> looking for annotation on %d %d %d %d" l1 c1 l2 c2 ; 
  let hl = Printf.sprintf "\"%s\" %d \([ 0-9 ]+\) \([ 0-9 ]+\) \"%s\" %d \([ 0-9 ]+\) \([ 0-9 ]+\)" (Str.quote source) l1 (Str.quote source) l2 in 
  let rxp = Str.regexp hl in
  Lwt_io.open_file ~mode:Lwt_io.input file
  >>= fun ic -> 
  
  let rec iter ic = 
    Lwt_io.read_line ic 
    >>= fun l -> 
    display "> analysing line %s" l ; 
    match Str.string_match rxp l 0 with 
      | true when ( int_of_string (Str.matched_group 2 l) - int_of_string (Str.matched_group 1 l) = c1 ) -> lwt _ = Lwt_io.read_line ic in 
                Lwt_io.read_line ic 
      | _ -> iter ic in

  finalize 
    (fun () -> iter ic)
    (fun () -> Lwt_io.close ic)
    
  
  let check_and_infer_signature control_code solution = 
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
         let ic, oc = Unix.pipe () in (* might be correct here, after all *)
         finalize 
           (fun () -> 
             Lwt_process.exec
               ~timeout 
               ~stdout: `Keep 
               ~stderr: (`FD_move oc)
               (ocamlfind, [| ocamlfind; "ocamlopt" ; "-annot"; "-package" ; "yojson"; source; "-o"; binary; "-linkpkg" |])
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
                          let annot = (Filename.chop_extension source) ^ ".annot" in
                          catch
                            (fun () -> 
                              let_position source "benchmark" 
                              >>= fun (p1, p2) -> 
                              read_annot source annot p1 p2 
                              >>= fun signature -> 
                              display "signature is %s" signature ; 
                              return (`Signature signature))
                            (function
                                | End_of_file -> return (`Invalid_code "no function called benchmark detected")
                                | e -> fail e))
                            
                      | _ -> (* oops, execution failed, should never happen *)
                        return (`Panic "sorry, the benchmark couldn't be run")
                    )
                 )
                   
               | _ -> (* oops, we fail and return the output *) 
                 let buf = Buffer.create 0 in
                 let t = String.create 1024 in 
                 let i = ref 0 in 
                 while (i := Unix.read ic t 0 1024; !i > 0) do Buffer.add_string buf (String.sub t 0 !i) done ; 
                 return (`Invalid_code (Buffer.contents buf)))

           (fun () -> Unix.close ic; (* Lwt_io.close (Lwt_io.of_unix_fd ~mode:Lwt_io.output oc) *) return () )))
    
