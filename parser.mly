%{

open Located

let create_binexp left op right =
  let open Located in
  match (left.loc, right.loc) with
  | (Some lloc, Some rloc) ->
    Located.with_range lloc rloc Ast.(Binexp {
        binexp_left = left;
        binexp_op = op;
        binexp_right = right })
  | _ -> failwith "not match"

let paren open_ value close =
  Located.with_range open_ close @@ Ast.Paren (Ast.enclose open_ value close)

%}

%token <Ast.text> UIDENT
%token <Ast.text> LIDENT
%token <Ast.text> CHAR
%token <Ast.text> STRING
%token <Ast.text> INT
%token <Ast.text> FLOAT
%token <Ast.token> LPAREN
%token <Ast.token> RPAREN
%token <Ast.token> LBRACK
%token <Ast.token> RBRACK
%token <Ast.token> LBRACE
%token <Ast.token> RBRACE
%token <Ast.token> COMMA
%token <Ast.token> DOT
%token <Ast.token> COLON
%token <Ast.token> SEMI
%token <Ast.token> USCORE           (* "_" *)
%token <Ast.token> NSIGN            (* "#" *)
%token <Ast.token> AND              (* "and" *)
%token <Ast.token> OR               (* "or" *)
%token <Ast.token> NOT              (* "not" *)
%token <Ast.token> LAND             (* "band" *)
%token <Ast.token> LOR              (* "bor" *)
%token <Ast.token> LXOR             (* "bxor" *)
%token <Ast.token> LNOT             (* "bnot" *)
%token <Ast.token> LSHIFT           (* "bsl" *)
%token <Ast.token> RSHIFT           (* "bsr" *)
%token <Ast.token> MATCH            (* "=" *)
%token <Ast.token> SEND             (* "!" *)
%token <Ast.token> BAR              (* "|" *)
%token <Ast.token> DBAR             (* "||" *)
%token <Ast.token> EQ
%token <Ast.token> NE
%token <Ast.token> XEQ
%token <Ast.token> XNE
%token <Ast.token> LT
%token <Ast.token> LE
%token <Ast.token> GT
%token <Ast.token> GE
%token <Ast.token> PLUS
%token <Ast.token> MINUS
%token <Ast.token> MUL              (* "*" *)
%token <Ast.token> DIV              (* "/" *)
%token <Ast.token> QUO              (* "div" *)
%token <Ast.token> REM              (* "rem" *)
%token <Ast.token> LIST_ADD         (* "++" *)
%token <Ast.token> LIST_DIFF        (* "--" *)
%token <Ast.token> RARROW           (* "->" *)
%token <Ast.token> LARROW           (* "<-" *)
%token <Ast.token> MODULE           (* "-module" *)
%token <Ast.token> EXPORT           (* "-export" *)
%token <Ast.token> BEGIN            (* "begin" *)
%token <Ast.token> END              (* "end" *)
%token <Ast.token> AFTER            (* "after" *)
%token <Ast.token> COND             (* "cond" *)
%token <Ast.token> LET              (* "let" *)
%token <Ast.token> WHEN             (* "when" *)
%token <Ast.token> OF               (* "of" *)
%token <Ast.token> CASE             (* "case" *)
%token <Ast.token> FUN              (* "fun" *)
%token <Ast.token> CATCH            (* "catch" *)
%token <Ast.token> IF               (* "if" *)
%token <Ast.token> RECEIVE          (* "receive" *)
%token <Ast.token> TRY              (* "try" *)
%token EOF

%start <Ast.t option> module_

%%

module_:
  | EOF { None }
  | module_decls { Some $1 }

module_decls:
  | module_attr+ EOF
  { less @@ Ast.Module {
      module_attrs = $1;
      module_decls = []; }
  }
  | module_attr+ fun_decl+ EOF
  { less @@ Ast.Module {
      module_attrs = $1;
      module_decls = $2; }
  }
  | fun_decl+ EOF
  { less @@ Ast.Module {
      module_attrs = [];
      module_decls = $1; }
  }

module_attr:
  | MINUS LIDENT LPAREN exp RPAREN DOT
  { (less @@ Ast.Module_attr {
      module_attr_minus = $1;
      module_attr_tag = $2;
      module_attr_open = $3;
      module_attr_value = $4;
      module_attr_close = $5; }, $6)
  }

fun_decl:
  | fun_clauses DOT
  { (less @@ Ast.Fun_decl $1, $2) }

fun_clauses:
  | fun_clause { Seplist.one $1 }
  | fun_clauses SEMI fun_clause { Seplist.cons $3 ~sep:$2 $1 }

fun_clause:
  | LIDENT fun_clause_def
  { { $2 with Ast.fun_clause_name = Some $1 } }

