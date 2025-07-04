package examples

import "core:fmt"
import os "core:os/os2"

import "../src/html"

main :: proc() {
	using html

	// Set up the HTML parser
	html_parser := parser_make()
	defer parser_destroy(&html_parser)

	// Initialize and load in some data
	parser_init(
		&html_parser,
		`<html><body><p id="greeting">Hello, <em>world!</em></p></body></html>`,
	)

	// Perform the actual parsing from text -> nodes
	parse(&html_parser)

	// Create an HTML event stream
	main_stream := stream_make(html_parser.node_stream)
	// Use stream_destroy_all to fully clean up all merged events when done
	defer stream_destroy_all(main_stream)

	// Loop over the events in the HTML event stream.
	// This is mainly useful for injecting or replacing text or elements.
	// In this example, we will append a <p id="response">Hellope!</p> just after
	//  the "Hello, world!" paragraph.
	saw_greeting := false
	for next, ok := stream_next(main_stream); ok; next, ok = stream_next(main_stream) {
		switch next.kind {
		case .Start:
			data := next.data.(^StartEventData)
			// Ensure the element is a <p>
			if data.tag == "p" {
				// Check that the <p> has id="greeting"
				id := attrs_get_value(&data.attrs, "id") or_continue
				if id != "greeting" do continue
				saw_greeting = true
			}
		case .End:
			data := next.data.(^EndEventData)
			// Ensure the element is a <p>
			if data.tag == "p" && saw_greeting {
				// Create the new <p id="response">Hellope!</p>
				p := tag("p", attr("id", "response"), "Hellope!")
				// It can be destroyed since we are immediately converting to a stream just below this
				defer tag_destroy(p)

				// Convert <p>...</p> to a substream
				tag_stream := stream_make(p)
				defer stream_destroy(tag_stream)

				// Inject the <p>...</p> substream into the main HTML stream
				stream_inject(main_stream, tag_stream)
			}
		case .Text:
		case .Invalid:
		}
	}

	stream_reset(main_stream)
	strs, _ := stream_serialize(main_stream)
	defer {
		for str in strs {
			delete(str)
		}
		delete(strs)
	}
	/*
  Should print something like:
  <html>
    <body>
      <p id="greeting">
        Hello, 
        <em>
          world!
        </em>
      </p>
      <p id="response">
        Hellope!
      </p>
    </body>
  </html>
  */
	for str in strs {
		fmt.println(str)
	}
}
