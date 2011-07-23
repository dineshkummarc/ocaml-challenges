{shared{

open Lwt

open HTML5.M
open Eliom_output.Html5

open Types

let __name__ = "challenges" 

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
    }

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

let uid t = 
  t.uid

{client{

  let new_challenge_form (author ,(title ,(description, (difficulty, hints)))) =
    [
      int_input ~input_type:`Hidden ~value:0 ~name:difficulty () ;
      div [
        label ~a:([a_for "title_challenge"]) [ pcdata "Title:" ];
        string_input ~a:([a_id "title_challenge"; a_required `Required]) ~input_type:`Text ~name:title () ;
      ];
      div [
        label ~a:([a_for "author_challenge"]) [ pcdata "Author:" ];
        string_input ~a:([a_id "author_challenge"; a_required `Required]) ~input_type:`Text ~name:author () ;
      ];
      div [
        label ~a:([a_for "desc_challenge"]) [ pcdata "Describe your problem:" ];
        textarea ~a:([ a_id "desc_challenge"; a_required `Required]) ~rows:10 ~cols:50 ~name:description () ;
      ];
      div [
        label ~a:([a_for "hints_challenge"]) [ pcdata "Some hints" ];
        string_input ~a:([ a_id "hints_challenge"]) ~input_type:`Text ~name:hints () ;
      ];
      raw_input ~input_type:`Submit ~value:"submit" ()
    ]
      
  let init container service =
    let form = post_form ~service new_challenge_form () in
    Dom.appendChild container (Eliom_client.Html5.of_element form)
}}

let new_handler _ _ =
  let c = unique (div []) in

  Eliom_services.onload  {{
    init (Eliom_client.Html5.of_element %c) %Services.Frontend.challenge_new_post
  }} ;

  Nutshell.home [ c ]

let _ = 
  Appl.register Services.Frontend.challenge_new new_handler
