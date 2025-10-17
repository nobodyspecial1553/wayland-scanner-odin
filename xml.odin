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
}

XML_Token_Type :: enum {
	Unknown = 0,
	Whitespace,
	Angle_Bracket_Left,
	Angle_Bracket_Right,
	Forward_Slash,
	Exclamation,
	Question,
	Hyphen,
	Equals,
	Double_Quotation,
	Identifier,
}

XML_Token :: struct {
	type: XML_Token_Type,
	lexeme: string,
}

XML_Lexer :: struct {
	reader: io.Reader,
	r: rune,
	r_size: int,
	scratch_allocator: mem.Allocator,
	string_allocator: mem.Allocator,
}

xml_lexer_init :: proc(
	lexer: ^XML_Lexer,
	reader: io.Reader,
	string_allocator: mem.Allocator,
	scratch_allocator := context.temp_allocator,
) {
	assert(lexer != nil)

	lexer.reader = reader
	lexer.string_allocator = string_allocator
	lexer.scratch_allocator = scratch_allocator
}

@(require_results)
xml_lexer_token_next :: proc(lexer: ^XML_Lexer) -> (token: XML_Token, error: XML_Error) {
	read_rune :: #force_inline proc(lexer: ^XML_Lexer) -> (r: rune, r_size: int, error: io.Error) {
		r, r_size, error = io.read_rune(lexer.reader)
		lexer.r = r
		lexer.r_size = r_size
		return
	}

	@(require_results)
	parse_rune :: proc(r: rune) -> (token: XML_Token) {
		switch r {
		case ' ':
			return {
				type = .Whitespace,
				lexeme = " ",
			}
		case '\t':
			return {
				type = .Whitespace,
				lexeme = "\t",
			}
		case '\r':
			return {
				type = .Whitespace,
				lexeme = "\r",
			}
		case '\n':
			return {
				type = .Whitespace,
				lexeme = "\n",
			}
		case '<':
			return {
				type = .Angle_Bracket_Left,
				lexeme = "<",
			}
		case '>':
			return {
				type = .Angle_Bracket_Right,
				lexeme = ">",
			}
		case '/':
			return {
				type = .Forward_Slash,
				lexeme = "/",
			}
		case '!':
			return {
				type = .Exclamation,
				lexeme = "!",
			}
		case '?':
			return {
				type = .Question,
				lexeme = "?",
			}
		case '-':
			return {
				type = .Hyphen,
				lexeme = "-",
			}
		case '=':
			return {
				type = .Equals,
				lexeme = "=",
			}
		case '"':
			return {
				type = .Double_Quotation,
				lexeme = "\"",
			}
		}
		return {
			type = .Unknown,
			lexeme = "",
		}
	}

	context.allocator = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()

	assert(lexer != nil)

	if lexer.r == 0 {
		read_rune(lexer) or_return
	}

	token = parse_rune(lexer.r)
	#partial switch token.type {
	case .Unknown:
		string_builder: strings.Builder

		string_builder = strings.builder_make_len_cap(0, 64, lexer.scratch_allocator)

		id_parse_loop: for {
			r: rune

			strings.write_rune(&string_builder, lexer.r)
			r, _ = read_rune(lexer) or_return
			#partial switch parse_rune(r).type {
			case .Unknown:
				continue
			case:
				break id_parse_loop
			}
		}

		token = {
			type = .Identifier,
			lexeme = strings.clone(strings.to_string(string_builder), lexer.string_allocator),
		}
	}

	return token, nil
}

XML_Parser_Protocol :: struct {
	name: string,
	copyright: ^XML_Parser_Copyright,
	interface_list: ^XML_Parser_Interface,
}

XML_Parser_Copyright :: struct {
	content: string,
}

XML_Parser_Interface :: struct {
	next: ^XML_Parser_Interface,
	name: string,
	version: int,
	description: ^XML_Parser_Description,
	event_list: ^XML_Parser_Event,
	request_list: ^XML_Parser_Request,
	enum_list: ^XML_Parser_Enum,
}

XML_Parser_Description :: struct {
	summary: string,
	content: string,
}

XML_Parser_Event :: struct {
	next: ^XML_Parser_Event,
	name: string,
	since: Maybe(int),
	description: ^XML_Parser_Description,
	arg_list: ^XML_Parser_Event_Arg,
}
XML_Parser_Request :: XML_Parser_Event

XML_Parser_Event_Arg :: struct {
	next: ^XML_Parser_Arg,
	name: string,
	type: string,
	summary: string,
	since: Maybe(int),
}
XML_Parser_Request_Arg :: XML_Parser_Event_Arg

XML_Parser_Enum :: struct {
	next: ^XML_Parser_Enum
	name: string,
	since: Maybe(int),
	bitfield: bool,
	description: ^XML_Parser_Description,
	entry_list: ^XML_Parser_Enum_Entry,
}

XML_Parser_Enum_Entry :: struct {
	next: ^XML_Parser_Enum_Entry,
	name: string,
	summary: string,
	value: int
}
