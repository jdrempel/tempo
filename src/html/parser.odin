package html

import "base:runtime"
import "core:log"


HtmlParser :: struct {
  lex: ^Lexer,
  ally: runtime.Allocator,
  node_stream: [dynamic]^Node,
}


Node :: struct {
  derived: Any_Node,
}


Any_Node :: union {
  ^Node_Text,
  ^Node_Element,
  ^Node_Attr,
}


Node_Text :: struct {
  using node: Node,
  text: Token,
}


Node_Element :: struct {
  using node: Node,
  open: Token,
  name: Token,
  attrs: [dynamic]^Node_Attr,
  end: Maybe(Token),
  close: Token,
}


Node_Attr :: struct {
  using node: Node,
  key: Token,
  value: Maybe(Token),
}


parser_init_bytes :: proc(p: ^HtmlParser, source: []byte, allocator := context.allocator) {
  lexer_init(p.lex, source)
  p.ally = allocator
  p.node_stream = make([dynamic]^Node, allocator)
}


parser_init_string :: proc(p: ^HtmlParser, source: string, allocator := context.allocator) {
  parser_init_bytes(p, transmute([]byte)source)
}


parser_init :: proc {
  parser_init_bytes,
  parser_init_string,
}


parse :: proc(p: ^HtmlParser) {
  parse_loop : for {
    log.debug("At top of parse loop")
    tok := lexer_next(p.lex)

    switch tok.type {
    case .Tag_Start:
      log.debugf("Tag_Start")
      if out, ok := parse_tag(p, tok); ok {
        append(&p.node_stream, out)
      } else do break parse_loop

    case .Text:
      log.debugf("Text")
      append(&p.node_stream, parse_text(p, tok))

    case .EOF:
      log.debugf("EOF")
      break parse_loop

    case .Illegal, .Tag_End, .AttrVal, .AttrKey, .Element, .Element_End:
      log.debugf("%v", tok.type)
      fallthrough
    case:
      panic("What did you do?")
    }
  }
}


parse_tag :: proc(p: ^HtmlParser, tok: Token) -> (n: ^Node_Element, ok: bool) {
  n = new(Node_Element, p.ally)
  n.derived = n
  n.open = tok
  tok := lexer_next(p.lex)
  maybe_last_attr: Maybe(^Node_Attr) = nil
  for tok.type != .Tag_End {
    switch tok.type {
    case .Element_End:
      n.end = tok

    case .Element:
      n.name = tok

    case .AttrKey:
      if maybe_last_attr != nil && maybe_last_attr.?.value == nil {
        append(&n.attrs, maybe_last_attr.?)
        log.debugf("Name-Only Attr: %s", maybe_last_attr.?.key.value)
        maybe_last_attr = nil
      }
      maybe_last_attr = new(Node_Attr)
      maybe_last_attr.?.derived = maybe_last_attr.?
      maybe_last_attr.?.key = tok

    case .AttrVal:
      assert(maybe_last_attr != nil)
      last_attr := maybe_last_attr.?
      last_attr.value = tok
      append(&n.attrs, last_attr)
      log.debugf("Attr: %s='%s'", last_attr.key.value, last_attr.value.?.value)
      last_attr = nil

    case .Tag_End, .Illegal, .Text, .Tag_Start, .EOF:
      fallthrough

    case:
      return  // TODO errors
    }
    tok = lexer_next(p.lex)
  }
  n.close = tok
  ok = true
  return
}


parse_text :: proc(p: ^HtmlParser, tok: Token) -> (n: ^Node_Text) {
  n = new(Node_Text)
  n.derived = n
  n.text = tok
  log.debugf("Text node: %s", n.text.value)
  return
}
