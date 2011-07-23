let display fmt = Printf.ksprintf print_endline fmt

(* sdb utils *****************************************************************************************)

open Printf
open CalendarLib

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
  Printer.Date.from_string (List.assoc label l)
