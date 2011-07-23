let params = Hashtbl.create 0 

let set_param = Hashtbl.replace params
let get_param = Hashtbl.find params

open Simplexmlparser

let _  = 
  List.iter
    (fun acc e -> 
      match e with
	  | Element(k, _ , PCData (v) :: _) -> set_param k v
	  | _ -> ())
    (Eliom_config.get_config ())
    
