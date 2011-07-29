open Lwt 
open Eliom_pervasives

open HTML5.M
open Eliom_output.Html5

open Types

(* generic visualization ****************************************************************)
    
{client{
  
  open HTML5.M 
  open Types 

  module type ELT = 
    sig 
      type key = sdb_key
      type diff deriving (Json)
      type t 
      
      val __name__ : string 
      val render_html5 : 'a -> t -> [ HTML5_types.div ] Eliom_pervasives.HTML5.M.elt Lwt.t 
      val update_form : t -> key ->
           (string, diff, [< Eliom_services.post_service_kind ],
            [< Eliom_services.suff ], 'd,
            [< string Eliom_parameters.setoneradio ]
            Eliom_parameters.param_name, [< Eliom_services.registrable ], 'e)
           Eliom_services.service -> [> HTML5_types.form ] Eliom_pervasives.HTML5.M.elt

      val build_diff : key -> diff Js.Opt.t
      val uid : t -> key
    end
    
  module Viz (E : ELT) = 
    struct
      open Lwt
        
      let menu_canceller = ref None
        
      let display service s3_service update_service = 
        Eliom_client.call_caml_service ~service () ()
        >>= fun elements -> 
        
        let container = Eliom_client.Html5.of_div (div []) in 

        let rec build_bloc elt = 
           E.render_html5 s3_service elt
            >>= fun box -> 
          
            let box_elt = Eliom_client.Html5.of_div box in
            let update_handler _ = 
              let edit_form = Eliom_client.Html5.of_form (E.update_form elt (E.uid elt) (Obj.magic update_service)) in
              edit_form##onsubmit <- Dom_html.handler
                (fun _ -> 
                  Js.Opt.iter
                    (E.build_diff (E.uid elt))
                    (fun diff -> Lwt.ignore_result 
                      (
                        Dom.removeChild container edit_form ; 
                        Eliom_client.call_caml_service update_service (E.uid elt) diff 
                        >>= build_bloc)) ;
                  Js._false) ;  

              Dom.removeChild container box_elt ; 
              Dom.appendChild container edit_form ; 
              
              Js._false in

            box_elt ## onclick <- Dom_html.handler update_handler ;
            Dom.appendChild container box_elt ; 
            return () in 

        Lwt_list.iter_s build_bloc elements 
        >>= fun _ -> return container

      let init elt_container click_zone get_service s3_service update_service =
        let canceller =
          Event_arrows.run
            (Event_arrows.clicks
               click_zone 
               (Event_arrows.lwt_arr (fun _ -> (match !menu_canceller with Some c -> Event_arrows.cancel c | None -> ()); display get_service s3_service update_service >>= fun b -> Dom.appendChild elt_container b; return ())))
            () in 
        
        menu_canceller := Some canceller

    end

    module VChallenges = Viz (Persistency.Challenges)
    module VSolutions = Viz (Persistency.Solutions)
    module VCms = Viz (Cms)
}}

module type ELT = 
  sig 
    type key = sdb_key
    type diff deriving (Json) 
    type t
      
    val __name__ : string
    val list : unit -> t list
      
    val update_diff : key -> diff -> t Lwt.t
  end

module Viz (E : ELT) = 
  struct
    
    open Eliom_services
    open Eliom_parameters 
    
    (* Services that send the list of elements ******************************************)
    
    let service_get = service [ "get_elements" ; Config.get_param "salt";  E.__name__ ] unit () 
    let service_update_fallback = service [ "update_element" ; Config.get_param "salt"; E.__name__ ] (string "key") () 
    let service_update = post_service service_update_fallback (caml "value" (Json.t< E.diff> )) () 
            
    let handler_get () () = 
      return (E.list ())

    let handler_update key value = 
      E.update_diff key value 

    let handler_fallback _ _ = Nutshell.home [ h2 [ pcdata "You're lost - or I am!" ]]
    let _ = 
      Eliom_output.Caml.register service_get handler_get ; 
      Appl.register service_update_fallback handler_fallback ;
      Eliom_output.Caml.register service_update handler_update 

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
    %Services.Hidden.s3_get
    %VChallenges.service_update }} in 

  let onload_solutions = {{
    VSolutions.init
    (Eliom_client.Html5.of_element %VSolutions.elt_container) 
    (Eliom_client.Html5.of_element %VSolutions.menu_container)
    %VSolutions.service_get
    %Services.Hidden.s3_get
    %VSolutions.service_update }} in 

  let onload_cms = {{
    VCms.init
    (Eliom_client.Html5.of_element %VCms.elt_container) 
    (Eliom_client.Html5.of_element %VCms.menu_container)
    %VCms.service_get
    %Services.Hidden.s3_get
    %VCms.service_update }} in 

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
