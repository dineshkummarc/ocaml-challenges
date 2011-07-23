{shared{
   type s3_path = string
   type sdb_key = string

   module Date = 
     struct
       
       type t = int * int * int * int * int * int

       let create a b c d e f = (a, b, c, d, e, f)
       let to_string (a, b, c, d, e, f) = Printf.sprintf "%d %d %d %d %d %d" a b c d e f 
       let of_string s = Scanf.sscanf s "%d %d %d %d %d %d" create

     end
}}
