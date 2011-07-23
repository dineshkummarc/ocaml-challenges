(* TODO
   - stub out pervasives
   - stub out unix
   - strip any input line starting with '#'
 *)
open Types
open Misc

let (>>=) =  Lwt.(>>=)

let timeout = float_of_string (Config.get_param "ocaml_timeout")
let ocaml = Config.get_param "ocaml_path"
let main_function = "main"

(** Extract signature of function that soluton expects *)
let benchmark_signature code =
    let pat = "val benchmark : " in
    let stop  = String.length ") -> int = <fun>" in

    Lwt_process.with_process_full
      ~timeout
      (ocaml, [| ocaml |])
      (fun p ->
        Lwt_io.write p#stdin code
	  >>= (fun () -> Lwt_io.flush p#stdin)
	  >>= (fun () -> Lwt_io.close p#stdin)
	  >>= (fun () ->
            let stream = Lwt_io.read_lines p#stdout in
	    let rec loop _ =
	      Lwt_stream.next stream >>= (fun s ->
		if Pcre.pmatch ~pat s then
		  (match Pcre.split ~pat s with
		    | [_; s] ->
		      let signature = String.sub s 1 (String.length s - stop - 1) in
		      Lwt.return (Printf.sprintf "val %s: %s" main_function signature)
                    | _ -> loop ())
	         else	  
                  loop ()
              )
            in
            loop ()
	  )
      )

(** Check the solution to make sure it at least type checks *)
let check_solution solution =
    Lwt_process.with_process_full
      ~timeout
      (ocaml, [| ocaml |])
      (fun p ->
	Lwt_io.write p#stdin solution
	  >>= (fun () -> Lwt_io.flush p#stdin)
	  >>= (fun () -> Lwt_io.close p#stdin)
	  >>= (fun () ->
	    let outstream = Lwt_io.read_lines p#stdout in
	    let rec loop lst =
	      Lwt.catch
	       (fun () ->
	          Lwt_stream.next outstream >>= (fun s ->
		    if List.length lst > 0 || (String.length s > 0 && String.get s 0 = '#') then
		      loop (s :: lst)
		    else
		      loop lst
	          )
	       )
	       (fun _ -> Lwt.return lst)
            in
	    loop []
          )
	  >>= (fun lst ->
	    Lwt.return (String.concat "\n" (List.rev lst))
	  )
      )	  
        
(** Run the benchmark, extract the score *)
let run_benchmark challenge solution =
    Lwt_process.with_process_full
      ~timeout
      (ocaml, [| ocaml |])
      (fun p ->
        let lines =
	  [challenge;
	   "\n";
	   "let benchmark_xxxx = benchmark;;";
	   "\n";
	   solution;
	   "\n";
	   "benchmark_xxxx " ^ main_function ^ ";;";
	   "\n";
	  ] in
	let instream = Lwt_stream.of_list lines in
	Lwt_io.write_lines p#stdin instream
	  >>= (fun () -> Lwt_io.flush p#stdin)
	  >>= (fun () -> Lwt_io.close p#stdin)
	  >>= (fun () ->
	    let outstream = Lwt_io.read_lines p#stdout in
	    let rec loop last_line =
	      Lwt.catch
	       (fun () ->
	          Lwt_stream.next outstream >>= (fun s ->
	            loop (if String.length s > 10 then s else last_line)
	          )
	       )
	       (fun _ -> Lwt.return last_line)
            in
	    loop ""
          )
	  >>= (fun s ->
	    try
    	      match Pcre.extract ~pat:"[0-9]+$" s with
	        | [|s|] -> Lwt.return (`Score (int_of_string s))
	        | _     -> Lwt.return (`Failed s)
            with Not_found -> Lwt.return (`Failed s)
         )     
      )	  

(* debug code
let challenge = "let benchmark f = if f 1 = 2 then 10 else 0;;"
let solution  = "let main i = i + 1;;";;

let _ = Lwt_main.run (benchmark_signature challenge >>= (fun s -> display "signature -> %s" s; Lwt.return ()));;
let _= Lwt_main.run (run_benchmark challenge solution >>= (function
    | `Score i  ->  display "done --> %d" i; Lwt.return ()
    | `Failed s ->  display "error --> %s" s; Lwt.return ()
))

let _= Lwt_main.run (check_solution solution >>=  (fun s -> display "solution --> %s" s; Lwt.return ()))
*)
