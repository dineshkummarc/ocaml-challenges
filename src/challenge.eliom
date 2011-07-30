{shared{

  open Lwt
  
  open HTML5.M
  open Eliom_output.Html5
  
  open Types
  
  let __name__ = "challenges" 
    
  type key = sdb_key

  type diff =
      {
        d_author : string ; 
        d_active : bool ; 
        d_title : string ; 
        d_description : string ; 
        d_signature : string ; 
        d_difficulty : int ; 
        d_hints : string list ; 
        d_tags : string list ; 
        d_sample_solution : string ; 
        d_control_code : string ; 
      } deriving (Json)
  
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
      | n -> (caml :: (gen_camels (n-1)))
    in

    return 
      (div ~a:[ a_class [ "challenge_short" ]]
         [
           span ~a:[ a_class [ "challenge_short_title" ]] [ pcdata t.title ] ; 
           span ~a:[ a_class [ "challenge_short_author" ]] [ pcdata "by " ; pcdata t.author ] ; 
           div ~a:[ a_class [ "challenge_short_difficulty" ]] (gen_camels t.difficulty)  ;
           div ~a:[ a_class [ "clearall" ]] []; 
         ])
  

  let update_form s3get v key update_service =
    
    let string_field field value =
      tr [
        td [ label ~a:[ a_for (key ^ "__" ^ field) ] [ pcdata field ] ; ];
        td [ string_input ~a:[ a_id (key ^ "__" ^ field) ] ~value ~input_type:`Text ()  ];
      ] in

    let int_field field value =
      tr [
        td [ label ~a:[ a_for (key ^ "__" ^ field) ] [ pcdata field ] ; ];
        td [ int_input ~a:[ a_id (key ^ "__" ^ field) ] ~value ~input_type:`Text () ];
      ] in

    let textarea_field field value =
      tr [
        td [label ~a:[ a_for (key ^ "__" ^ field) ] [ pcdata field ] ;];
        td [raw_textarea ~name:"blob" ~rows:30 ~cols:60 ~value ~a:[ a_id (key ^ "__" ^ field) ] ()]
      ] in

    let bool_field field checked =
      tr [
        td [label ~a:[ a_for (key ^ "__" ^ field) ] [ pcdata field ] ;];
        td [raw_checkbox ~a:[ a_id (key ^ "__" ^ field) ] ~name: "bloby" ~checked ~value:"" () ]
      ] in
        
    s3get v.description 
    >>= fun description -> 
    s3get v.control_code 
    >>= fun control_code -> 
    s3get v.sample_solution
    >>= fun sample_solution-> 
    
    return 
      (
        post_form update_service 
          (fun _ -> 
            [
              table ~a:([a_class ["backend_table"]]) (string_field "author" v.author) [
                bool_field "active" v.active ;
                string_field "title" v.title ; 
                string_field "signature" v.signature ; 
                int_field "difficulty" v.difficulty ; 
                textarea_field "description" description ; 
                textarea_field "control_code" control_code ; 
                textarea_field "sample_solution" sample_solution ;
                tr [ td ~a:([a_colspan 2])[ string_input ~input_type:`Submit ~value:"update" ()  ]]
              ]
            ]) key)
      
  let uid t = 
    t.uid
      
  let visible t = 
    t.active
}}

let update_diff s3_store value diff =
  s3_store diff.d_description 
  >>= fun description -> 
  s3_store diff.d_sample_solution 
  >>= fun sample_solution ->
  s3_store diff.d_control_code 
  >>= fun control_code -> 
  return 
    {
      value with
        author = diff.d_author ;
        difficulty= diff.d_difficulty ;
        active = diff.d_active ; 
        title = diff.d_title ; 
        description ; 
        sample_solution ; 
        control_code ;
    }

{client{
  open Misc

  let build_diff key =    
    let gid field = Dom_html.document ## getElementById (Js.string (key ^ "__" ^ field)) in
    
    Js.Opt.bind 
      (Js.Opt.bind 
         (gid "author")
         (Dom_html.CoerceTo.input))
      (fun author -> 
        Js.Opt.bind 
          (Js.Opt.bind 
             (gid "active")
             (Dom_html.CoerceTo.input))
          (fun active -> 
            Js.Opt.bind 
              (Js.Opt.bind 
                 (gid "title")
                 (Dom_html.CoerceTo.input))
              (fun title -> 
                Js.Opt.bind 
                  (Js.Opt.bind 
                     (gid "description")
                     (Dom_html.CoerceTo.textarea))
                  (fun description -> 
                    Js.Opt.bind 
                      (Js.Opt.bind 
                         (gid "signature")
                         (Dom_html.CoerceTo.input))
                      (fun signature -> 
                        Js.Opt.bind 
                          (Js.Opt.bind 
                             (gid "difficulty")
                             (Dom_html.CoerceTo.input))
                          (fun difficulty -> 
                            Js.Opt.bind 
                              (Js.Opt.bind 
                                 (gid "control_code")
                                 (Dom_html.CoerceTo.textarea))
                              (fun control_code -> 
                                Js.Opt.bind 
                                  (Js.Opt.bind 
                                     (gid "sample_solution")
                                     (Dom_html.CoerceTo.textarea))
                                  (fun sample_solution -> 
                                    let diff = 
                                      {
                                        d_author = Js.to_string author ## value ; 
                                        d_active = Js.to_bool active ## checked  ; 
                                        d_title = Js.to_string title ## value ; 
                                        d_description = Js.to_string description ## value ; 
                                        d_signature = Js.to_string signature ## value ; 
                                        d_difficulty = int_of_string (Js.to_string difficulty ## value) ; 
                                        d_hints = [] ; 
                                        d_tags = [] ; 
                                        d_sample_solution = Js.to_string sample_solution ## value ; 
                                        d_control_code = Js.to_string control_code ## value ;
                                      } in 
                                    Js.some diff 
                                  )
                              )
                          )
                      )
                  )
              )
          )
      )


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
    submission_date = fetch_date l "submission_date" ; 
    
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
