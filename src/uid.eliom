let counter = ref 0 
let ready = ref false 

exception Not_ready 

let tick i = 
  counter := max i !counter 

let generate () = 
  match !ready with 
      false -> raise Not_ready
    | true -> incr counter ; string_of_int !counter


let unlock () = 
  counter := !counter + 1000 ; 
  ready := true 
