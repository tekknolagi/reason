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