fun_clause_def:
  | LPAREN patterns_opt RPAREN RARROW body
  { Ast.({
      fun_clause_name = None;
      fun_clause_open = $1;
      fun_clause_ptns = $2;
      fun_clause_close = $3;
      fun_clause_when = None;
      fun_clause_guard = None;
      fun_clause_arrow = $4;
      fun_clause_body = $5 })
  }
  | LPAREN patterns_opt RPAREN WHEN guard RARROW body
  { Ast.({
      fun_clause_name = None;
      fun_clause_open = $1;
      fun_clause_ptns = $2;
      fun_clause_close = $3;
      fun_clause_when = Some $4;
      fun_clause_guard = Some $5;
      fun_clause_arrow = $6;
      fun_clause_body = $7 })
  }

guard:
  | rev_guard { Seplist.rev $1 }

rev_guard:
  | exp { Seplist.one $1 }
  | rev_guard COMMA exp { Seplist.cons $3 ~sep:$2 $1 }

body:
  | exps { $1 }

exps:
  | rev_exps { Seplist.rev $1 }

rev_exps:
  | exp { Seplist.one $1 }
  | rev_exps COMMA exp { Seplist.cons $3 ~sep:$2 $1 }

exps_opt:
  | exps { $1 }
  | (* empty *) { Seplist.empty }

exp:
  | CATCH exp { less @@ Ast.Catch ($1, $2) }
  | match_exp { $1 }

match_exp:
  | exp MATCH match_exp
  { create_binexp $1 (locate $2 Ast.Op_match) $3 }
  | send_exp { $1 }

send_exp:
  | compare_exp SEND send_exp
  { create_binexp $1 (locate $2 Ast.Op_send) $3 }
  | compare_exp { $1 }

compare_exp:
  | list_conc_exp compare_op list_conc_exp
  { create_binexp $1 $2 $3 }
  | list_conc_exp { $1 }

compare_op:
  | EQ { locate $1 Ast.Op_eq }
  | NE { locate $1 Ast.Op_ne }
  | XEQ { locate $1 Ast.Op_xeq }
  | XNE { locate $1 Ast.Op_xne }
  | GT { locate $1 Ast.Op_gt }
  | GE { locate $1 Ast.Op_ge }
  | LT { locate $1 Ast.Op_lt }
  | LE { locate $1 Ast.Op_le }

list_conc_exp:
  | shift_exp list_conc_op list_conc_exp { create_binexp $1 $2 $3 }
  | shift_exp { $1 }

list_conc_op:
  | LIST_ADD { locate $1 @@ Ast.Op_list_add }
  | LIST_DIFF { locate $1 @@ Ast.Op_list_diff }

shift_exp:
  | shift_exp shift_op mul_exp { create_binexp $1 $2 $3 }
  | mul_exp { $1 }

shift_op:
  | PLUS { locate $1 @@ Ast.Op_add }
  | MINUS { locate $1 @@ Ast.Op_sub }
  | LOR { locate $1 @@ Ast.Op_lor }
  | LXOR { locate $1 @@ Ast.Op_lxor }
  | LSHIFT { locate $1 @@ Ast.Op_lshift }
  | RSHIFT { locate $1 @@ Ast.Op_rshift }

mul_exp:
  | mul_exp mul_op prefix_exp { create_binexp $1 $2 $3 }
  | mul_exp AND prefix_exp
  { create_binexp $1 (locate $2 @@ Ast.Op_and) $3 }
  | prefix_exp { $1 }

mul_op:
  | MUL { locate $1 @@ Ast.Op_mul }
  | DIV { locate $1 @@ Ast.Op_div }
  | QUO { locate $1 @@ Ast.Op_quo }
  | REM { locate $1 @@ Ast.Op_rem }
  | LAND { locate $1 @@ Ast.Op_land }

prefix_exp:
  | prefix_op record_exp { less @@ Ast.Unexp ($1, $2) }
  | record_exp { $1 }

prefix_op:
  | PLUS { locate $1 @@ Ast.Op_pos }
  | MINUS { locate $1 @@ Ast.Op_neg }
  | NOT { locate $1 @@ Ast.Op_not }
  | LNOT { locate $1 @@ Ast.Op_lnot }

record_exp:
(*
  | record_exp_opt NSIGN record_type DOT record_field_name
    { Ast.RecordCreationexp ($1, $3, $5) }
  | record_exp_opt NSIGN record_type record_update_tuple
    { Ast.RecordAccessexp ($1, $3, $4) }
*)
  | call_exp { $1 }

record_field_name:
  | atom { $1 }

