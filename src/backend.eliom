open Lwt 
open Eliom_pervasives

open HTML5.M
open Eliom_output.Html5

(* generic visualization ****************************************************************)
    
{client{
  
  open HTML5.M 
  open Types 

  module type ELT = 
    sig 
      type t 
      val __name__ : string 
      val render_html5 : 'a -> t -> [ HTML5_types.div ] Eliom_pervasives.HTML5.M.elt Lwt.t 
    end
    
  module Viz (E : ELT) = 
    struct
      open Lwt
      
      let display service s3_service = 
        Eliom_client.call_caml_service ~service () ()
        >>= fun elements -> 
        alert "Just got %d %s" (List.length elements) E.__name__ ; 
        Lwt_list.map_s (E.render_html5 s3_service) elements 
        >>= fun content ->
        return (Eliom_client.Html5.of_element (div content))

      let init elt_container click_zone get_service s3_service =
        let canceller =
          Event_arrows.run
            (Event_arrows.clicks
               click_zone 
               (Event_arrows.lwt_arr (fun _ -> display get_service s3_service >>= fun b -> Dom.appendChild elt_container b; return ())))
            () in 
        
        ignore canceller

    end

    module VChallenges = Viz (Challenge)
    module VSolutions = Viz (Solution)
    module VCms = Viz (Cms)
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
module VSolutions = Viz (Persistency.Solutions)
module VCms = Viz (Cms)

let home_handler _ _ =

  let onload_challenges = {{
    VChallenges.init
    (Eliom_client.Html5.of_element %VChallenges.elt_container) 
    (Eliom_client.Html5.of_element %VChallenges.menu_container)
    %VChallenges.service_get
    %Services.Hidden.s3_get }} in 

  let onload_solutions = {{
    VSolutions.init
    (Eliom_client.Html5.of_element %VSolutions.elt_container) 
    (Eliom_client.Html5.of_element %VSolutions.menu_container)
    %VSolutions.service_get
    %Services.Hidden.s3_get }} in 

   let onload_cms = {{
    VCms.init
    (Eliom_client.Html5.of_element %VCms.elt_container) 
    (Eliom_client.Html5.of_element %VCms.menu_container)
    %VCms.service_get
    %Services.Hidden.s3_get }} in 

  Eliom_services.onload onload_challenges ;
  Eliom_services.onload onload_solutions ;
  Eliom_services.onload onload_cms ; 
  Nutshell.home
    [ 
      h1 [ pcdata "naive backend" ] ; 
      VChallenges.menu_container ; 
      VSolutions.menu_container ; 
      VCms.menu_container
    ]


(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Backend.home home_handler
