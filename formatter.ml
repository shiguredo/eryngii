open Core.Std
open Located

module Op = struct

  type desc =
    | Nop
    | Text of string
    | Comment of string
    | Space of int
    | Newline of int
    | Indent of int option ref
    | Dedent

  type t = {
    pos : int;
    desc : desc;
  }

  let create pos desc =
    { pos; desc }

  let of_loc loc desc =
    { pos = Location.offset loc; desc }

  let spaces pos len =
    create pos (Space len)

  let length op =
    match op.desc with
    | Nop
    | Dedent -> None

    | Text s
    | Comment s -> Some (String.length s)
    | Space n
    | Newline n -> Some n
    | Indent { contents = Some n } -> Some n

    | _ -> None

  let length_exn op =
    Option.value_exn (length op)

  let add_pos op len =
    { op with pos = op.pos + len }

  let add_pos_of op other =
    add_pos op @@ length_exn other

  let to_string op =
    let open Printf in
    match op.desc with
    | Nop -> "nop"
    | Text s -> sprintf "text(\"%s\")" s
    | Comment s -> sprintf "comment(\"%s\")" s
    | Space n -> sprintf "space(%d)" n
    | Newline n -> sprintf "newline(%d)" n
    | Indent { contents = None } -> "indent"
    | Indent { contents = Some n} -> sprintf "indent(%d)" n
    | Dedent -> "dedent"

end

module Context = struct

  type t = {
    file : File.t;
    mutable ops : Op.t list;
    mutable indent : int list;
    mutable count : int option;
  }

  let create file =
    { file;
      ops = [];
      indent = [0];
      count = None;
    }

  let contents ctx =
    List.rev ctx.ops

  let clear ctx =
    ctx.ops <- []

  let start_count ctx =
    match ctx.count with
    | Some _ -> failwith "already start count"
    | None -> ctx.count <- Some 0

  let end_count ctx =
    match ctx.count with
    | None -> failwith "not start count"
    | Some count ->
      ctx.count <- None;
      count

  let count ctx =
    Option.value_exn ctx.count

  let last_pos ctx =
    match List.hd ctx.ops with
    | None -> None
    | Some op -> Some op.pos

  let last_pos_exn ctx =
    Option.value_exn (last_pos ctx)

  let add ctx op =
    ctx.ops <- op :: ctx.ops

  let add_string ctx loc text =
    add ctx @@ Op.of_loc loc (Op.Text text)

  let add_text ctx text =
    add ctx @@ Op.of_loc text.loc (Op.Text text.desc)

  let add_comment ctx text =
    let len = String.length text.desc in
    let buf = Buffer.create (len+1) in
    let body = String.lstrip text.desc ~drop:(fun c -> c = '%') in
    let sign = String.make (len - String.length body) '%'  in
    let body = String.strip body in
    Buffer.add_string buf sign;
    Buffer.add_string buf " ";
    Buffer.add_string buf body;
    add ctx @@ Op.of_loc text.loc (Op.Comment (Buffer.contents buf))

  let add_space ctx loc n =
    add ctx @@ Op.of_loc loc (Space n)

  let add_newline ctx loc n =
    add ctx @@ Op.of_loc loc (Newline n)

  let add_indent ctx loc =
    add ctx @@ Op.of_loc loc (Indent (ref None))

  let cur_indent ctx =
    List.hd_exn ctx.indent

  let indent ctx =
    (*cur_indent ctx |> spaces ctx *)
    ()

  let dedent ctx =
    add ctx @@ Op.create (last_pos_exn ctx) Dedent

  let nest ?indent:size ctx =
    let size = (Option.value size ~default:4) + cur_indent ctx in
    ctx.indent <- size :: ctx.indent

  let unnest ctx =
    ctx.indent <- List.tl_exn ctx.indent

end

let parse_annots ctx =
  let open Context in

  List.iter (Annot.all ())
    ~f:(fun annot ->
        match annot with
        | Comment text -> add_comment ctx text
        (* TODO: count \r\n, \r, \n *)
        | Newline text -> add_newline ctx text.loc (String.length text.desc))

