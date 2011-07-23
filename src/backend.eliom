open Lwt 
open Eliom_pervasives

open HTML5.M
open Eliom_output.Html5

(* generic visualization ****************************************************************)
    
{client{
  
  open HTML5.M 

  module type ELT = 
    sig 
      val __name__ : string 
    end
    

  module Viz (E : ELT) = 
    struct
      open Lwt
      
      let display service = 
        Eliom_client.call_caml_service ~service () ()
        >>= fun (references, elements) -> 
        alert "Just got %d %s" (List.length elements) E.__name__ ; 
        let box = div [] in
        return (Eliom_client.Html5.of_element box)

      let init elt_container click_zone get_service =
        let canceller =
          Event_arrows.run
            (Event_arrows.clicks
               click_zone 
               (Event_arrows.lwt_arr (fun _ -> display get_service >>= fun b -> Dom.appendChild elt_container b; return ())))
            () in 
        
        ignore canceller

    end

    module VChallenges = Viz (struct let __name__ = "challenges" end)

}}

module type ELT = 
  sig 
    type t 
    val __name__ : string
    val list : unit -> t list
  end

module Viz (E : ELT) = 
  struct
    
    open Eliom_services
    open Eliom_parameters 
    
    (* Services that send the list of elements ******************************************)
    
    let service_get = service [ "get_elements" ; E.__name__ ] unit () 
            
    let handler_get () () = 
      return (E.list ())

    let _ = Eliom_output.Caml.register service_get handler_get 

    (* Some HTML5 code ******************************************************************)
      
    let elt_container = unique (div [])
    let menu_container = 
      unique
        (div 
           [ h2 [ pcdata E.__name__ ] ; 
             elt_container 
           ])
        
  end

module VChallenges = Viz (Persistency.Challenges)

let home_handler _ _ =

  
  let onload = {{
    VChallenges.init
    (Eliom_client.Html5.of_element %VChallenges.elt_container) 
    (Eliom_client.Html5.of_element %VChallenges.menu_container)
    %VChallenges.service_get }} in 

  Eliom_services.onload onload ;
  Nutshell.home
    [ 
      h1 [ pcdata "naive backend" ] ; 
      VChallenges.menu_container
    ]


(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Backend.home home_handler