open Types

{shared{
  let (>>>) f g = g f
}}

let display fmt = Printf.ksprintf print_endline fmt

(* sdb utils *****************************************************************************************)

open Printf


let sdb_append label elements acc = 
  snd (List.fold_left (fun (i, acc) e -> (i+1), ((sprintf "%s.%d" label i), e) :: acc) (1, acc) elements)

let fetch_string l label = 
  try
    List.assoc label l
  with Not_found -> display "> missing %s" label ; raise Not_found

let fetch_int l label = 
  try
    int_of_string (List.assoc label l)
  with Not_found -> display "> missing %s" label ; raise Not_found

let fetch_bool l label = 
  try
    bool_of_string (List.assoc label l)
  with Not_found -> display "> missing %s" label ; raise Not_found

let fetch_string_list l label =
  try
    let rxp = Str.regexp_string (label^".") in
    List.fold_left (fun acc (k, v) -> if Str.string_match rxp k 0 then v :: acc else acc) [] l
  with Not_found -> display "> missing %s" label ; raise Not_found
  
let fetch_date l label = 
  try 
    Date.of_string (List.assoc label l)
  with Not_found -> display "> missing %s" label ; raise Not_found
    
let filter_empty_string_from_list l =
  let regexp = Str.regexp "^[ \t]*$" in
  List.filter (
    fun (el) ->
      (Str.string_match regexp el 0) <> true
  ) l
  
(* S3 list fonction ****)

let build_s3_from_list s3_f generate_uid_f l =
  Lwt_list.map_s (
    fun el ->
      let uid = generate_uid_f () in
      s3_f uid el;
      Lwt.return uid
  ) l

let build_list_from_s3 s3_f l =
  Lwt_list.map_s (fun el ->
    s3_f el
  ) l


{shared{
  
  module RR = 
    struct 
      type 'a t = int ref * ('a array)
      let create p r size i = (ref 0), Array.init size (fun _ -> let e = i () in p e ; e), p, r
      let push (pos, a, p, r) e =  r a.(!pos) ; a.(!pos) <- e ; p e ; pos := (!pos + 1) mod (Array.length a)  
      let load p r a = (ref 0), Array.init (Array.length a) (fun i -> let e = a.(i) in p e ; e), p, r
      let dump (pos, a, p, r) =
        let i = ref !pos in 
        let v = ref [] in 
        while (!i > 0) do 
          decr i; 
          v := a.(!i) :: !v ;  
        done ; 
        i := Array.length a ; 
        while (!i > !pos) do 
          decr i ;
          v := a.(!i) :: !v ; 
        done ; 
        List.rev !v 
        
    end

 }}

{client{

  let empty e = 
    while Js.to_bool (e##hasChildNodes ()) do 
      let c = e##firstChild in
      Js.Opt.iter c (fun c -> ignore (e##removeChild (c)))
    done

       let (><) t f = Js.Opt.bind t f  
       let (>|<) t f = Js.Opt.iter t f

(* Cancellable iter *)

open Lwt 

let cancellable_iter active f s =
  let rec loop () =
    Lwt_stream.get s >>= function
      | None -> return ()
      | Some x ->
        match !active with 
            false -> return () 
          | true -> let () = f x in
            loop ()
      
  in
  loop ()
    
let iter_for_page f s = 
  let active = ref true in 
  ignore (cancellable_iter active f s) ; 
  Eliom_client.on_unload (fun () -> active := false)

}}
