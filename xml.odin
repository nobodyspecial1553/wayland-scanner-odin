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
	XML_Parse_Error,
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

XML_Token_Location :: struct {
	offset: int,
	x: int,
	y: int,
}

XML_Token :: struct {
	type: XML_Token_Type,
	lexeme: string,
	using location: XML_Token_Location,
}

XML_Lexer :: struct {
	reader: io.Reader,
	r: rune,
	r_size: int,
	using location: XML_Token_Location,
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

	lexer.x = 1
	lexer.y = 1
}

@(require_results)
xml_lexer_token_next :: proc(lexer: ^XML_Lexer) -> (token: XML_Token, error: XML_Error) {
	read_rune :: #force_inline proc(lexer: ^XML_Lexer) -> (r: rune, r_size: int, error: io.Error) {
		r, r_size, error = io.read_rune(lexer.reader)
		lexer.r = r
		lexer.r_size = r_size
		lexer.offset += r_size
		if r == '\n' {
			lexer.y += 1
			lexer.x = 1
		}
		else {
			lexer.x += r_size
		}
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
	token.location = lexer.location
	token.location.x -= 1

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

		token.type = .Identifier
		token.lexeme = strings.clone(strings.to_string(string_builder), lexer.string_allocator)
	case:
		read_rune(lexer) or_return
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
	next: ^XML_Parser_Event_Arg,
	name: string,
	type: string,
	summary: string,
	since: Maybe(int),
}
XML_Parser_Request_Arg :: XML_Parser_Event_Arg

XML_Parser_Enum :: struct {
	next: ^XML_Parser_Enum,
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
	value: int,
}

XML_Parse_Error :: enum {
	None = 0,
	Invalid_XML_Declaration,
	Unexpected_Token,
}

@(require_results)
xml_parse_skip_ws :: proc(lexer: ^XML_Lexer) -> (token: XML_Token, error: XML_Error) {
	for {
		token = xml_lexer_token_next(lexer) or_return
		if token.type != .Whitespace {
			break
		}
	}
	return
}

@(private="file")
@(require_results)
xml_parse_generate_print_header :: proc(
	type: string,
	#any_int x, y: int,
	temp_allocator := context.temp_allocator,
) -> (
	header: string,
) {
	header = fmt.aprintf("[%s@%v,%v]:", type, x, y, allocator = temp_allocator)
	return header
}

@(private="file")
xml_parse_print_error_expected :: proc(
	location: XML_Token_Location,
	expected: string,
	received: string,
	temp_allocator := context.temp_allocator)
{
	header: string

	context.temp_allocator = temp_allocator

	header = xml_parse_generate_print_header("Error", location.x, location.y, temp_allocator)
	fmt.eprintfln("%s Expected \"%s\", received \"%s\"", header, expected, received)
}

@(require_results)
xml_parse :: proc(
	lexer: ^XML_Lexer,
	arena_allocator: mem.Allocator,
	scratch_allocator: mem.Allocator,
) -> (
	protocol: XML_Parser_Protocol,
	error: XML_Error,
) {
	context.allocator = arena_allocator
	context.temp_allocator = scratch_allocator

	assert(lexer != nil)

	{ // XML Declaration
		token: XML_Token

		token = xml_parse_skip_ws(lexer) or_return
		if token.type != .Angle_Bracket_Left {
			xml_parse_print_error_expected(lexer^, "<", token.lexeme)
			return {}, XML_Parse_Error.Invalid_XML_Declaration
		}

		token = xml_parse_skip_ws(lexer) or_return
		if token.type != .Question {
			xml_parse_print_error_expected(lexer^, "?", token.lexeme)
			return {}, XML_Parse_Error.Invalid_XML_Declaration
		}

		token = xml_parse_skip_ws(lexer) or_return
		if token.lexeme != "xml" {
			xml_parse_print_error_expected(lexer^, "xml", token.lexeme)
			return {}, XML_Parse_Error.Invalid_XML_Declaration
		}

		for {
			token = xml_parse_skip_ws(lexer) or_return
			if token.type == .Question {
				break
			}
			switch token.lexeme {
			case "version":
				_ = xml_parse_skip_ws(lexer) or_return // =
				_ = xml_parse_skip_ws(lexer) or_return // "
				for {
					token = xml_parse_skip_ws(lexer) or_return
					if token.type == .Double_Quotation {
						break
					}
				}
			case "encoding":
				encoding_type_string_builder: strings.Builder

				encoding_type_string_builder = strings.builder_make_len_cap(0, 5, scratch_allocator)

				_ = xml_parse_skip_ws(lexer) or_return // =
				_ = xml_parse_skip_ws(lexer) or_return // "
				for {
					token = xml_parse_skip_ws(lexer) or_return
					if token.type == .Double_Quotation {
						break
					}
					strings.write_string(&encoding_type_string_builder, token.lexeme)
				}
				if strings.to_string(encoding_type_string_builder) != "UTF-8" {
					header: string

					header = xml_parse_generate_print_header("Error", token.x, token.y)
					log.fatalf("%s Invalid encoding: \"%s\"", header, token.lexeme)
					return {}, XML_Parse_Error.Invalid_XML_Declaration
				}
			case:
				header: string

				header = xml_parse_generate_print_header("Error", token.x, token.y)
				fmt.eprintfln("%s Unrecognized XML Declaration Attribute: \"%v\"", header, token.lexeme)
			}
		}

		token = xml_parse_skip_ws(lexer) or_return
		if token.type != .Angle_Bracket_Right {
			header: string

			header = xml_parse_generate_print_header("Error", token.x, token.y)
			fmt.eprintfln("%s Invalid XML Declaration", header)
			return {}, XML_Parse_Error.Invalid_XML_Declaration
		}
	}

	{
		tag: XML_Parser_Tag
		protocol_ok: bool

		tag = xml_parse_tag(lexer) or_return
		protocol, protocol_ok = tag.(XML_Parser_Protocol)
		if protocol_ok == false {
			return {}, XML_Parse_Error.Unexpected_Token
		}
	}

	return protocol, nil
}

