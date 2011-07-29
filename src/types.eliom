{shared{
   type s3_path = string deriving (Json)
   type sdb_key = string deriving (Json)

   module DateCommon = 
     struct
       
       type t = int * int * int * int * int * int deriving (Json)

       let create a b c d e f = (a, b, c, d, e, f)
       let to_string (a, b, c, d, e, f) = Printf.sprintf "%d %d %d %d %d %d" a b c d e f 
       let of_string s = Scanf.sscanf s "%d %d %d %d %d %d" create
         
     end
}}


{client{
   module Date = DateCommon
}}

{server{
   module Date = 
     struct 
       include DateCommon
       let now () = 
         let open Unix in 
             let tm = gmtime (gettimeofday ()) in 
             ((tm.tm_year + 1900), tm.tm_mon, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec)
     end
}}
