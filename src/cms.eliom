open Lwt
open Misc

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

let get key = 
  Persistency.S3.get key 
  >>= fun s -> 
  Wiki_syntax.xml_of_wiki Wiki_syntax.wikicreole_parser dummy_box_info s 
  >>= fun r -> return r

open HTML5.M

let handler_get key _ = 
  get key
  >>= Nutshell.home

let _ = 
  Appl.register Services.Frontend.cms handler_get
