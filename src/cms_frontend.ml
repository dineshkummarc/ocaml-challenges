open Lwt
open Misc

let handler_get key _ = 
  Cms.cache # find key 
  >>= fun (_, _, block) -> Nutshell.home block

let _ = 
  Appl.register Services.Frontend.cms handler_get

 