record_exp_opt:
  | record_exp { Some $1 }
  | (* empty *) { None }

record_update_tuple:
  | LBRACE record_field_updates_opt RBRACE { $2 }

record_field_updates_opt:
  | record_field_updates { $1 }
  | (* empty *) { [] }

record_field_updates:
  | record_field_update { [$1] }
  | record_field_updates COMMA record_field_update { $1 @ [$3] }

record_field_update:
  | record_field_name MATCH exp { Ast.Assoc ($1, $3) }

call_exp:
  | primary_exp LPAREN exps_opt RPAREN
  { less @@ Ast.Call {
      call_fname = Ast.simple_fun_name $1;
      call_open = $2;
      call_args = $3;
      call_close = $4; }
  }
  | primary_exp COLON primary_exp LPAREN exps_opt RPAREN
  { let fname = {
      Ast.fun_name_mname = Some $1;
      fun_name_colon = Some $2;
      fun_name_fname = $3; }
    in
    less @@ Ast.Call {
      call_fname = fname;
      call_open = $4;
      call_args = $5;
      call_close = $6; }
  }
  | primary_exp { $1 }

(* TODO *)
primary_exp:
  | var { $1 }
  | atomic { $1 }
  | tuple_skel { $1 }
  | list_skel { $1 }
  | list_compr { $1 }
  | if_exp { $1 }
  | case_exp { $1 }
  | receive_exp { $1 }
  | fun_exp { $1 }
  | try_exp { $1 }
  | LPAREN exp RPAREN { paren $1 $2 $3 }

var:
  | UIDENT { locate $1.loc (Ast.Var $1) }
  | USCORE { locate $1.loc Ast.Uscore }

atomic:
  | atom { $1 }
  | char { $1 }
  | string { locate $1.loc (Ast.String $1) }
  | integer { $1 }
  | float { $1 }

atom:
  | LIDENT { locate $1.loc (Ast.Atom $1) }

char:
  | CHAR { locate $1.loc (Ast.Char $1) }

string:
  | STRING { locate $1.loc (Ast.String $1) }

integer:
  | INT { locate $1.loc (Ast.Int $1) }

float:
  | FLOAT { locate $1.loc (Ast.Float $1) }

tuple_skel:
  | LBRACE exps_opt RBRACE
  { less Ast.(Tuple (enclose $1 $2 $3)) }

list_skel:
  | LBRACK RBRACK
  { less Ast.(List {
      list_open = $1;
      list_head = None;
      list_bar = None;
      list_tail = None;
      list_close = $2 })
  }
  | LBRACK exps RBRACK
  { less Ast.(List {
      list_open = $1;
      list_head = Some $2;
      list_bar = None;
      list_tail = None;
      list_close = $3 })
  }
  | LBRACK exps BAR exp RBRACK
  { less Ast.(List {
      list_open = $1;
      list_head = Some $2;
      list_bar = Some $3;
      list_tail = Some $4;
      list_close = $5 })
  }

list_compr:
  | LBRACK exp DBAR list_compr_quals RBRACK
  { less @@ Ast.List_compr {
      compr_open = $1;
      compr_exp = $2;
      compr_sep = $3;
      compr_quals = $4;
      compr_close = $5; }
  }

list_compr_quals:
  | rev_list_compr_quals { Seplist.rev $1 }

rev_list_compr_quals:
  | list_compr_qual { Seplist.one $1 }
  | rev_list_compr_quals COMMA list_compr_qual
  { Seplist.cons $3 ~sep:$2 $1 }

list_compr_qual:
  | list_compr_gen { $1 }
  | list_compr_filter { $1 }

list_compr_gen:
  | pattern LARROW exp
  { less @@ Ast.List_compr_gen {
      gen_ptn = $1;
      gen_arrow = $2;
      gen_exp = $3 }
  }

list_compr_filter:
  | exp { $1 }

block_exp:
  | BEGIN body END
  { less @@ Ast.(Block (enclose $2 $2 $3)) }

if_exp:
  | IF if_clauses END
  { less (Ast.If {
      if_begin = $1;
      if_clauses = $2;
      if_end = $3 })
  }

if_clauses:
  | rev_if_clauses { Seplist.rev $1 }

rev_if_clauses:
  | if_clause { Seplist.one $1 }
  | rev_if_clauses SEMI if_clause { Seplist.cons $3 ~sep:$2 $1 }

if_clause:
  | guard RARROW body
  { { Ast.if_clause_guard = $1;
        if_clause_arrow = $2;
        if_clause_body = $3; }
  }

case_exp:
  | CASE exp OF cr_clauses END
  { less (Ast.Case {
      case_begin = $1;
      case_exp = $2;
      case_of = $3;
      case_clauses = $4;
      case_end = $5; })
  }

