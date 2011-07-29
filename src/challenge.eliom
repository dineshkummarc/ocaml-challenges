{shared{

  open Lwt
  
  open HTML5.M
  open Eliom_output.Html5
  
  open Types
  
  let __name__ = "challenges" 
    
  type key = sdb_key
  type diff = string deriving (Json)
  type t = 
      {
        uid : sdb_key ; 

        author : string ;

        active : bool ; 
        submission_date : Date.t ; 

        title : string ; 
        description : s3_path ; 
        signature : string ; 
        difficulty : int ; (* 1 - 10 *)

        hints : s3_path list ; 
        tags : string list ; 

        sample_solution : s3_path ; 

        control_code : s3_path ;

        submitted_solutions : sdb_key list ;

        facebook_id : string ;
      } deriving (Json)
        
        
  let render_html5 get_s3 t = 

    let caml = img ~src:"/img/thumb_camel.png" ~alt:(Printf.sprintf "difficulty is %d" t.difficulty) () in 
    let rec gen_camels = function 
      | 0 -> []
      | n -> caml :: (gen_camels (n-1)) in

    return (div ~a:[ a_class [ "challenge_short" ]]
              [
                span ~a:[ a_class [ "challenge_short_title" ]] [ pcdata t.title ] ; 
                span ~a:[ a_class [ "challenge_short_author" ]] [ pcdata "by " ; pcdata t.author ] ; 
                div ~a:[ a_class [ "challenge_short_difficulty" ]] (gen_camels t.difficulty)  ;
                div ~a:[ a_class [ "clearall" ]] []; 
              ])


  let update_form _ key update_service =
    post_form update_service 
      (fun diff -> 
        [
          div [
            string_input ~input_type:`Text ~name:diff () 
          ]; 
          div [
            string_input ~input_type:`Submit ~value:"update" () 
          ]
        ]) key
      
  let uid t = 
    t.uid
      
}}


{client{
  let build_diff _ =
    alert "not implemented"; 
    Js.null
}}

open Misc

let cache_size = int_of_string (Config.get_param "cache_size")
let domain = Config.get_param "sdb_domain_challenges"

(* sdb functions *************************************************************************************)

let to_sdb t = 
  sdb_append "submitted_solutions" t.submitted_solutions
    (sdb_append "tags" t.tags 
       (sdb_append "hints" t.hints
          [
            "uid", t.uid ; 
            "author", t.author ;
            "active", string_of_bool t.active ; 
            "submission_date", Date.to_string t.submission_date ; 
            "title", t.title ;
            "description", t.description ; 
             "signature", t.signature ;
            "difficulty", string_of_int t.difficulty ; 
            "sample_solution", t.sample_solution ; 
            "control_code", t.control_code ;
            "facebook_id", t.facebook_id ; 
          ]))

let of_sdb l =
  {
    uid = fetch_string l "uid" ; 
    author = fetch_string l "author" ;
    active = fetch_bool l "active" ; 
    submission_date = fetch_date l "date" ; 
    
    title = fetch_string l "title" ; 
    description = fetch_string l "description" ; 
    signature = fetch_string l "signature"; 
    
    difficulty = fetch_int l "difficulty" ;
    
    hints = fetch_string_list l "hints" ; 
    tags = fetch_string_list l "tags" ; 
    
    sample_solution = fetch_string l "sample_solution" ; 
    
    control_code = fetch_string l "control_code" ; 
    
    submitted_solutions = fetch_string_list l "submitted_solutions" ; 
    
    facebook_id = fetch_string l "facebook_id" ;
  
}
