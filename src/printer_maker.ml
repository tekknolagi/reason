module type PRINTER =
    sig
        type t
        val parse : string option ->
        bool ->
        string ->
        ((t * Reason_pprint_ast.commentWithCategory) * bool)
        val makePrinter : string option ->
        string ->
        bool ->
        out_channel ->
        ((t * Reason_pprint_ast.commentWithCategory) -> unit)
    end

let ocamlBinaryParser use_stdin filename parsedAsInterface =
  let chan =
    match use_stdin with
      | true -> stdin
      | false ->
          let file_chan = open_in filename in
          seek_in file_chan 0;
          file_chan
  in
  let _ = really_input_string chan (String.length Config.ast_impl_magic_number) in
  let _ = input_value chan in
  let ast = input_value chan in
  ((ast, []), true, parsedAsInterface)

let reasonBinaryParser use_stdin filename =
  let chan =
    match use_stdin with
      | true -> stdin
      | false ->
          let file_chan = open_in filename in
          seek_in file_chan 0;
          file_chan
  in
  let (magic_number, filename, ast, comments, parsedAsML, parsedAsInterface) = input_value chan in
  ((ast, comments), parsedAsML, parsedAsInterface)
