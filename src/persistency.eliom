open Lwt

{shared{
  open Misc
  open Types
}}

let creds = 
  {
    Creds.aws_access_key_id = Config.get_param "aws_access_key_id" ;
    Creds.aws_secret_access_key = Config.get_param "aws_secret_access_key" ;
  }




(* s3 **************************************************************************************************)

module S3 = 
  struct 

    exception S3_error
      
    let default_region = ref `US_EAST_1
    let bucket = Config.get_param "s3_bucket" 
      
    let rec load objekt = 
      S3.get_object_s 
        (Some creds)
        !default_region
        ~bucket
        ~objekt
      >>= fun r -> 
      match r with 
        | `Ok s ->  return s
        | `NotFound 
        | `AccessDenied -> fail S3_error
        | `Error _ -> fail S3_error
        | `PermanentRedirect (Some r) -> default_region := r ; load objekt
        | `PermanentRedirect None ->  default_region := `US_EAST_1 ; load objekt
          
    let store objekt body = 
      S3.put_object creds !default_region ~bucket ~objekt ~body:(`String body) 
      >>= function 
        | `Ok -> return () 
        | `Error msg -> display "ERROR : %s" msg ; return () 
        | _ -> display "ERROR - Something else" ; return ()

module S3_cache = Ocsigen_cache.Make (struct type key = string type value = string end)
      
    let s3_cache = new S3_cache.cache load (int_of_string (Config.get_param "cache_size"))
      
    let get = s3_cache # find 
      
    let set key value = 
      store key value
      >>= fun _ -> s3_cache # add key value ; return () 
        
    let set_fresh value = 
      let key = Uid.generate () in
      set key value >>= fun _ -> return key

  end

(* sdb ***************************************************************************************************)

module type LS = 
  sig
    type key = sdb_key
    type t deriving (Json)
    type diff deriving (Json)
    val cache_size : int
    val domain : string 

    val __name__ : string 

    val uid : t -> sdb_key
    val visible : t -> bool
    val of_sdb : (string * string) list -> t
    val to_sdb : t -> (string * string) list
  
    val update_diff : (string -> s3_path Lwt.t) -> t -> diff -> t Lwt.t 
end


module LFactory (L : LS) = 
  struct
    
    exception Error

    type key = sdb_key
    type t = L.t 
    type diff = L.diff deriving (Json)

    let __name__ = L.__name__

    module C = Ocsigen_cache.Make (struct type key = sdb_key type value = L.t end)
            
    let load key = 
      SDB.get_attributes creds L.domain key
      >>= function 
        | `Ok l -> return (L.of_sdb l)
        | `Error _ -> fail Error

    let save value = 
      SDB.put_attributes ~replace:true creds L.domain (L.uid value) (L.to_sdb value)
      >>= function
        | `Ok -> return ()
        | `Error _ -> fail Error

    let cache = new C.cache load L.cache_size

    let get key = 
      cache # find key
        
    let update value = 
      save value 
      >>= function _ ->
        let key = L.uid value in
        cache # remove key ; 
        cache # add key value ; 
        return () 

    let list () = 
      List.filter L.visible (cache # list ())
      
    let update_diff key diff = 
      display "> got the diff" ;
      cache # find key 
      >>= fun value -> 
      L.update_diff (S3.set_fresh) value diff
      >>= fun value -> 
      update value >>= fun _ -> return value

    let cardinal () = 
      List.length (List.filter L.visible (cache # list ())) (* <- change that! *)

    let rec init ?(token=None) () = 
      display "> init %s" L.__name__ ; 
      SDB.select ~token creds ("select * from " ^ L.domain)
      >>= function 
        | `Ok (elements, token) -> 
          (List.iter
             (fun (name, attrs) -> 
               try 
                 (try Uid.tick (int_of_string name) with _ -> ()); 
                 let attrs = List.fold_left
                   (fun acc -> 
                     function 
                       | label, None -> (label, "") :: acc 
                       | label, Some v -> (label, v) :: acc) [] attrs in
                 let value = L.of_sdb attrs in
                 let key = L.uid value in 
                 cache # add key value 
               with e -> display "> discarding item %s from domain %s: %s" name L.domain (Printexc.to_string e)) elements ; 
           match token with 
               None -> display "> loading domain %s done" L.domain ; return () 
             | Some _ as token -> init ~token ())
        | `Error _ -> 
          display "> error while selecting over domain %s, waiting for 5 secs and retrying" L.domain ; 
          Lwt_unix.sleep 5.0 >>= init ~token

            
 (* to be removed *)

    let create_domain () = 
      SDB.create_domain creds L.domain >>= fun _ -> return ()
                        
  end

module Challenges = LFactory (Challenge)
module Solutions = LFactory (Solution)


(* bootstraping ****************************************************************************************)


let _ = 
  Lwt_main.run (Challenges.init ()) ;
  Lwt_main.run (Solutions.init ()) ; 
  Uid.unlock () 


(* s3 service *******************************************************************************************)

let s3_get_handler key _ = S3.get key

let _ = Eliom_output.Caml.register Services.Hidden.s3_get s3_get_handler


(* s3 helper client side ********************************************************************************)

{client{
  open Lwt 
  
  let fetch_from_s3 service key = 
    Eliom_client.call_caml_service ~service key () 

}}

(* we also need to expose a bunch of signatures *********************************************************)

(* you can consider the following lines as a super dirty hack .. *)

{client{

  module type LS = 
  sig
    type t
    type key = sdb_key
    type diff deriving (Json)
    
    val __name__ : string 
      
    val render_html5 :  (Types.s3_path -> string Lwt.t) -> t -> [ HTML5_types.div ] Eliom_pervasives.HTML5.M.elt Lwt.t 
    val update_form : (Types.s3_path -> string Lwt.t) -> t -> key ->
      (string, diff, [< Eliom_services.post_service_kind ],
       [< Eliom_services.suff ], 'd,
       [< string Eliom_parameters.setoneradio ]
         Eliom_parameters.param_name, [< Eliom_services.registrable ], 'e)
        Eliom_services.service -> [> HTML5_types.form ] Eliom_pervasives.HTML5.M.elt Lwt.t

    val uid : t -> key
    val build_diff : key -> diff Js.Opt.t
  end
  
  module LFactory (L : LS) = 
  struct
    
    exception Error
      
    type key = sdb_key
    type t = L.t 
    type diff = L.diff deriving (Json)


    let update_form = L.update_form
    let __name__ = L.__name__
    let render_html5 = L.render_html5
    let uid = L.uid
      
    let build_diff = L.build_diff
  end
    
 module Challenges = LFactory (Challenge)
 module Solutions = LFactory (Solution)


}}
