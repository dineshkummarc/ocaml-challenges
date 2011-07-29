open Lwt

open HTML5.M  
open Eliom_output.Html5

open Misc

{client{

  (* activity stuff *)
  let init_activity activity_container bus view_challenge_service max_size = 
    Activity.widget activity_container bus view_challenge_service max_size 

}}

(* home related containers ***************************************************************)

let home content =
  let cv1 = Services.Frontend.challenge_view in
  let activity_container = unique (div []) in 
  let activity_max_size = 6 in
  let activity_init = List.fold_left (fun acc -> function None -> acc | Some v -> v :: acc) [] (RR.dump Activity.rr) in

lwt contribute = Cms.get "contribute" in
  Eliom_services.onload 
  {{
      init_activity 
      (Eliom_client.Html5.of_element %activity_container)
      %Activity.bus 
      %cv1
      %activity_max_size 
      %activity_init
          
  }} ; 
    html
       (head (title (pcdata "OCaml puzzles")) [
         link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/common.css") ();
         script ~a:[ a_mime_type "application/x-javascript"; a_src (uri_of_string "/runtime.js") ] (pcdata "") ;
         script ~a:[ a_mime_type "application/x-javascript"; a_src (uri_of_string "/challenges_oclosure.js") ] (pcdata "") ;
       ])
      (body [
        div ~a:[ a_id "wrap" ] 
          [ 
            div [
              HTML5.M.a ~a: [ a_target "blank" ; a_href (uri_of_string "https://github.com/baoug/ocaml-challenges") ;  a_id "github-link" ] [] ;
            ] ; 
            header [
              hgroup 
                (h1 [ pcdata "OCaml puzzles" ])
                [
                  h4 [ 
                    span ~a:[ a_id "hdlineL" ] [ pcdata "handcrafted by the" ] ; 
                span ~a:[ a_id "hdlineR" ] [ pcdata "Bay Area OCaml User Group" ] ; 
                  ] ; 
                ];
              nav [
                ul [
                  li [
                    a ~service:Services.Frontend.home [ pcdata "Home" ] ()
                  ];
                  li [
                    a ~service:Services.Frontend.challenge_new [ pcdata "Contribute a challenge" ] ()
                  ]; 
                  li [
                    a ~service:Services.Frontend.cms [ pcdata "About" ] "about"
                  ]
                ]
              ]
            ];
            div ~a:[ a_id "fb-root" ] [] ; 
            div ~a:[ a_id "container"] [
              div ~a:[ a_id "home_left" ] content ; 
                div ~a:[ a_id "home_right" ]
                [
                  img ~src:"/img/caml_race.jpg" ~alt:"caml race" () ; 
                  div ~a:[ a_id "out_activity_container" ] 
                    [
                      h3 [ pcdata "Recent activity" ] ;
                      activity_container ; 
                    ] ; 
                  div ~a:[ a_id "contribute" ] 
                   contribute
                     
                    
                ] ; 
              div ~a:[ a_class [ "clearall" ]] [] ; 
              
            ]
              

          ] ; 
        footer [
          div [
            pcdata "Initiated the 23th of July 2011 during the #0 OCaml Hackathon, in San Francisco, California"
          ] ; 
        ];
        
      ]
    ) >>> return 
