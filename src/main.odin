package src

import "core:log"
import os "core:os/os2"

/*
  {{ value }}

  {% if <<condition>> %}
  {% elseif <<condition>> %}
  {% else %}
  {% endif %}

  {% for <<loop_setup>> %}
  {% endfor %}
*/

FILE_PATH :: "demo.twig"


main :: proc() {
  logger := log.create_console_logger()
  context.logger = logger

  p := new(Parser)
  defer free(p)

  p.lex = new(Lexer)
  defer free(p.lex)

  data, err := os.read_entire_file(FILE_PATH, context.allocator)
  if err != nil {
    log.errorf("Error reading %s: %v", FILE_PATH, err)
    os.exit(1)
  }

  parser_init(p, data)
  parse(p)
  log.infof("Parse data: %#v", p.ast_root)
}
