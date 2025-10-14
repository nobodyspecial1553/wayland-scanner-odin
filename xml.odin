package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
import "core:mem"
import "core:strings"
import "core:io"

// Reminder of where log2 is
// import "base:intrinsics"
// log2 :: intrinsics.constant_log2

XML_Error :: union #shared_nil {
	io.Error,
	XML_Token_Error,
}

XML_Token_Error :: enum {
	None = 0,
	Invalid_Token,
}

XML_Token_Type :: enum {
	Invalid = 0,
	Angle_Bracket_Left,
	Angle_Bracket_Right,
	Forward_Slash,
	Exclamation,
	Question,
	Equals,
	String,
	Identifier,
}

XML_Token :: struct {
	type: XML_Token_Type,
}

XML_Lexer :: struct {
	reader: io.Reader,
	r: rune,
	r_size: int,
	scratch_allocator: mem.Allocator,
}

xml_lexer_init :: proc(lexer: ^XML_Lexer, reader: io.Reader, scratch_allocator := context.temp_allocator) {
	assert(lexer != nil)

	lexer.reader = reader
	lexer.scratch_allocator = scratch_allocator
}

@(require_results)
xml_lexer_token_next :: proc(lexer: ^XML_Lexer) -> (token: XML_Token, error: XML_Error) {
	assert(lexer != nil)

	for {
		switch lexer.r {
		case 0, ' ', '\t', '\r', '\n':
			lexer.r, lexer.r_size = io.read_rune(lexer.reader) or_return
			continue
		}
		break
	}

	return token, nil
}