XML_Parser_Tag :: union #no_nil {
	XML_Parser_Protocol,
	XML_Parser_Copyright,
	XML_Parser_Interface,
	XML_Parser_Description,
	XML_Parser_Event,
	XML_Parser_Event_Arg,
	XML_Parser_Enum,
	XML_Parser_Enum_Entry,
}

@(require_results)
xml_parse_tag :: proc(
	lexer: ^XML_Lexer,
	arena_allocator := context.allocator,
	scratch_allocator := context.temp_allocator,
) -> (
	tag: XML_Parser_Tag,
	error: XML_Error,
) {
	token: XML_Token

	context.allocator = arena_allocator
	context.temp_allocator = scratch_allocator

	assert(lexer != nil)

	token = xml_parse_skip_ws(lexer) or_return
	if token.type == .Angle_Bracket_Left {
		token = xml_parse_skip_ws(lexer) or_return
	}
	tag_lexeme_switch: switch token.lexeme {
	//case "arg":
	//case "entry":
	//case "event":
	//case "enum":
	//case "description":
	//case "interface":
	//case "copyright":
	//case "protocol":
	case:
		tag_token: XML_Token

		tag_token = token

		#partial switch token.type {
		case .Unknown, .Identifier:
			header: string

			header = xml_parse_generate_print_header("Error", token.x, token.y)
			fmt.eprintfln("%s Unrecognized tag: \"%s\"", header, token.lexeme)
		case:
			header: string

			header = xml_parse_generate_print_header("Error", token.x, token.y)
			fmt.eprintfln("%s Unexpected token: %v", header, token.lexeme)
		}

		for {
			token = xml_parse_skip_ws(lexer) or_return
			if token.type == .Forward_Slash {
				token = xml_parse_skip_ws(lexer) or_return
				if token.type != .Angle_Bracket_Right {
					xml_parse_print_error_expected(lexer^, ">", token.lexeme)
					return tag, XML_Parse_Error.Unexpected_Token
				}
				break tag_lexeme_switch
			}
			else if token.type == .Angle_Bracket_Right {
				break
			}
		}

		for {
			token = xml_parse_skip_ws(lexer) or_return
			if token.type != .Angle_Bracket_Left {
				continue
			}

			token = xml_parse_skip_ws(lexer) or_return
			if token.type != .Forward_Slash {
				continue
			}

			token = xml_parse_skip_ws(lexer) or_return
			if token.lexeme == tag_token.lexeme {
				break
			}
		}
	}

	return tag, nil
}

XML_Parser_Attribute :: struct {
	name: string,
	value: string,
}

@(require_results)
xml_parse_attribute :: proc(
	lexer: ^XML_Lexer,
	arena_allocator := context.allocator,
	scratch_allocator := context.temp_allocator,
) -> (
	attribute: XML_Parser_Attribute,
	error: XML_Error,
) {
	context.allocator = arena_allocator
	context.temp_allocator = scratch_allocator

	assert(lexer != nil)

	return attribute, nil
}
