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

let load key = 
  Persistency.S3.load key 
  >>= fun s -> 
  Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info s 
  >>= fun block -> 
  return (s, block)

module Cache = Ocsigen_cache.Make (struct type key = string type value = string * (HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list) end)

let cache = new Cache.cache load (int_of_string (Config.get_param "cache_size"))

let set key value = 
  Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info value 
  >>= fun block -> cache # add key (key, block) ; return ()
  
let handler_get key _ = 
  cache # find key 
  >>= fun (_, block) -> Nutshell.home block

let _ = 
  Appl.register Services.Frontend.cms handler_get


(* backend logic **********************************************************************)

{shared{
  
  open Lwt
  open HTML5.M

  let __name__ = "cmspages" 
  
  type t = string * (HTML5_types.flow5 Eliom_pervasives.HTML5.M.elt list)

  let render_html5 _ (code, _ ) = 
    return 
      (div 
         [
           pcdata code
         ])
     
}}

{server{

  let list () = 
    cache # list ()

}}