cr_clauses:
  | rev_cr_clauses { Seplist.rev $1 }

rev_cr_clauses:
  | cr_clause { Seplist.one $1 }
  | rev_cr_clauses SEMI cr_clause { Seplist.cons $3 ~sep:$2 $1 }

cr_clause:
  | pattern RARROW body
  { { Ast.cr_clause_ptn = $1;
        Ast.cr_clause_when = None;
        Ast.cr_clause_guard = None;
        Ast.cr_clause_arrow = $2;
        Ast.cr_clause_body = $3; } }

  | pattern WHEN guard RARROW body
  { { Ast.cr_clause_ptn = $1;
        Ast.cr_clause_when = Some $2;
        Ast.cr_clause_guard = Some $3;
        Ast.cr_clause_arrow = $4;
        Ast.cr_clause_body = $5; } }

patterns:
  | rev_patterns { Seplist.rev $1 }

rev_patterns:
  | pattern { Seplist.one $1 }
  | patterns COMMA pattern { Seplist.cons $3 ~sep:$2 $1 }

patterns_opt:
  | patterns { $1 }
  | (* empty *) { Seplist.empty }

pattern:
  | exp { $1 }

receive_exp:
  | RECEIVE cr_clauses END
  { less @@ Ast.Recv {
      recv_begin = $1;
      recv_clauses = $2;
      recv_after = None;
      recv_end = $3; }
  }
  | RECEIVE AFTER exp RARROW body END
  { less @@ Ast.Recv {
      recv_begin = $1;
      recv_clauses = Seplist.empty;
      recv_after = Some {
        recv_after_begin = $2;
        recv_after_timer = $3;
        recv_after_arrow = $4;
        recv_after_body = $5;
      };
      recv_end = $6; }
  }
  | RECEIVE cr_clauses AFTER exp RARROW body END
  { less @@ Ast.Recv {
      recv_begin = $1;
      recv_clauses = $2;
      recv_after = Some {
        recv_after_begin = $3;
        recv_after_timer = $4;
        recv_after_arrow = $5;
        recv_after_body = $6;
      };
      recv_end = $7; }
  }

fun_exp:
  | FUN atom COLON atom_or_var DIV integer_or_var
  { less @@ Ast.Module_fun {
      module_fun_prefix = $1;
      module_fun_mname = Some $2;
      module_fun_colon = Some $3;
      module_fun_fname = $4;
      module_fun_slash = $5;
      module_fun_arity = $6; }
  }
  | FUN atom DIV INT
  { less @@ Ast.Module_fun {
      module_fun_prefix = $1;
      module_fun_mname = Some $2;
      module_fun_colon = None;
      module_fun_fname = None;
      module_fun_slash = $3;
      module_fun_arity = $4; }
  }
  | FUN fun_clauses END
  { less @@ Ast.Anon_fun {
      anon_fun_begin = $1;
      anon_fun_body = $2;
      anon_fun_end = $3; }
  }

atom_or_var:
  | atom { $1 }
  | var { $1 }

integer_or_var:
  | integer { $1 }
  | var { $1 }

try_exp:
  | TRY exps OF cr_clauses try_catch { Ast.nop }
  | TRY exps try_catch { Ast.nop }

try_catch:
  | CATCH try_clauses END
  { { Ast.try_catch_begin = Some $1;
        try_catch_clauses = Some $2;
        try_catch_after = None;
        try_catch_end = $3; }
  }
  | CATCH try_clauses AFTER exps END
  { { Ast.try_catch_begin = Some $1;
        try_catch_clauses = Some $2;
        try_catch_after = Some {
            try_catch_after_begin = $3;
            try_catch_after_exps = $4; };
        try_catch_end = $5; }
  }
  | AFTER exps END
  { { Ast.try_catch_begin = None;
        try_catch_clauses = None;
        try_catch_after = Some {
            try_catch_after_begin = $1;
            try_catch_after_exps = $2; };
        try_catch_end = $3; }
  }

try_clauses:
  | rev_try_clauses { Seplist.rev $1 }

rev_try_clauses:
  | try_clause { Seplist.one $1 }
  | rev_try_clauses SEMI try_clause
  { Seplist.cons $3 ~sep:$2 $1 }

try_clause:
  | exp guard body
  { { Ast.try_clause_exn = None;
        try_clause_exp = $1;
        try_clause_guard = $2;
        try_clause_body = $3; }
  }
  | atom_or_var COLON exp guard body
  { { Ast.try_clause_exn = Some ($1, $2);
        try_clause_exp = $3;
        try_clause_guard = $4;
        try_clause_body = $5; }
  }
