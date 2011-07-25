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
  List.assoc label l

let fetch_int l label = 
  int_of_string (List.assoc label l)

let fetch_bool l label = 
  bool_of_string (List.assoc label l)

let fetch_string_list l label =
  let rxp = Str.regexp_string (label^".") in
  List.fold_left (fun acc (k, v) -> if Str.string_match rxp k 0 then v :: acc else acc) [] l
  
let fetch_date l label = 
  Date.of_string (List.assoc label l)


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
