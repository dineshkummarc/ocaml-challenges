open CalendarLib 
open Types 


type status = [ `Score of int | `Failed of (string * exn) | `Pending ]
 
type t = 
    {
      uid : sdb_key ; 
      
      author : string ;
      challenge_id : sdb_key ; 
      date : Date.t ; 
      
      content : s3_path ;

      status : status ; 
    }