let rec parse ctx node =
  let open Ast_intf in
  let open Context in
  let open Located in
  let open Location in

  match node with
  | Module m ->
    List.iter m.module_decls ~f:(parse ctx)

  | Modname_attr attr ->
    add_text ctx attr.modname_attr_tag;
    add_string ctx attr.modname_attr_open "(";
    add_text ctx attr.modname_attr_name;
    add_string ctx attr.modname_attr_close ")";
    add_string ctx attr.modname_attr_dot "."

  | Export_attr attr ->
    add_text ctx attr.export_attr_tag;
    add_string ctx attr.export_attr_open "(";
    add_string ctx attr.export_attr_fun_open "[";
    parse_fun_sigs ctx attr.export_attr_funs;
    dedent ctx;
    add_string ctx attr.export_attr_fun_close "]";
    add_string ctx attr.export_attr_close ")";
    add_string ctx attr.export_attr_dot "."

  | Paren paren ->
    add_string ctx paren.enc_open "(";
    parse ctx paren.enc_desc;
    add_string ctx paren.enc_close ")"

  | Nop -> ()
  | _ -> ()

and parse_fun_sigs ctx fsigs =
  let open Context in
  let len = Seplist.length fsigs in
  Seplist.iter fsigs
    ~f:(fun sep fsig ->
        parse_fun_sig ctx fsig;
        Option.iter sep ~f:(fun sep ->
            add_string ctx sep ",";
            if len < 3 then
              add_space ctx sep 1
            else begin
              add_newline ctx sep 1;
              add_indent ctx sep;
            end))

and parse_fun_sig ctx fsig =
  let open Ast in
  let open Context in
  add_text ctx fsig.fun_sig_name;
  add_string ctx fsig.fun_sig_sep "/";
  add_text ctx fsig.fun_sig_arity

let sort ops =
  List.sort ops ~cmp:Op.(fun a b -> Int.compare a.pos b.pos)

    (*
let adjust_comments (ops:Op.t list) =
  List.fold_left ops
    ~init:[]
    ~f:(fun accu op ->
        match List.hd accu with
        | None -> op :: accu
        | Some (pre:Op.t) ->
          match op.desc with
          | Comment s ->
            begin match pre.desc with
              | Newline -> op :: accu
              | Indent _ ->
                let accu = op :: List.tl_exn accu in
                let space = Op.spaces op.pos 1 in
                let op = Op.add_pos op 1  in
                let pre = Op.add_pos_of pre op in
                pre :: op :: space :: List.tl_exn accu
              | _ ->
                let space = Op.spaces op.pos 1 in
                Op.add_pos_of op space :: space :: accu
            end
          | _ -> op :: accu)
  |> List.rev
     *)

let compact_newlines (ops:Op.t list) =
  List.fold_left ops
    ~init:(None, [])
    ~f:(fun (count, accu) op ->
        match (count, op.desc) with
        | None, Newline _ -> (Some 1, accu)
        | None, _ -> (None, op :: accu)
        | Some _, Newline _ -> (Some 2, accu)
        | Some n, _ ->
          let nl = Op.create op.pos (Newline n) in
          (None, nl :: op :: accu))
  |> snd
  |> List.rev

let compact_pos (ops:Op.t list) =
  let pos, ops = List.fold_left ops ~init:(0, [])
      ~f:(fun (pos, accu) op ->
          let op = { op with pos = pos } in
          let pos, op = match Op.length op with
            | None -> (pos, op)
            | Some len -> (pos + len, op)
          in
          (pos, op :: accu))
  in
  (pos, List.rev ops)

module Indent = struct

  type t = {
    ops : Op.t list
  }

  let length indent =
    List.fold_left indent
      ~init:0
      ~f:(fun accu op ->
          match Op.length op with
          | None -> accu
          | Some n -> accu + n)

end

(*
let count_indent (ops:Op.t list) =
  ()
 *)

let write len (ops:Op.t list) =
  let buf = String.make (len*2) ' ' in
  let replace pos s = 
    ignore @@ List.fold_left (String.to_list s)
      ~init:pos
      ~f:(fun pos c ->
          String.set buf pos c;
          pos + 1)
  in
  let replace_spaces pos len =
    replace pos (String.make len ' ')
  in

  List.iter ops
    ~f:(fun op ->
        match op.desc with
        | Text s
        | Comment s -> replace op.pos s
        | Newline n -> replace op.pos (String.make n '\n')
        | Space n -> replace_spaces op.pos n
        | Indent { contents = Some n } ->
          replace_spaces (op.pos + 1) n
        | Indent { contents = None } ->
          failwith "no indent size"
        | Dedent -> ()
        | _ -> failwith "not impl"
      );
  String.strip buf ^ "\n"

let format file node =
  let ctx = Context.create file in
  parse_annots ctx;
  parse ctx node;
  let len, ops =
    List.rev ctx.ops
    |> sort
    (*|> adjust_comments*)
    |> compact_newlines
    (*|> count_indent*)
    |> compact_pos
  in
  (*Printf.printf "[%s]\n" (String.concat (List.map ops ~f:Op.to_string) ~sep:", ");*)
  write len ops
