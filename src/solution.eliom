open CalendarLib 
open Misc
open Types 


let cache_size = int_of_string (Config.get_param "cache_size")
let domain = Config.get_param "sdb_domain_solutions"

exception BadType

type status = [ `Score of int | `Failed of (string * string) | `Pending ]
 
type t = 
    {
      uid : sdb_key ; 
      
      author : string ;
      challenge_id : sdb_key ; 
      date : Date.t ; 
      
      content : s3_path ;
      
      
      status : status ; 
      
      
      
    }


(* sdb functions *************************************************************************************)

let status_to_sdb acc = function 
  | `Score score -> 
    ("status.kind", "0") 
    :: ("status.score", string_of_int score) 
    :: acc
  | `Failed (msg, e) -> 
    ("status.kind", "1") 
    :: ("status.msg", msg) 
    :: ("status.exn", e)
    :: acc
  | `Pending -> 
    ("status.kind", "2") 
    :: acc

let status_of_sdb l =
  match int_of_string (List.assoc "status.kind" l) with 
      0 -> `Score (int_of_string (List.assoc "status.score" l))
    | 1 -> `Failed (List.assoc "status.msg" l, List.assoc "status.exn" l) 
    | 2 -> `Pending
    | _ -> raise BadType  
        

let to_sdb t = 
  status_to_sdb 
    [
      "uid", t.uid ;
      "author", t.author ; 
      "challenge_id", t.challenge_id ; 
      "date", Printer.Date.to_string t.date ; 
      "content", t.content ; 
    ] t.status


let of_sdb l = 
  {
    uid =  fetch_string l "uid" ; 
    author = fetch_string l "author"; 
    challenge_id = fetch_string l "challenge_id" ; 
    date = fetch_date l "date" ;
    content = fetch_string l "content" ; 
    status = status_of_sdb l
  }


let uid t = 
  t.uid
    
