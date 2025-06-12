package html

import "core:log"
import rf "core:reflect"


Fragment :: struct {
  children: [dynamic]Any_Fragment,
}


Element :: struct {
  using fragment: Fragment,
  using attrs: Attrs,
  tag: string,
}


Any_Fragment :: union {
  ^Fragment,
  ^Element,
  ^string,
}


init_element :: proc(e: ^Element) {
  e.children = make([dynamic]Any_Fragment)
}


@(private="file")
_build_0_attr :: proc(tag: string, fs: ..Any_Fragment) -> (n: ^Element) {
  n = new(Element)
  init_element(n)
  n.tag = tag
  for f in fs {
    append(&n.children, f)
  }
  return
}


@(private="file")
_build_1_attr :: proc(tag: string, a0: Attr, fs: ..Any_Fragment) -> (n: ^Element) {
  n = _build_0_attr(tag, ..fs)
  attrs_append_attr(n, a0)
  return
}


@(private="file")
_build_2_attr :: proc(tag: string, a0: Attr, a1: Attr, fs: ..Any_Fragment) -> (n: ^Element) {
  n = _build_1_attr(tag, a0, ..fs)
  attrs_append_attr(n, a1)
  return
}


@(private="file")
_build_3_attr :: proc(tag: string, a0: Attr, a1: Attr, a2: Attr, fs: ..Any_Fragment) -> (n: ^Element) {
  n = _build_2_attr(tag, a0, a1, ..fs)
  attrs_append_attr(n, a2)
  return
}


@(private="file")
_build_text :: proc(tag: string, text: ^string) -> (n: ^Element) {
  n = _build_0_attr(tag)
  append(&n.children, text)
  return
}


build :: proc{
  _build_0_attr,
  _build_1_attr,
  _build_2_attr,
  _build_3_attr,
  _build_text,
}


text :: proc(text: string) -> (n: Any_Fragment) {
  n = new(string)
  n.(^string)^ = text
  return
}


builder_append :: proc(frag: ^Fragment, fs: ..Any_Fragment) {
  for f in fs {
    append(&frag.children, f)
  }
}


// builder_generate :: proc(frag: ^Fragment) -> (s: ^HtmlStream) {
//   s = new(HtmlStream)
//   stream_init(s)
//   return
// }
