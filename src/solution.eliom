{shared{

  open Lwt
  
  open HTML5.M
  open Eliom_output.Html5
  
  open Types

  let __name__ = "solutions" 

  type status = [ `Score of int | `Failed of (string * string) | `Pending ] deriving (Json)

      
  type key = sdb_key
  type diff = string deriving (Json)

  type t = 
      {
        uid : sdb_key ; 
        
        author : string ;
        challenge_id : sdb_key ; 
        date : Date.t ; 
        
        content : s3_path ;
        
        status : status ; 
      } deriving (Json)


  let render_html5 s3_service t = 
    return (div
              [
                h3 [ pcdata t.author ]
              ])

  let update_form _ _ key update_service =
    return 
      (post_form update_service 
         (fun diff -> 
           [
             div [
               string_input ~input_type:`Text ~name:diff () 
             ]; 
             div [
               string_input ~input_type:`Submit ~value:"update" () 
             ]
           ]) key)
      
  let uid t = 
    t.uid

      
  let visible t = 
    false
}}

{client{
  let build_diff _ = 
    alert "not implemented" ;
    Js.null
}}



let update_diff _ value diff =
  return value

open Misc

let cache_size = int_of_string (Config.get_param "cache_size")
let domain = Config.get_param "sdb_domain_solutions"

exception BadType

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
      "date", Date.to_string t.date ; 
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

