open Ast ;;

exception InvalidVC of string ;;

(* Returns a new identifier with a its unique name.
   We make the name based on the id of the identifier.
   We use the var_names hash table to cache these names
   and their associated types. *)
let rename_and_replace_id ident var_names =
  let id = id_of_identifier ident in
  let new_name = 
    if (Hashtbl.mem var_names id) then
      fst (Hashtbl.find var_names id)
    else
      let new_var_name = "__" ^ (string_of_int id) ^ "_" ^ ident.name in
	Hashtbl.add var_names id (new_var_name, type_of_identifier ident);
	new_var_name
  in
    {name = new_name; location_id = ident.location_id; decl = ident.decl} ;;

(* Transforms an expr by renaming any identifiers in it. *)
let rec parse_expr e var_names =
  let rec pe = function
    | Assign (loc, lval, e) -> Assign (loc, pl lval, pe e)
    | Constant (loc, c) -> Constant (loc, c)
    | LValue (loc, lval) -> LValue (loc, pl lval)
    | Call (loc, s, el) -> Call (loc, s, List.map pe el)
    | Plus (loc, t1, t2) -> Plus (loc, pe t1, pe t2)
    | Minus (loc, t1, t2) -> Minus (loc, pe t1, pe t2)
    | Times (loc ,t1, t2) -> Times (loc, pe t1, pe t2)
    | Div (loc, t1, t2) -> Div (loc, pe t1, pe t2)
    | IDiv (loc, t1, t2) -> IDiv (loc, pe t1, pe t2)
    | Mod (loc, t1, t2) -> Mod (loc, pe t1, pe t2)
    | UMinus (loc, t) -> UMinus (loc, pe t)
    | LT (loc, t1, t2) -> LT (loc, pe t1, pe t2)
    | LE (loc, t1, t2) -> LE (loc, pe t1, pe t2)
    | GT (loc, t1, t2) -> GT (loc, pe t1, pe t2)
    | GE (loc, t1, t2) -> GE (loc, pe t1, pe t2)
    | EQ (loc, t1, t2) -> EQ (loc, pe t1, pe t2)
    | NE (loc, t1, t2) -> NE (loc, pe t1, pe t2)
    | And (loc, t1, t2) -> And (loc, pe t1, pe t2)
    | Or (loc, t1, t2) -> Or (loc, pe t1, pe t2)
    | Not (loc, t) -> Not (loc, pe t)
    | Length (loc, t) -> Length (loc, pe t)
    | Iff (loc, t1, t2) -> Iff (loc, pe t1, pe t2)
    | Implies (loc, t1, t2) -> Implies (loc, pe t1, pe t2)
    | EmptyExpr -> EmptyExpr
  and pl l = parse_lval l var_names
  in
    pe e

(* Transforms an lval by renaming any identifiers in it. *)
and parse_lval lval var_names = match lval with
  | NormLval (loc, id) -> NormLval (loc, rename_and_replace_id id var_names)
  | ArrayLval (loc, id, e) -> ArrayLval (loc, rename_and_replace_id id var_names, parse_expr e var_names) ;;

(* Convert our AST to be yices-readable. *)
let rec yices_string_of_expr e =
  let rec ysoe = function
    | Constant (loc, c) ->
	begin
	  match c with
	    | ConstInt (loc, i) -> string_of_int i
	    | ConstFloat (loc, f) -> string_of_float f
	    | ConstBool (loc, b) -> if b then "true" else "false"
	end
    | LValue (loc, lval) ->
	begin
	  match lval with
	    | NormLval (loc, ident) -> ident.name
	    | ArrayLval (loc, ident, e) -> "(" ^ ident.name ^ " " ^ (ysoe e) ^ ")"
	end
    | Plus (loc, t1, t2) -> "(+ " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Minus (loc, t1, t2) -> "(- " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Times (loc, t1, t2) -> "(* " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Div (loc, t1, t2) -> "(/ " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | IDiv (loc, t1, t2) -> "(div " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Mod (loc, t1, t2) -> "(mod " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | UMinus (loc, t) -> "(- " ^ (ysoe t) ^ ")"
    | LT (loc, t1, t2) -> "(< " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | LE (loc, t1, t2) -> "(<= " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | GT (loc, t1, t2) -> "(> " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | GE (loc, t1, t2) -> "(>= " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | EQ (loc, t1, t2) -> "(= " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | NE (loc, t1, t2) -> "(/= " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | And (loc, t1, t2) -> "(and " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Or (loc, t1, t2) -> "(or " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Not (loc, t) -> "(not " ^ (ysoe t) ^ ")"
    | Length (loc, t) -> raise (InvalidVC ("Length not yet implemented."))
	(* TODO: Implement.  Make a variable for each array to be its size?
	   But what if this is the length of say a function that returns an arr or 2d_arr[i]? *)
    | Iff (loc, t1, t2) -> "(= " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | Implies (loc, t1, t2) -> "(=> " ^ (ysoe t1) ^ " " ^ (ysoe t2) ^ ")"
    | _ -> raise (InvalidVC ("Unexpected expr type in VC: " ^ (string_of_expr e)))
  in
    ysoe e ;;

let rec yices_string_of_type t = match t with
  | Bool (loc) -> "bool"
  | Int (loc) -> "int"
  | Float (loc) -> "real"
  | Array (typ, l) -> "(-> int " ^ (yices_string_of_type typ) ^ ")"
  | _ -> raise (InvalidVC ("Unimplemented type: " ^ (string_of_type t))) (* TODO: Finish *)

let build_define_string id (name, t) cur_string =
  cur_string ^ "(define " ^ name ^ "::" ^ (yices_string_of_type t) ^ ")\n" ;;

let get_yices_string vc =
  
  (* First, find all vars and rename them. *)
  let var_names = Hashtbl.create 10 in
  let new_vc = Not (get_dummy_location (), parse_expr vc var_names) in
  let defines = Hashtbl.fold build_define_string var_names "" in
  let vc_string = yices_string_of_expr new_vc in
  defines ^ "(assert " ^ vc_string ^ ")\n(check)\n" ;;
