package html_tests

import "core:fmt"
import "core:testing"
import "../../src/html"


@(test)
parser_smoke_test :: proc(t: ^testing.T) {
  p := html.parser_make()
  defer html.parser_destroy(&p)
  html.parser_init(&p, `<html></html>`)
  html.parse(&p)
}


@(test)
test_html_streams :: proc(t: ^testing.T) {
  p := html.parser_make()
  defer html.parser_destroy(&p)
  html.parser_init(&p, `<html></html>`)
  html.parse(&p)
  testing.expect_value(t, len(p.node_stream), 2)
  s := html.stream_make(p.node_stream)
  defer html.stream_destroy_all(s)
  for next, ok := html.stream_next(s);
      ok;
      next, ok = html.stream_next(s) {
    switch next.kind {
    case .Start:
      p := html.tag("p", "Hello, world!")
      defer html.tag_destroy(p)
      ps := html.stream_make(p)
      defer html.stream_destroy(ps)
      inject_ok := html.stream_inject(s, ps)
      testing.expect(t, inject_ok)
    case .End:
    case .Text:
    case .Invalid:
    case:
    }
  }
  strs, ok := html.stream_serialize(s)
  defer {
    for str in strs {
      delete(str)
    }
    delete(strs)
  }
  // testing.expect_value(t, len(strs), 5)

  expected := [?]string{"<html>", "    <p>", "        Hello, world!", "    </p>", "</html>"}
  for s in strs {
    fmt.printfln("str: '%s'", s)
  }
  testing.expect(t, len(strs) == len(expected))
  for i in 0..<len(expected) {
    testing.expect_value(t, strs[i], expected[i])
  }
}
