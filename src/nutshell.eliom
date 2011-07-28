open Lwt

open HTML5.M  
open Eliom_output.Html5

open Misc

(* home related containers ***************************************************************)

let home content =
    html
       (head (title (pcdata "base")) [
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
                    a ~service:Services.Frontend.cms [ pcdata "About" ] "About"
                  ]
                ]
              ]
            ];
            div ~a:[ a_id "fb-root" ] [] ; 
            div ~a:[ a_id "container"] content
              

          ] ; 
        footer [
          div [
            pcdata "Initiated the 23th of July 2011 during the #0 OCaml Hackathon, in San Francisco, California"
          ] ; 
        ];
        
      ]
    ) >>> return 
