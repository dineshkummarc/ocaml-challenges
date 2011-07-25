open Lwt

open HTML5.M  
open Eliom_output.Html5

open Misc

(* home related containers ***************************************************************)

let home content =
    html
       (head (title (pcdata "base")) [

          link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/common.css") ();
          (*
          
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/common.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/button.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/dialog.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/linkbutton.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/menu.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/menuitem.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/menuseparator.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/tab.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/tabbar.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/toolbar.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/colormenubutton.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/palette.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/colorpalette.css") () ;
          
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/editor/bubble.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/editor/dialog.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/editor/linkdialog.css") () ;
           link ~rel:[ `Stylesheet ] ~href:(uri_of_string "/closure-library/closure/goog/css/editortoolbar.css") () ;
          *)
           script ~a:[ a_mime_type "application/x-javascript"; a_src (uri_of_string "/runtime.js") ] (pcdata "") ;
           script ~a:[ a_mime_type "application/x-javascript"; a_src (uri_of_string "/challenges_oclosure.js") ] (pcdata "") ;

      ])
      (body [
        header [
          hgroup (h1 [ pcdata "OCaml puzzles" ]) [
            h4 [ pcdata "handcrafted by the Bay Area OCaml Users Group" ]
          ];
          nav [
            ul [
              li [
                a ~service:Services.Frontend.home [ pcdata "home" ] ()
              ];
              li [
                a ~service:Services.Frontend.challenge_new [ pcdata "New challenge" ] ()
              ]
            ]
          ]
        ];
        div ~a:[ a_id "container"] content;
        footer [
          span [ pcdata "This is the Footer" ]
        ];
        div ~a:[ a_id "fb-root" ] []
      ]
    ) >>> return 
