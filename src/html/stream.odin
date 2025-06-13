package html

import "base:runtime"
import "core:log"


HtmlStream :: struct {
  ally: runtime.Allocator,
  _cursor: int,
  _events: [dynamic]^Event,
  _init: bool,
}


Event :: struct {
  kind: EventKind,
  data: EventData,
  pos: Pos,
}


EventKind :: enum {
  Invalid = 0,
  Start,
  Text,
  End,
}


EventData :: union {
  ^StartEventData,
  TextEventData,
  ^EndEventData,
}


StartEventData :: struct {
  tag: string,
  attrs: Attrs,
}


TextEventData :: string


EndEventData :: struct {
  tag: string,
}


Attrs :: struct {
  _names: [dynamic]string,
  _name_value_map: map[string]Maybe(string),
}


Attr :: struct {
  key: string,
  value: Maybe(string),
}


init_attrs :: proc(a: ^Attrs, allocator := context.allocator) {
  a._names = make([dynamic]string, allocator)
  a._names.allocator = allocator
  a._name_value_map = make(map[string]Maybe(string), allocator)
  a._name_value_map.allocator = allocator
}


attrs_destroy :: proc(a: ^Attrs) {
  delete(a._names)
  delete(a._name_value_map)
}


attrs_append_key_value :: proc(a: ^Attrs, key: string, value: Maybe(string)) {
  append(&a._names, key)
  a._name_value_map[key] = value
}


attrs_append_attr :: proc(a: ^Attrs, attr: Attr) {
  append(&a._names, attr.key)
  a._name_value_map[attr.key] = attr.value
}


attrs_append :: proc {
  attrs_append_key_value,
  attrs_append_attr,
}


attrs_iter_names :: proc(a: ^Attrs) -> ^[dynamic]string {
  return &a._names
}


attrs_get_value :: proc(a: ^Attrs, key: string) -> (elem: Maybe(string), ok: bool) {
  elem = a._name_value_map[key] or_return
  ok = true
  return
}


attrs_get_all :: proc(a: ^Attrs) -> (result: [dynamic]Attr, ok: bool) {
  result = make([dynamic]Attr)
  for name in attrs_iter_names(a) {
    key := name
    value := attrs_get_value(a, key) or_return
    attr := Attr{
      key = key,
      value = value,
    }
    append(&result, attr)
  }
  ok = true
  return result, ok
}


stream_init_nodes :: proc(s: ^HtmlStream, nodes: [dynamic]^Node, allocator := context.allocator) -> (ok: bool) {
  if ! s._init {
    s.ally = allocator
    s._events = make([dynamic]^Event, allocator)
    s._events.allocator = allocator
    s._init = true
  }

  e: ^Event
  for node in nodes {
    switch v in node.derived {
    case ^Node_Text:
      e = new(Event)
      e.kind = .Text
      e.data = v.text.value
      append(&s._events, e)

    case ^Node_Element:
      e = new(Event)
      if v.end != nil {
        e.kind = .End
        e.data = new(EndEventData)
        e.data.(^EndEventData).tag = v.name.value
      } else {
        e.kind = .Start
        e.data = new(StartEventData)
        e.data.(^StartEventData).tag = v.name.value
        init_attrs(&e.data.(^StartEventData).attrs)
        for attr in v.attrs {
          key := attr.key.value
          value: Maybe(string)
          if attr.value == nil {
            value = nil
          } else {
            value = attr.value.?.value
          }
          attrs_append(&e.data.(^StartEventData).attrs, key, value)
        }
      }
      append(&s._events, e)
      
    case ^Node_Attr:
      return ok
    case:
      return ok
    }
  }
  ok = true
  return ok
}


