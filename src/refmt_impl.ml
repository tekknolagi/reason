(* Portions Copyright (c) 2015-present, Facebook, Inc. All rights reserved. *)

open Lexing
open Reason_interface_printer
open Reason_implementation_printer

exception Invalid_config of string


let default_print_width = 100


let usage = {|Reason: Meta Language Utility

[Usage]: refmt [options] some-file.[re|ml|rei|mli]

   // translate ocaml to reason on stdin
   echo 'let _ = ()' | refmt --print re --parse ml

   // print the AST of a file
   refmt --parse re --print ast some-file.re

   // reformat a file
   refmt --parse re --print re some-file.re

[Options]:
|}

(*
 * As soon as m17n vends comments, this should be replaced with what is
 * effectively m17n's parser.
 *)
let () =
  let filename = ref "" in
  let prnt = ref None in
  let prse = ref None in
  let intf = ref None in
  let recoverable = ref false in
  let assumeExplicitArity = ref false in
  let heuristics_file = ref None in
  let print_width = ref None in
  let output_file = ref None in
  let writing_to_file = ref false in
  let print_help = ref false in
  let options = [
    "-is-interface-pp", Arg.Bool (fun x -> prerr_endline "-is-interface-pp is deprecated; use -i or --interface instead"; intf := Some x), "";
    "--is-interface-pp", Arg.Bool (fun x -> prerr_endline "--is-interface-pp is deprecated; use -i or --interface instead"; intf := Some x), "";
    "--interface", Arg.Bool (fun x -> intf := Some x), "<interface>, -i <interface>; parse AST as an interface (either true or false; default false)";
    "-i", Arg.Bool (fun x -> intf := Some x), "<interface>, --interface <interface>; parse AST as an interface (either true or false; default false)";
    "-use-stdin", Arg.Bool (fun x -> prerr_endline "-use-stdin is deprecated; usage is assumed if not specifying a filename"), "";
    "--use-stdin", Arg.Bool (fun x -> prerr_endline "--use-stdin is deprecated; usage is assumed if not specifying a filename"), "";
    "-recoverable", Arg.Bool (fun x -> prerr_endline "-recoverable is deprecated; use --recoverable instead"; recoverable := x), "";
    "--recoverable", Arg.Bool (fun x -> recoverable := x), "<recoverable>; enable or disable recoverable parser (either true or false; default false)";
    "-assume-explicit-arity", Arg.Unit (fun () -> prerr_endline "-assume-explicit-arity is deprecated; use --assume-explicit-arity instead" ; assumeExplicitArity := true), "";
    "--assume-explicit-arity", Arg.Unit (fun () -> assumeExplicitArity := true), "If a constructor's argument is a tuple, always interpret it as multiple arguments";
    "-parse", Arg.String (fun x -> prerr_endline "-parse is deprecated; use --parse instead"; prse := Some x), "";
    "--parse", Arg.String (fun x -> prse := Some x), "<parse>, parse AST as <parse> (either 'ml', 're', 'binary_reason(for interchange between Reason versions)', 'binary (from the ocaml compiler)')";
    (* Use a print option of "none" to simply perform a parsing validation -
     * useful for IDE error messages etc.*)
    "-print", Arg.String (fun x -> prerr_endline "-print is deprecated; use --print instead"; prnt := Some x), "";
    "--print", Arg.String (fun x -> prnt := Some x), "<print>, print AST in <print> (either 'ml', 're', 'binary(default - for compiler input)', 'binary_reason(for interchange between Reason versions)', 'ast (print human readable directly)', 'none')";
    "-print-width", Arg.Int (fun x -> prerr_endline "-print-width is deprecated; use --print-width instead"; print_width := Some x), "";
    "--print-width", Arg.Int (fun x -> print_width := Some x), "<print-width>, wrapping width for printing the AST";
    "-heuristics-file", Arg.String (fun x -> prerr_endline "-heuristics-file is deprecated; use --heuristics-file instead"; heuristics_file := Some x), "";
    "--heuristics-file", Arg.String (fun x -> heuristics_file := Some x),
    "<path>, load path as a heuristics file to specify which constructors are defined with multi-arguments. Mostly used in removing [@implicit_arity] introduced from OCaml conversion.\n\t\texample.txt:\n\t\tConstructor1\n\t\tConstructor2";
    "-o", Arg.String (fun x -> output_file := Some x; writing_to_file := true), "<output-file>, output file for printing";
    "-h", Arg.Unit (fun () -> print_help := true), " Display this list of options";
  ] in
  let () = Arg.parse options (fun arg -> filename := arg) usage in
  let print_help = !print_help in
  let filename = !filename in
  let use_stdin = (filename = "") in
  let () =
    let has_print = match !prnt with
      | None -> false
      | Some x -> true
    in
    let has_parse = match !prse with
      | None -> false
      | Some x -> true
    in

    if (filename = "" && not (has_parse && has_print)) || print_help then
      let () = Arg.usage options usage in
        exit 1;
  in
  let print_width = match !print_width with
    | None -> default_print_width
    | Some x -> x
  in
  let constructorLists = match !heuristics_file with
    | None -> []
    | Some file ->
      let list = ref [] in
      let chan = open_in file in
      try
        while true; do
          list := input_line chan :: !list
        done; []
      with End_of_file ->
        close_in chan;
        List.rev !list
  in
  let _ = if !recoverable then
    Reason_config.configure ~r:true
  in
  Location.input_name := filename;
  let intf = match !intf with
    | None when (Filename.check_suffix filename ".rei" || Filename.check_suffix filename ".mli") -> true
    | None -> false
    | Some b -> b
  in
  let (module Printer : Printer_maker.PRINTER) =
    if intf then (module Reason_interface_printer)
    else (module Reason_implementation_printer)
  in
  let _ = Reason_pprint_ast.configure
      ~width: print_width
      ~assumeExplicitArity: !assumeExplicitArity
      ~constructorLists
  in
  try
    let (ast, parsedAsML) = Printer.parse !prse use_stdin filename in
    (* As it turns out, calling formatter_of_out_channel on stdout results in
       missing output. So we don't do that. *)
    let (output_chan, output_formatter) =
        match !output_file with
        | Some name ->
                let ochan = open_out name in
                (ochan, Format.formatter_of_out_channel ochan)
        | None -> (stdout, Format.std_formatter)
    in
    let thePrinter = Printer.makePrinter !prnt filename parsedAsML output_chan output_formatter in
    let () = thePrinter ast in
    match !output_file with
    | Some _ -> close_out output_chan
    | None -> ()
  with
  | exn ->
    Location.report_exception Format.err_formatter exn;
    exit 1
