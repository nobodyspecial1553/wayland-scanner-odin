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

@(rodata)
xml_token_type_string_array := [XML_Token_Type]string {
	.Unknown = "",
	.Whitespace = "",
	.Angle_Bracket_Left = "<",
	.Angle_Bracket_Right = ">",
	.Forward_Slash = "/",
	.Exclamation = "!",
	.Question = "?",
	.Hyphen = "-",
	.Equals = "=",
	.Double_Quotation = "\"",
	.Identifier = "",
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
	@(require_results)
	is_ws :: #force_inline proc "contextless" (r: rune) -> (ok: bool) {
		switch r {
		case ' ', '\t', '\r', '\n':
			return true
		}
		return false
	}

	read_rune :: #force_inline proc(lexer: ^XML_Lexer) -> (r: rune, r_size: int, error: io.Error) {
		r, r_size, error = io.read_rune(lexer.reader)
		lexer.r = r
		lexer.r_size = r_size
		return
	}

	parse_rune :: proc(r: rune) -> (token_type: XML_Token_Type) {
		switch r {
		case ' ', '\t', '\r', '\n':
			return .Whitespace
		case '<':
			return .Angle_Bracket_Left
		case '>':
			return .Angle_Bracket_Right
		case '/':
			return .Forward_Slash
		case '!':
			return .Exclamation
		case '?':
			return .Question
		case '-':
			return .Hyphen
		case '=':
			return .Equals
		case '"':
			return .Double_Quotation
		}
		return .Unknown
	}

	context.allocator = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()

	assert(lexer != nil)

	if lexer.r == 0 {
		read_rune(lexer) or_return
	}

	token.type = parse_rune(lexer.r)
	#partial switch token.type {
	case .Unknown:
		string_builder: strings.Builder

		string_builder = strings.builder_make_len_cap(0, 64, lexer.scratch_allocator)

		id_parse_loop: for {
			r: rune

			strings.write_rune(&string_builder, lexer.r)
			r, _ = read_rune(lexer) or_return
			#partial switch parse_rune(r) {
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
	case .Whitespace:
		switch lexer.r {
		case ' ':
			token.lexeme = " "
		case '\t':
			token.lexeme = "\t"
		case '\r':
			token.lexeme = "\r"
		case '\n':
			token.lexeme = "\n"
		}
		read_rune(lexer)
	case:
		token.lexeme = xml_token_type_string_array[token.type]
		read_rune(lexer)
	}

	return token, nil
}
