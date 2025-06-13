package html

import "core:fmt"
import "core:strings"


START_TEMPLATE :: "<%s%s>"
END_TEMPLATE :: "<%s%s>"


Serializer :: struct {
  indent_level: int,
  indent_size: int,
  empty_tags: map[string]any,
}


ser_write_indent :: proc(s: ^Serializer, b: ^strings.Builder) {
  for i in 0..<s.indent_level {
    for j in 0..<s.indent_size {
      strings.write_byte(b, ' ')
    }
  }
}


serialize_text_event :: proc(s: ^Serializer, e: ^Event) -> (result: string, ok: bool) {
  assert(e.kind == .Text)
  data := e.data.(TextEventData)

  bld := strings.builder_make()

  ser_write_indent(s, &bld)
  trimmed := strings.trim_space(data)
  strings.write_string(&bld, trimmed)

  result = strings.to_string(bld)
  ok = true
  return result, ok
}


serialize_start_event :: proc(s: ^Serializer, e: ^Event) -> (result: string, ok: bool) {
  assert(e.kind == .Start)
  data := e.data.(^StartEventData)

  bld := strings.builder_make()

  ser_write_indent(s, &bld)
  strings.write_byte(&bld, '<')
  strings.write_string(&bld, data.tag)

  attrs_str, attrs_ok := serialize_attrs(&data.attrs)
  defer delete(attrs_str)

  strings.write_string(&bld, attrs_str)
  strings.write_byte(&bld, '>')

  result = strings.to_string(bld)
  ok = true
  return result, ok
}


serialize_attrs :: proc(a: ^Attrs) -> (result: string, ok: bool) {
  attrs := attrs_get_all(a) or_return
  defer delete(attrs)

  bld := strings.builder_make()

  for attr in attrs {
    strings.write_byte(&bld, ' ')
    strings.write_string(&bld, attr.key)
    if attr.value != nil {
      strings.write_byte(&bld, '=')
      strings.write_quoted_string(&bld, attr.value.?)
    }
  }

  result = strings.to_string(bld)
  ok = true
  return result, ok
}


serialize_end_event :: proc(s: ^Serializer, e: ^Event) -> (result: string, ok: bool) {
  assert(e.kind == .End)
  data := e.data.(^EndEventData)
  bld := strings.builder_make()

  ser_write_indent(s, &bld)
  strings.write_string(&bld, "</")
  strings.write_string(&bld, data.tag)
  strings.write_byte(&bld, '>')

  result = strings.to_string(bld)
  ok = true
  return result, ok
}
