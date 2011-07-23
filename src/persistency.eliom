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
                 let attrs = List.fold_left
                   (fun acc -> 
                     function 
                     label, None -> acc 
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

      
    
  end

module Challenges = LFactory (Challenge)
module Solutions = LFactory (Solution)
