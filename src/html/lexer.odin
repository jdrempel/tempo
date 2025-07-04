package html

import "core:fmt"
import "core:log"


EOF :: 0


Pos :: int


Token_Type :: enum {
  Illegal,
  EOF,
  Tag_Start,    // <div id="foo"> -> <
  Tag_End,      // <div id="foo"> -> >
  Element,      // <div id="foo"> -> div
  Element_End,  // </div> -> /  OR  <br /> -> /
  AttrKey,      // <div id="foo"> -> id
  AttrVal,      // <div id="foo"> -> foo
  Text,         // <div>Hello!</div> -> Hello!
}


Token :: struct {
  type: Token_Type,
  value: string,
  pos: Pos,
  leading_fluff: string,
  trailing_fluff: string,
}


Lexer :: struct {
  source: []byte,
  pos: Pos,
  char: byte,
  last_token_type: Token_Type,
}


lexer_init :: proc(l: ^Lexer, source: []byte) {
  l.source = source
  l.pos = -1
  lexer_read(l)
  log.debug("Done lexer init")
}


lexer_destroy :: proc(l: ^Lexer) {
  free(l)
}


lexer_read :: proc(l: ^Lexer) {
  l.pos += 1
  if l.pos >= len(l.source) {
    l.char = EOF
    return
  }
  l.char = l.source[l.pos]
}


lexer_peek :: proc(l: ^Lexer, offset: Pos = 1) -> byte {
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


char_is_whitespace :: proc(c: byte) -> bool {
  return c == ' ' || c == '\n' || c == '\r' || c == '\t'
}


lexer_skip_whitespace :: proc(l: ^Lexer) -> (result: string) {
  if ! char_is_whitespace(l.char) do return ""

  sentinel_char: byte = EOF
  i := 1
  for l.char != EOF {
    c := lexer_peek(l, i)
    if ! char_is_whitespace(c) {
      sentinel_char = c
      break
    }
  }
  ws := lexer_consume_until(l, transmute(string)[]byte{sentinel_char})
  return ws
}


lexer_next :: proc(l: ^Lexer) -> (t: Token) {
  t.pos = l.pos
  switch {
  case l.char == EOF:
    t.type = .EOF

  case l.char == '<' && lexer_peek(l) == '!':
    // For now we don't handle this
    t.type = .Text
    t.value = lexer_consume_until(l, "<")

  case l.char == '<':
    t.type = .Tag_Start
    t.value = lexer_consume(l, "<")
    t.trailing_fluff = lexer_skip_whitespace(l)

  case l.char == '>':
    t.type = .Tag_End
    t.value = lexer_consume(l, ">")

  case l.last_token_type != .Tag_End && l.char == '/':
    t.type = .Element_End
    t.value = lexer_consume(l, "/")
    t.trailing_fluff = lexer_skip_whitespace(l)

  case (l.last_token_type == .Tag_Start || l.last_token_type == .Element_End) && l.char != '>':
    t.type = .Element
    t.value = lexer_consume_until(l, "/", ">", " ")
    t.trailing_fluff = lexer_skip_whitespace(l)

  case l.char == '=' && l.last_token_type == .AttrKey:
    t.type = .AttrVal
    // TODO what to do about this equal sign
    lexer_consume(l, "=")
    t.leading_fluff = lexer_skip_whitespace(l)
    if l.char == '"' {
      // TODO what to do about the quotes
      lexer_consume(l, "\"")
      t.value = lexer_consume_until(l, "\"")
      lexer_consume(l, "\"")
    } else {
      t.value = lexer_consume_until(l, "/", ">", " ")
    }
    t.trailing_fluff = lexer_skip_whitespace(l)

  case l.last_token_type == .Element || l.last_token_type == .AttrVal || l.last_token_type == .AttrKey:
    t.type = .AttrKey
    t.value = lexer_consume_until(l, "/", ">", " ", "=")
    t.trailing_fluff = lexer_skip_whitespace(l)

  case:
    t.type = .Text
    t.value = lexer_consume_until(l, "<")
  }
  l.last_token_type = t.type
  return
}