stream_init_element :: proc(s: ^HtmlStream, el: ^Element, allocator := context.allocator) -> (ok: bool) {
  if ! s._init {
    s.ally = allocator
    s._events = make([dynamic]^Event, allocator)
    s._events.allocator = allocator
    s._init = true
  }

  start := new(Event)
  start.kind = .Start
  start.data = new(StartEventData)
  start.data.(^StartEventData).tag = el.tag
  start.data.(^StartEventData).attrs = el.attrs
  append(&s._events, start)

  for child in el.children {
    switch _ in child {
    case ^Element:
      stream_init_element(s, child.(^Element), allocator) or_return
    case ^Fragment:
      log.debugf("Child is a Fragment")
      stream_init_fragment(s, child.(^Fragment), allocator) or_return
    case string:
      ch := new(Event)
      ch.kind = .Text
      ch.data = child.(string)
      append(&s._events, ch)
    case:
      return
    }
  }

  stop := new(Event)
  stop.kind = .End
  stop.data = new(EndEventData)
  stop.data.(^EndEventData).tag = el.tag
  append(&s._events, stop)
  ok = true
  return ok
}


stream_init_fragment :: proc(s: ^HtmlStream, frag: ^Fragment, allocator := context.allocator) -> (ok: bool) {
  if typeid_of(^Element) == typeid_of(type_of(frag)) {
    log.debugf("Got ELEMENT")
  } else {
    log.debugf("Got FRAGMENT")
  }
  ok = true
  return
}


stream_init :: proc {
  stream_init_nodes,
  stream_init_element,
  stream_init_fragment,
}


stream_destroy :: proc (s: ^HtmlStream) {
  for e in s._events {
    switch v in e.data {
    case ^StartEventData:
      attrs_destroy(&v.attrs)
      free(v)
    case ^EndEventData:
      free(v)
    case TextEventData:
    }
    free(e)
  }
  delete(s._events)
  free(s)
}


stream_destroy_nice :: proc(s: ^HtmlStream) {
  delete(s._events)
  free(s)
}


stream_reset :: proc(s: ^HtmlStream) {
  s._cursor = 0
}


stream_next :: proc(s: ^HtmlStream) -> (e: ^Event, ok: bool) {
  if s._cursor >= len(s._events) {
    return
  }
  e = s._events[s._cursor]
  s._cursor += 1
  ok = true
  return
}


stream_inject :: proc(s: ^HtmlStream, e: ^Event) -> (ok: bool) {
  inject_ok, err := inject_at(&s._events, s._cursor, e)
  if err != nil {
    return
  }
  s._cursor += 1
  ok = inject_ok
  return
}


stream_replace :: proc(s: ^HtmlStream, e: ^Event) -> (ok: bool) {
  assign_ok, err := assign_at(&s._events, s._cursor, e)
  if err != nil {
    return
  }
  s._cursor += 1
  ok = assign_ok
  return
}


stream_serialize :: proc(s: ^HtmlStream) -> (result: [dynamic]string, ok: bool) {
  result = make([dynamic]string)
  ser := new(Serializer)
  defer free(ser)

  ser.indent_size = 4
  // TODO
  empty_tags_html := map[string]any{
    "area" = nil,
    "base" = nil, 
    "basefont" = nil, 
    "br" = nil, 
    "col" = nil, 
    "frame" = nil, 
    "hr" = nil, 
    "img" = nil, 
    "input" = nil, 
    "isindex" = nil, 
    "link" = nil, 
    "meta" = nil, 
    "param" = nil,
  }
  defer delete(empty_tags_html)
  ser.empty_tags = empty_tags_html

  for event in s._events {
    switch event.kind {
    case .Text:
      text_data := serialize_text_event(ser, event) or_return
      if len(text_data) == 0 do continue
      append(&result, text_data)

    case .Start:
      append(&result, serialize_start_event(ser, event) or_return)
      if event.data.(^StartEventData).tag not_in ser.empty_tags {
        ser.indent_level += 1
      }

    case .End:
      if event.data.(^EndEventData).tag in ser.empty_tags do break
      ser.indent_level -= 1
      append(&result, serialize_end_event(ser, event) or_return)

    case .Invalid:
      fallthrough

    case:
      return
    }
  }
  ok = true
  return result, ok
}
