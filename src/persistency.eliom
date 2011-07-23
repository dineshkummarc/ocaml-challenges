open Lwt
open Misc
open Types

let creds = 
  {
    Creds.aws_access_key_id = Config.get_param "aws_access_key_id" ;
    Creds.aws_secret_access_key = Config.get_param "aws_secret_access_key" ;
  }

module type LS = 
  sig
    type t 

    val cache_size : int
    val domain : string 

    val uid : t -> sdb_key
    val of_sdb : (string * string) list -> t
    val to_sdb : t -> (string * string) list
  end

module LFactory (L : LS) = 
  struct
    
    exception Error

    module C = Ocsigen_cache.Make (struct type key = sdb_key type value = L.t end)
            
    let load key = 
      SDB.get_attributes creds L.domain key
      >>= function 
        | `Ok l -> return (L.of_sdb l)
        | `Error _ -> fail Error

    let save value = 
      SDB.put_attributes creds L.domain (L.uid value) (L.to_sdb value)
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
          
    let rec init ?(token=None) () = 
      SDB.select creds ("select * from " ^ L.domain)
      >>= function 
        | `Ok (elements, token) -> 
          (List.iter
             (fun (name, attrs) -> 
               try 
                 (try Uid.tick (int_of_string name) with _ -> ()); 
                 let attrs = List.fold_left
                   (fun acc -> 
                     function 
                       | label, None -> acc 
                       | label, Some v -> (label, v) :: acc) [] attrs in
                 let value = L.of_sdb attrs in
                 let key = L.uid value in 
                 cache # add key value 
               with _ -> display "> discarding item %s from domain %s" name L.domain) elements ; 
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


(* s3 **************************************************************************************************)

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


module S3_cache = Ocsigen_cache.Make (struct type key = string type value = string end)

let s3_cache = new S3_cache.cache load (int_of_string (Config.get_param "cache-size"))

let get = s3_cache # find 
let set key value = 
  store key value
  >>= fun _ -> s3_cache # add key value ; return () 

(* bootstraping ****************************************************************************************)

(*
let _ = 
  Lwt_main.run (Challenges.init ()) ;
  Lwt_main.run (Solutions.init ()) ; 
  Uid.unlock () 
*)
