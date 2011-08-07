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
    s3_service t.content 
    >>= fun content -> 
    return (div ~a:[ a_class [ "challenge_short" ]]
              [
                h3 [ pcdata t.author ] ; 
                div [ pcdata content ] ; 
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
    true
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
    ("status.kind", Some "0") 
    :: ("status.score", Some (string_of_int score)) 
    :: acc
  | `Failed (msg, e) -> 
    ("status.kind", Some "1") 
    :: ("status.msg", Some msg) 
    :: ("status.exn", Some e)
    :: acc
  | `Pending -> 
    ("status.kind", Some "2") 
    :: acc

let status_of_sdb l =
  match int_of_string (assoc "status.kind" l) with 
      0 -> `Score (int_of_string (assoc "status.score" l))
    | 1 -> `Failed (assoc "status.msg" l, assoc "status.exn" l) 
    | 2 -> `Pending
    | _ -> raise BadType  
        

let to_sdb t = 
  status_to_sdb 
    [
      "uid", Some t.uid ;
      "author", Some t.author ; 
      "challenge_id", Some t.challenge_id ; 
      "date", Some (Date.to_string t.date) ; 
      "content", Some t.content ; 
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

