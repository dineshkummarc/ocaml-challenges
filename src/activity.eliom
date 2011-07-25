open Lwt
open Misc
open Types

{shared{
  open Types
  type activity = [ `Anonymous_viewing of (string * sdb_key)
                  | `Someone_viewing of (string * string * sdb_key) ] deriving (Json)      

}}

{server{

  let bus : activity Eliom_bus.t = Eliom_bus.create ~size:1000 Json.t<activity>

  let rr = RR.create (fun _ -> ()) (fun _ -> ()) 6 (fun () -> None)
  let post activity = 
    try 
      display "> posting some activity" ;
      RR.push rr (Some activity) ; 
      Eliom_bus.write bus activity
    with e -> display "> panic, activity bus error: %s" (Printexc.to_string e) 

}}

{client{
  open Misc
  open HTML5.M 
  
  let widget container bus view_challenge_service max_size activities = 
   
    let rr = RR.create (fun e -> Dom.appendChild container e) (Dom.removeChild container) max_size (fun _ -> Eliom_client.Html5.of_element (div [])) in

    let render activity = 
      match activity with 
        | `Anonymous_viewing (challenge_title, challenge_id) -> 
          Eliom_client.Html5.of_element
            (div [
              pcdata "Someone is viewing" ; space () ; 
              Eliom_output.Html5.a ~service:view_challenge_service [ pcdata challenge_title ] challenge_id
             ])
        | `Someone_viewing (user, challenge_title, challenge_id) -> 
          Eliom_client.Html5.of_element 
            (div [ (* don't use space (), of_element does not know how to translate it *)
              pcdata user ;
              pcdata " " ; 
              pcdata "is viewing " ; 
              Eliom_output.Html5.a ~service:view_challenge_service [ pcdata challenge_title ] challenge_id
             ]) in
    
    let publish activity = 
      let box = render activity in 
      RR.push rr box in
    
    List.iter publish activities ; 
 
    ignore (Lwt_stream.iter publish (Eliom_bus.stream bus))       

}}

