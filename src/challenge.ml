open CalendarLib 
open Types

type t = 
    {
      uid : sdb_key ; 
      
      author : string ;

      active : bool ; 
      submission_date : Date.t ; 

      title : string ; 
      description : s3_path ; 
      difficulty : int ; (* 1 - 10 *)
      
      hints : s3_path list ; 
      tags : string list ; 
      
      sample_solution : s3_path ; 

      control_code : s3_path ; 
      
      submitted_solutions : sdb_key list ; 
      
      facebook_id : string ;
    }


