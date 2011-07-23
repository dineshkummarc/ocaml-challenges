open Lwt 
open Eliom_pervasives

open HTML5.M
open Eliom_output.Html5


let home_handler _ _ =
  let btn = unique (div ~a:[ a_id "btn" ] [ pcdata "click here" ]) in
  let box = unique (div ~a:[ a_id "box" ] [ pcdata "this is a google closure popup" ]) in
  
  Nutshell.home
    [ 
      h1 [ pcdata "hello world" ] ; 
      btn ; 
      box ;
    ]


(* service registration ******************************************************************)

let _ = 
  Appl.register Services.Backend.home home_handler
