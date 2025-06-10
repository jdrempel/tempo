package src

import "base:runtime"
import os "core:os/os2"
import "core:log"


Parser :: struct {
  lex: ^Lexer,
  ally: runtime.Allocator,
  ast_root: [dynamic]Node,
}


Node :: struct {
  derived: Any_Node,
}


Any_Node :: union {
  ^Node_Text,
  ^Node_Output,
  ^Node_If,
  ^Node_For,
}


Node_Text :: struct {
  using node: Node,
  text: Token,
}


Node_Output :: struct {
  using node: Node,
  open: Token,
  expr: Token,
  close: Token,
}


Node_If :: struct {
  using node: Node,
  if_: Node_If_Component,
  elseifs: [dynamic]^Node_If_Component,
  else_: Maybe(^Node_If_Component),
  end: Node_End,
}


Node_If_Component :: struct {
  start: struct {
    open: Token,
    type: Token,
    expr: Maybe(Token),
    close: Token,
  },
  body: [dynamic]Node,
}


Node_For :: struct {
  using node: Node,
  start: struct {
    open: Token,
    for_: Token,
    expr: Token,
    close: Token,
  },
  body: [dynamic]Node,
  end: Node_End,
}


Node_End :: struct {
  open: Token,
  end: Token,
  close: Token,
}


parser_init_bytes :: proc(p: ^Parser, source: []byte, allocator := context.allocator) {
  lexer_init(p.lex, source)
  p.ally = allocator
  p.ast_root = make([dynamic]Node, allocator)
  log.debug("Done parser init")
}


parser_init_string :: proc(p: ^Parser, source: string, allocator := context.allocator) {
  parser_init_bytes(p, transmute([]byte)source)
}


parser_init :: proc {
  parser_init_bytes,
  parser_init_string,
}


parse :: proc(p: ^Parser) {
  parse_loop : for {
    log.debug("Top of parse loop")
    tok := lexer_next(p.lex)

    switch tok.type {
    case .Output_Open:
      if out, ok := parse_output(p, tok); ok {
        append(&p.ast_root, out)
      } else do break parse_loop
    case .Text:
      append(&p.ast_root, parse_text(p, tok))
    case .Process_Open:
      if out, ok := parse_process(p, tok); ok {
        append(&p.ast_root, out)
      } else do break parse_loop
    case .EOF:
      break parse_loop
    case .Illegal, .Output_Close, .Process_Close, .If, .For, .ElseIf, .Else, .EndIf, .EndFor:
      fallthrough
    case:
      panic("What did you do?")
    }
  }
}


parse_output :: proc(p: ^Parser, tok: Token) -> (n: ^Node_Output, ok: bool) {
  n = new(Node_Output, p.ally)
  n.derived = n
  n.open = tok
  n.expr = lexer_next(p.lex)

  if n.expr.type != .Text do return

  n.close = lexer_next(p.lex)
  if n.close.type != .Output_Close do return

  ok = true
  return
}


parse_text :: proc(p: ^Parser, tok: Token) -> ^Node_Text {
  n := new(Node_Text, p.ally)
  n.derived = n
  n.text = tok
  return n
}


parse_process :: proc(p: ^Parser, tok: Token, maybe_process_type: Maybe(Token) = nil) -> (n: Node, ok: bool) {
  process_type, type_ok := maybe_process_type.?
  if !type_ok {
    process_type = lexer_next(p.lex)
  }

  switch process_type.type {
  case .If:
    log.debug("parsing if")
    return parse_if(p, tok, process_type)
  case .For:
    log.debug("parsing for")
    return parse_for(p, tok, process_type)
  case .EndIf, .EndFor, .Process_Close, .Process_Open, .EOF, .Text, .Illegal, .Output_Close, .Output_Open, .Else, .ElseIf:
    fallthrough
  case:
    return
  }
  return
}


