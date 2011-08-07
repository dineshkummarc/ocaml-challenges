open Lwt
open Misc

(* wikicreole transformation **********************************************************)

let dummy_box_info = 
  let open Wiki_widgets_interface in 
  {
    bi_subbox = (fun _ -> return None); 
    bi_ancestors = Ancestors.no_ancestors ;
    bi_box = Wiki_types.wikibox_of_sql 0l ;
    bi_wiki = Wiki_types.wiki_of_sql 0l ;
    bi_page = (Wiki_types.wiki_of_sql 0l, None) ; 
    bi_rights = Obj.magic () ; 
    bi_menu_style = `None ; 
  }

let render = Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info
  
let load key = 
  catch 
    (fun _ -> Persistency.S3.load key)
    (fun _ -> return "== This page does not exist ==")
  >>= fun s -> 
  Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info s 
  >>= fun block -> 
  return (key, s, block)

module Cache = Ocsigen_cache.Make (struct type key = string type value = string * string * (HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) end)

let cache = new Cache.cache load (int_of_string (Config.get_param "cache_size"))

exception InvalidWikiName

let set key value = 
  (try ignore (int_of_string key); raise InvalidWikiName with _ -> ()); 
  display "Storing key %s value %s" key value ; 
  Persistency.S3.store key value 
  >>= fun _ -> 
  Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info value 
  >>= fun block -> cache # add key (key, value, block) ; return ()
  
let get key = 
  cache # find key >>= fun (_, _, block) -> return block

(* backend logic **********************************************************************)

{shared{
  
  open Lwt
  open HTML5.M
  open Eliom_output.Html5

  open Types 

  let __name__ = "cmspages" 
  
  type key = sdb_key 

  type t = key * string * (HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list)

  type diff = string deriving (Json)

  let uid (k, _, _) = k

  let render_html5 _ (key, code, markup) = 
    return 
      (div 
         [
           h3 [ pcdata key ]; 
           div markup
         ])

 let update_form _ (key,code, _) key update_service =
   return 
     (post_form ~no_appl:true ~service:update_service 
      (fun diff -> 
        [
          div [
            textarea ~a:[a_id (key ^  "___markup") ] ~cols:80 ~rows:30 ~name:diff ~value:code () 
          ]; 
          div [
            string_input ~input_type:`Submit ~value:"update" () 
          ]
        ]) key)     
}}

{server{

  let list ?(all=true) () = 
    cache # list ()

  let update_diff key markup = 
    Persistency.S3.store key markup >>= fun _ ->
    Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info markup 
    >>= fun block -> cache # add key (key, markup, block) ; return (key, markup, block)

}}


{client{
  let build_diff key = 
    Js.Opt.bind
      (Js.Opt.bind
         (Dom_html.document ## getElementById (Js.string (key ^ "___markup")))
         (Dom_html.CoerceTo.textarea))
      (fun textarea -> Js.some (Js.to_string textarea ## value))
         
      
}}
