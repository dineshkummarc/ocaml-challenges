exception Missing_param of string 

let params = Hashtbl.create 0 

let set_param = Hashtbl.replace params
let get_param name = 
  try 
    Hashtbl.find params name
  with Not_found -> raise (Missing_param name)

open Simplexmlparser

let _  = 
  List.iter
    (function
	  | Element(k, _ , PCData (v) :: _) -> set_param k v
	  | _ -> ())
    (Eliom_config.get_config ())
    
