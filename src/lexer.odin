package src

import "core:log"


EOF :: 0


Token_Type :: enum {
  Illegal,
  EOF,
  Text,
  Output_Open,
  Output_Close,
  Process_Open,
  Process_Close,
  If,
  ElseIf,
  Else,
  EndIf,
  For,
  EndFor,
}


Token :: struct {
  type: Token_Type,
  value: string,
  pos: int,
}


Lexer :: struct {
  source: []byte,
  pos: int,
  char: byte,
  token_type: Token_Type,
  last_char: byte,
  last_token_type: Token_Type,
}


lexer_init :: proc(l: ^Lexer, source: []byte) {
  l.source = source
  l.pos = -1
  lexer_read(l)
  log.debug("Done lexer init")
}


lexer_read :: proc(l: ^Lexer) {
  l.pos += 1
  log.debugf("Pos: %d", l.pos)
  if l.pos >= len(l.source) {
    log.debug("Hit EOF")
    l.char = EOF
    return
  }
  l.last_char = l.char
  l.char = l.source[l.pos]
}


lexer_peek :: proc(l: ^Lexer, offset: int = 1) -> byte {
  if l.pos + offset >= len(l.source) {
    return EOF
  }
  return l.source[l.pos + offset]
}


lexer_consume :: proc(l: ^Lexer, val: string) -> string {
  for i in 0..<len(val) {
    assert(l.char == val[i])
    lexer_read(l)
  }
  return val
}


lexer_consume_until :: proc(l: ^Lexer, delims: ..string) -> string {
  start := l.pos
  for l.char != EOF {
    lexer_read(l)
    dlc: for delim in delims {
      for i in 0..<len(delim) {
        if delim[i] != lexer_peek(l, i) {
          continue dlc
        }
      }
    return string(l.source[start:l.pos])
    }
  }
  return string(l.source[start:])
}


lexer_skip_whitespace :: proc(l: ^Lexer) {
  for l.char != EOF {
    if l.char != ' ' do return
    lexer_read(l)
  }
}


lexer_next :: proc(l: ^Lexer) -> (t: Token) {
  t.pos = l.pos
  switch {
  case l.char == EOF:
    t.type = .EOF
  case l.char == '{' && lexer_peek(l) == '{':
    t.type = .Output_Open
    log.debug("Output open")
    lexer_consume(l, "{{")
  case l.char == '}' && lexer_peek(l) == '}':
    t.type = .Output_Close
    log.debug("Output close")
    lexer_consume(l, "}}")
  case l.char == '{' && lexer_peek(l) == '%':
    t.type = .Process_Open
    log.debug("Process open")
    lexer_consume(l, "{%")
    lexer_skip_whitespace(l)
  case l.char == '%' && lexer_peek(l) == '}':
    t.type = .Process_Close
    log.debug("Process close")
    lexer_consume(l, "%}")
  case l.last_token_type == .Process_Open:
    switch {
    case l.char == 'i' && lexer_peek(l) == 'f' && lexer_peek(l, 2) == ' ':
      t.type = .If
      t.value = lexer_consume(l, "if")

    case l.char == 'f' && lexer_peek(l) == 'o' && lexer_peek(l, 2) == 'r' && lexer_peek(l, 3) == ' ':
      t.type = .For
      t.value = lexer_consume(l, "for")

    case l.char == 'e' && lexer_peek(l) == 'l' && lexer_peek(l, 2) == 's' && lexer_peek(l, 3) == 'e':
      if lexer_peek(l, 4) == 'i' && lexer_peek(l, 5) == 'f' {
        t.type = .ElseIf
        t.value = lexer_consume(l, "elseif")
      } else {
        t.type = .Else
        t.value = lexer_consume(l, "else")
        lexer_skip_whitespace(l)
      }

    case l.char == 'e' && lexer_peek(l) == 'n' && lexer_peek(l, 2) == 'd':
      if lexer_peek(l, 3) == 'i' && lexer_peek(l, 4) == 'f' && lexer_peek(l, 5) == ' ' {
        t.type = .EndIf
        t.value = lexer_consume(l, "endif")
        lexer_skip_whitespace(l)
      } else if lexer_peek(l, 3) == 'f' && lexer_peek(l, 4) == 'o' && lexer_peek(l, 5) == 'r' && lexer_peek(l, 6) == ' ' {
        t.type = .EndFor
        t.value = lexer_consume(l, "endfor")
        lexer_skip_whitespace(l)
      } else {
        t.type = .Illegal
        t.value = lexer_consume_until(l, "%}")
      }
    }
  case:
    t.type = .Text
    log.debug("Text")
    t.value = lexer_consume_until(l, "{{", "}}", "{%", "%}")
    log.debugf("Value: %s", t.value)
  }
  l.last_token_type = t.type
  return
}
