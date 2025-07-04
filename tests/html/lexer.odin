package html_tests

import "core:log"
import "core:testing"
import "../../src/html"


@(test)
test_init_values :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)
  html.lexer_init(l, transmute([]byte)string(`<html></html>`))
  testing.expect_value(t, l.pos, 0)
  testing.expect_value(t, l.char, '<')
  testing.expect_value(t, l.last_token_type, html.Token_Type.Illegal)
}


@(test)
test_lexer_read :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)

  html.lexer_init(l, transmute([]byte)string(`hello`))
  testing.expect_value(t, l.pos, 0)
  testing.expect_value(t, l.char, 'h')

  html.lexer_read(l)
  testing.expect_value(t, l.pos, 1)
  testing.expect_value(t, l.char, 'e')

  html.lexer_read(l)
  html.lexer_read(l)
  html.lexer_read(l)
  html.lexer_read(l)
  testing.expect_value(t, l.char, html.EOF)
}


@(test)
test_lexer_next_simple_tag :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)

  html.lexer_init(l, transmute([]byte)string(`< p >`))
  tok: html.Token
  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Tag_Start)
  testing.expect_value(t, tok.pos, 0)
  testing.expect_value(t, tok.value, "<")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, " ")

  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Element)
  testing.expect_value(t, tok.pos, 2)
  testing.expect_value(t, tok.value, "p")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, " ")

  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Tag_End)
  testing.expect_value(t, tok.pos, 4)
  testing.expect_value(t, tok.value, ">")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, "")
}


@(test)
test_lexer_next_tag_with_inline_end :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)

  html.lexer_init(l, transmute([]byte)string(`< meta / >`))
  tok: html.Token
  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Tag_Start)
  testing.expect_value(t, tok.pos, 0)
  testing.expect_value(t, tok.value, "<")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, " ")

  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Element)
  testing.expect_value(t, tok.pos, 2)
  testing.expect_value(t, tok.value, "meta")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, " ")

  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Element_End)
  testing.expect_value(t, tok.pos, 7)
  testing.expect_value(t, tok.value, "/")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, " ")

  tok = html.lexer_next(l)
  testing.expect_value(t, tok.type, html.Token_Type.Tag_End)
  testing.expect_value(t, tok.pos, 9)
  testing.expect_value(t, tok.value, ">")
  testing.expect_value(t, tok.leading_fluff, "")
  testing.expect_value(t, tok.trailing_fluff, "")
}


@(test)
test_lexer_next_start_text_end :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)

  expected: []html.Token = {
    html.Token{type = .Tag_Start,   pos =  0, value = "<"},
    html.Token{type = .Element,     pos =  1, value = "div"},
    html.Token{type = .Tag_End,     pos =  4, value = ">"},
    html.Token{type = .Text,        pos =  5, value = "Text with whitespace"},
    html.Token{type = .Tag_Start,   pos = 25, value = "<"},
    html.Token{type = .Element_End, pos = 26, value = "/"},
    html.Token{type = .Element,     pos = 27, value = "div"},
    html.Token{type = .Tag_End,     pos = 30, value = ">"},
  }

  html.lexer_init(l, transmute([]byte)string(`<div>Text with whitespace</div>`))
  tok: html.Token
  for exp in expected {
    tok = html.lexer_next(l)
    testing.expect_value(t, tok.type, exp.type)
    testing.expect_value(t, tok.pos, exp.pos)
    testing.expect_value(t, tok.value, exp.value)
  }
}


@(test)
test_lexer_consume :: proc(t: ^testing.T) {
  l := new(html.Lexer)
  defer html.lexer_destroy(l)

  html.lexer_init(l, transmute([]byte)string(`hello world!`))
  testing.expect_value(t, l.pos, 0)
  testing.expect_value(t, l.char, 'h')

  hello := html.lexer_consume(l, "hello")
  testing.expect_value(t, hello, "hello")
  testing.expect_value(t, l.pos, 5)
  testing.expect_value(t, l.char, ' ')

  html.lexer_skip_whitespace(l)
  testing.expect_value(t, l.pos, 6)
  testing.expect_value(t, l.char, 'w')

  wor := html.lexer_consume_until(l, "l")
  testing.expect_value(t, wor, "wor")
  testing.expect_value(t, l.pos, 9)
  testing.expect_value(t, l.char, 'l')

  ld_bang := html.lexer_consume_until(l, "?")
  testing.expect_value(t, ld_bang, "ld!")
  testing.expect_value(t, l.pos, 12)
  testing.expect_value(t, l.char, html.EOF)
}
