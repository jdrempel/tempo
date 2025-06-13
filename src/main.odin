package src

import "core:fmt"
import "core:log"
import "core:mem"
import os "core:os/os2"

import "html"


HTML_FILE_PATH :: "demo.html"
HTML_OUT_FILE_PATH :: "out.html"
TEMPL_FILE_PATH :: "demo.twig"


main :: proc() {
  when ODIN_DEBUG {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
      if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
          fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
        fmt.eprintf("=== %v allocations not freed ===\n", len(track.allocation_map))
      }
      if len(track.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
        for entry in track.bad_free_array {
          fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
        fmt.eprintf("=== %v incorrect frees ===\n", len(track.bad_free_array))
      }
      mem.tracking_allocator_destroy(&track)
    }
  }

  logger := log.create_console_logger()
  context.logger = logger
  defer log.destroy_console_logger(logger)

  hp := new(html.HtmlParser)
  defer html.parser_destroy(hp)

  hp.lex = new(html.Lexer)
  defer free(hp.lex)

  html_data, html_err := os.read_entire_file(HTML_FILE_PATH, context.allocator)
  defer delete(html_data)
  if html_err != nil {
    log.errorf("Error reading %s: %v", HTML_FILE_PATH, html_err)
    os.exit(1)
  }
  html.parser_init(hp, html_data)
  html.parse(hp)

  stream := new(html.HtmlStream)
  stream_ok := html.stream_init(stream, hp.node_stream)
  if ! stream_ok {
    log.error("Stream init failed")
    os.exit(1)
  }
  defer html.stream_destroy(stream)

  html.stream_reset(stream)
  for next, ok := html.stream_next(stream); ok; next, ok = html.stream_next(stream) {
    switch next.kind {
    case .Start:
      data := next.data.(^html.StartEventData)
      if data.tag == "body" {
        p := html.tag("p", "I am a banana!")
        defer html.tag_destroy(p)
        ps := new(html.HtmlStream)
        html.stream_init(ps, p)
        defer html.stream_destroy_nice(ps)
        for ev, ok := html.stream_next(ps); ok; ev, ok = html.stream_next(ps) {
          html.stream_inject(stream, ev)
        }
      }
    case .End:
    case .Text:
    case .Invalid:
      fallthrough
    case:
      continue
    }
  }
  write_stream_to_file(stream, "mod.html")

  using html
  doc := tag("html",
             attr("lang", "US-en"),
             tag("head",
                 tag("meta", attr("charset", "UTF-8")),
                 tag("meta", attr("name", "viewport"), attr("content", "width=device-width, initial-scale=1")),
                 tag("title", "My Demo Page"),
                 tag("link", attr("href", "css/style.css"), attr("rel", "stylesheet"))),
             tag("body",
                 tag("div", attr("class", "thing"),
                 tag("p", attr("id", "my-text"), "Lorem ipsum dolor sit amet."),
                 "Here is some text",
                 tag("img", attr("src", "/pth/thing.png")),
                 "And here is some text following the image.")))
  defer html.tag_destroy(doc)
  // defer free(doc)

  ns := new(html.HtmlStream)
  sie_ok := html.stream_init(ns, doc)
  defer html.stream_destroy(ns)
  write_stream_to_file(ns, "out.html")
}


write_stream_to_file :: proc(s: ^html.HtmlStream, path: string) {
  html.stream_reset(s)
  strs, ok := html.stream_serialize(s)
  defer {
    for str in strs {
      delete(str)
    }
    defer delete(strs)
  }

  if ! ok {
    log.errorf("Failed to serialize stream 'ns'")
    os.exit(1)
  } else {
    log.infof("Serialized %v", strs)
  }

  file, open_err := os.open(path, {os.File_Flag.Create, os.File_Flag.Write, os.File_Flag.Trunc})
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
}
