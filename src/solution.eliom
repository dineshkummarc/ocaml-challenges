open CalendarLib 
open Types 


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

let to_sdb t = 
  [
    "uid", t.uid ;
    "author", t.author ; 
    "challenge_id", t.challenge_id ; 
    "date", Printer.Date.to_string t.date ; 
    "content", t.content ; 
    "status", status_to_sdb t.status 
  ]

