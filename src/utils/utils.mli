val is_some : 'a option -> bool ;;
val is_none : 'a option -> bool ;;
val elem_from_opt : 'a option -> 'a ;;
val queue_to_list : 'a Queue.t -> 'a list ;;
val get_absolute_path : string -> string;;
val convert_line_endings : string -> string;;