package src

import "core:log"
import os "core:os/os2"

import "html"


HTML_FILE_PATH :: "demo.html"
HTML_OUT_FILE_PATH :: "out.html"
TEMPL_FILE_PATH :: "demo.twig"


main :: proc() {
  logger := log.create_console_logger()
  context.logger = logger

  hp := new(html.HtmlParser)
  defer free(hp)

  hp.lex = new(html.Lexer)
  defer free(hp.lex)

  html_data, html_err := os.read_entire_file(HTML_FILE_PATH, context.allocator)
  if html_err != nil {
    log.errorf("Error reading %s: %v", HTML_FILE_PATH, html_err)
    os.exit(1)
  }
  html.parser_init(hp, html_data)
  html.parse(hp)

  stream := new(html.HtmlStream)
  defer free(stream)
  stream_ok := html.stream_init(stream, hp.node_stream)
  if ! stream_ok {
    log.error("Stream init failed")
    os.exit(1)
  }

  html.stream_reset(stream)
  for next, ok := html.stream_next(stream); ok; next, ok = html.stream_next(stream) {
    switch next.kind {
    case .Start:
      data := next.data.(^html.StartEventData)
      log.infof("START: %q", data.tag)
      attrs := html.attrs_get_all(&data.attrs) or_continue
      for attr in attrs {
        log.infof(" :: %s=%q", attr.key, attr.value)
      }
      if data.tag == "body" {
        p := new(html.Event)
        p.kind = .Start
        p.data = new(html.StartEventData)
        p.data.(^html.StartEventData).tag = "p"
        html.stream_inject(stream, p)

        txt := new(html.Event)
        txt.kind = .Text
        txt.data = new(html.TextEventData)
        txt.data.(^html.TextEventData)^ = "I am a banana"
        html.stream_inject(stream, txt)

        end := new(html.Event)
        end.kind = .End
        end.data = new(html.EndEventData)
        end.data.(^html.EndEventData).tag = "p"
        html.stream_inject(stream, end)
      }
    case .End:
      log.infof("END: %q", next.data.(^html.EndEventData).tag)
    case .Text:
      log.infof("TEXT: %q", next.data.(^html.TextEventData)^)
    case .Invalid:
      fallthrough
    case:
      continue
    }
  }

  // strs, ok := html.stream_serialize(stream)
  // file, open_err := os.open(HTML_OUT_FILE_PATH, {os.File_Flag.Create, os.File_Flag.Write})
  // if open_err == nil {
  //   defer os.close(file)
  //   for str in strs {
  //     log.info(str)
  //     os.write_string(file, str)
  //     os.write_byte(file, '\n')
  //   }
  // } else {
  //   log.errorf("Error opening file: %v", open_err)
  // }

  p1_content := "Hey now"
  e := html.build("div",
                  html.Attr{key="id", value="my-div"},
                  html.Attr{key="class", value="foo bar baz"},
                  html.Attr{key="style", value="display: none;"},
                  html.build("p", &p1_content))
  defer free(e)
  e_content := "Yo..."
  html.builder_append(e, &e_content)

  p_content := "Hello, world!"
  p := html.build(string("p"), &p_content)
  defer free(p)
  html.builder_append(e, p)

  e_content_2 := "Hey, nice."
  html.builder_append(e, &e_content_2)

  ns := new(html.HtmlStream)
  defer free(ns)
  sie_ok := html.stream_init_element(ns, e)

  html.stream_reset(ns)
  for next, ok := html.stream_next(ns); ok; next, ok = html.stream_next(ns) {
    switch next.kind {
    case .Start:
      data := next.data.(^html.StartEventData)
      log.infof("START: %q", data.tag)
      attrs := html.attrs_get_all(&data.attrs) or_continue
      for attr in attrs {
        log.infof(" :: %s=%q", attr.key, attr.value)
      }
    case .End:
      log.infof("END: %q", next.data.(^html.EndEventData).tag)
    case .Text:
      log.infof("TEXT: %q", next.data.(^html.TextEventData)^)
    case .Invalid:
      fallthrough
    case:
      continue
    }
  }

  strs, ok := html.stream_serialize(ns)
  if ! ok {
    log.errorf("Failed to serialize stream 'ns'")
    os.exit(1)
  } else {
    log.infof("Serialized %v", strs)
  }
  file, open_err := os.open(HTML_OUT_FILE_PATH, {os.File_Flag.Create, os.File_Flag.Write, os.File_Flag.Trunc})
  if open_err == nil {
    defer os.close(file)
    for str in strs {
      log.info(str)
      os.write_string(file, str)
      os.write_byte(file, '\n')
    }
  } else {
    log.errorf("Error opening file: %v", open_err)
  }


  // tp := new(Parser)
  // defer free(tp)

  // tp.lex = new(Lexer)
  // defer free(tp.lex)

  // templ_data, templ_err := os.read_entire_file(TEMPL_FILE_PATH, context.allocator)
  // if templ_err != nil {
  //   log.errorf("Error reading %s: %v", TEMPL_FILE_PATH, templ_err)
  //   os.exit(1)
  // }

  // parser_init(tp, templ_data)
  // parse(tp)
  // log.infof("Parse data: %#v", tp.ast_root)
}