parse_if :: proc(p: ^Parser, tok: Token, process_type: Token) -> (n: ^Node_If, ok: bool) {
  assert(process_type.type == .If)
  log.info("assertion passed fine")
  tok, process_type := tok, process_type

  n = new(Node_If, p.ally)
  n.derived = n
  n.if_.body.allocator = p.ally
  n.elseifs.allocator = p.ally

  parse_if_component :: proc(p: ^Parser, if_comp: ^Node_If_Component, tok: Token, process_type: Token) -> (end_open: Token, end_type: Token, ok: bool) {
    if_comp.start.open = tok
    if_comp.start.type = process_type

    log.debug("inside parse_if_component")

    if process_type.type == .If || process_type.type == .ElseIf {
      expr := lexer_next(p.lex)
      if expr.type != .Text {
        log.warnf("Expected Text, got %v", expr.type)
        return
      }
      if_comp.start.expr = expr
    }
    log.debug("Done handling if component expr")

    if_comp.start.close = lexer_next(p.lex)
    if if_comp.start.close.type != .Process_Close {
      log.warnf("Expected Process_Close, got %v", if_comp.start.close.type)
      return
    }

    is_if_elseif_endif :: proc(t: Token) -> bool {
      return t.type == .Else || t.type == .ElseIf || t.type == .EndIf
    }

    is_else_endif :: proc(t: Token) -> bool {
      return t.type == .EndIf
    }

    select_proc := is_else_endif if if_comp.start.type.type == .Else else is_if_elseif_endif
    log.debug("about to parse if body")
    end_open, end_type = parse_body(p, &if_comp.body, select_proc) or_return
    ok = true
    log.infof("Done parse_if_component %#v\nand\n%#v", end_open, end_type)
    return
  }

  log.debug("about to parse first if component")
  tok, process_type = parse_if_component(p, &n.if_, tok, process_type) or_return
  log.debug("about to look at elseifs...")
  for process_type.type == .ElseIf {
    component := new(Node_If_Component, p.ally)
    component.body.allocator = p.ally
    tok, process_type = parse_if_component(p, component, tok, process_type) or_return
    append(&n.elseifs, component)
    log.info("Made it through the elseifs")
  }

  #partial switch process_type.type {
  case .Else:
    component := new(Node_If_Component, p.ally)
    component.body.allocator = p.ally
    tok, process_type = parse_if_component(p, component, tok, process_type) or_return
    n.else_ = component
    log.info("Got through the else")

  case .EndIf:
  case:
    log.warnf("Process type was %v at the end of parse_if", process_type.type)
    return
  }

  if process_type.type != .EndIf {
    log.warnf("Expected EndIf, got %v", process_type.type)
    return
  }

  n.end.open = tok
  n.end.end = process_type
  n.end.close = lexer_next(p.lex)
  if n.end.close.type != .Process_Close {
    log.warnf("Expected Process_Close, got %v", n.end.close.type)
    return
  }

  ok = true
    log.infof("Done parse_if %#v", n)
  return
}


parse_for :: proc(p: ^Parser, tok: Token, process_type: Token) -> (n: ^Node_For, ok: bool) {
  assert(process_type.type == .For)

  n = new(Node_For, p.ally)
  n.derived = n
  n.body.allocator = p.ally

  n.start.open = tok
  n.start.for_ = process_type

  n.start.expr = lexer_next(p.lex)
  if n.start.expr.type != .Text {
    log.warnf("Expected Text, got %v", n.start.expr.type)
    return
  }

  n.start.close = lexer_next(p.lex)
  if n.start.close.type != .Process_Close {
    log.warnf("Expected Process_Close, got %v", n.start.close.type)
    return
  }

  n.end.open, n.end.end = parse_body(p, &n.body, proc(t: Token) -> bool {return t.type == .EndFor}) or_return

  n.end.close = lexer_next(p.lex)
  if n.end.close.type != .Process_Close {
    log.warnf("Expected Process_Close, got %v", n.start.close.type)
    return
  }

  ok = true
  return
}


parse_body :: proc(p: ^Parser, container: ^[dynamic]Node, is_end: proc(t: Token) -> bool) -> (end_open: Token, end_process: Token, ok: bool) {
  for {
    tok := lexer_next(p.lex)
    log.debugf("body tok: %#v", tok)

    switch tok.type {
    case .Output_Open:
      log.debug("Output in body")
      append(container, parse_output(p, tok) or_return)
    
    case .Text:
      parsed_text := parse_text(p, tok)
      append(container, parsed_text)

    case .Process_Open:
      log.debug("Process in body")
      process_type := lexer_next(p.lex)
      if is_end(process_type) {
        end_open = tok
        end_process = process_type
        ok = true
        return
      }

      append(container, parse_process(p, tok, process_type) or_return)
    
    case .EOF:
      return

    case .Output_Close, .Process_Close, .Illegal, .If, .ElseIf, .Else, .EndIf, .For, .EndFor:
      fallthrough

    case:
      return
    }
  }
}
