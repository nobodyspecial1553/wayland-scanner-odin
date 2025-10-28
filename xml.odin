package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
import "core:mem"
import "core:strings"
import "core:strconv"
import "core:io"
import "core:reflect"

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
		PRINT_RUNE_READ :: #config(PRINT_RUNE_READ, false)
		when PRINT_RUNE_READ == true {
			fmt.print(r)
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

XML_Parser_Unknown :: struct {
	tag_name: string,
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

XML_Parser_Proc :: struct {
	name: string,
	type: string,
	since: Maybe(int),
	description: ^XML_Parser_Description,
	arg_list: ^XML_Parser_Arg,
}
XML_Parser_Event :: struct {
	next: ^XML_Parser_Event,
	using _: XML_Parser_Proc,
}
XML_Parser_Request :: struct {
	next: ^XML_Parser_Request,
	using _: XML_Parser_Proc,
}

XML_Parser_Arg :: struct {
	next: ^XML_Parser_Arg,
	name: string,
	type: string,
	summary: string,
	interface: string,
	_enum: string,
	since: Maybe(int),
}

XML_Parser_Enum :: struct {
	next: ^XML_Parser_Enum,
	name: string,
	since: Maybe(int),
	bitfield: bool,
	description: ^XML_Parser_Description,
	entry_list: ^XML_Parser_Entry,
}

XML_Parser_Entry :: struct {
	next: ^XML_Parser_Entry,
	name: string,
	summary: string,
	value: int,
}

XML_Parse_Error :: enum {
	None = 0,
	Invalid_XML_Declaration,
	Unexpected_Token,
	Unexpected_Closing_Tag,
	Integer_Cast_Failure,
	Reflection_Unhandled_Base_Type,
	Reflection_Incorrect_Integer_Size,
	Reflection_Union_Is_Not_Maybe_Like,
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
	location: XML_Token_Location,
	temp_allocator := context.temp_allocator,
) -> (
	header: string,
) {
	header = fmt.aprintf("[%s@%v,%v]:", type, location.x, location.y, allocator = temp_allocator)
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

	header = xml_parse_generate_print_header("Error", location, temp_allocator)
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

					header = xml_parse_generate_print_header("Error", token.location)
					log.fatalf("%s Invalid encoding: \"%s\"", header, token.lexeme)
					return {}, XML_Parse_Error.Invalid_XML_Declaration
				}
			case:
				header: string

				header = xml_parse_generate_print_header("Error", token.location)
				fmt.eprintfln("%s Unrecognized XML Declaration Attribute: \"%v\"", header, token.lexeme)
			}
		}

		token = xml_parse_skip_ws(lexer) or_return
		if token.type != .Angle_Bracket_Right {
			header: string

			header = xml_parse_generate_print_header("Error", token.location)
			fmt.eprintfln("%s Invalid XML Declaration", header)
			return {}, XML_Parse_Error.Invalid_XML_Declaration
		}
	}

	{
		tag: XML_Parser_Tag
		protocol_ok: bool

		tag, _ = xml_parse_tag(lexer) or_return
		protocol, protocol_ok = tag.variant.(XML_Parser_Protocol)
		if protocol_ok == false {
			return {}, XML_Parse_Error.Unexpected_Token
		}
	}

	return protocol, nil
}

XML_Parser_Tag_Variant :: union #no_nil {
	XML_Parser_Unknown,
	XML_Parser_Protocol,
	XML_Parser_Copyright,
	XML_Parser_Interface,
	XML_Parser_Description,
	XML_Parser_Event,
	XML_Parser_Request,
	XML_Parser_Arg,
	XML_Parser_Enum,
	XML_Parser_Entry,
}

XML_Parser_Tag :: struct {
	location: XML_Token_Location,
	name: string,
	variant: XML_Parser_Tag_Variant,
}

@(require_results)
xml_parser_tag_variant_to_string :: proc(xml_parser_tag_variant: XML_Parser_Tag_Variant) -> (variant_string: string) {
	switch _ in xml_parser_tag_variant {
	case XML_Parser_Unknown: return "unknown"
	case XML_Parser_Protocol: return "protocol"
	case XML_Parser_Copyright: return "copyright"
	case XML_Parser_Interface: return "interface"
	case XML_Parser_Description: return "description"
	case XML_Parser_Event: return "event"
	case XML_Parser_Request: return "request"
	case XML_Parser_Arg: return "arg"
	case XML_Parser_Enum: return "enum"
	case XML_Parser_Entry: return "entry"
	}
	return ""
}

@(require_results)
xml_parse_tag :: proc(
	lexer: ^XML_Lexer,
	arena_allocator := context.allocator,
	scratch_allocator := context.temp_allocator,
) -> (
	tag: XML_Parser_Tag,
	closing_tag: bool,
	error: XML_Error,
) {
	@(require_results)
	parse_tag :: proc(
		lexer: ^XML_Lexer,
		$T: typeid,
		arena_allocator := context.allocator,
		scratch_allocator := context.temp_allocator,
	) -> (
		tag: T,
		error: XML_Error,
	) where T != XML_Parser_Unknown {
		tag_ptr: [^]byte

		tag_ptr = cast([^]byte)&tag

		attribute_parse_loop: for {
			attribute: XML_Parser_Attribute
			attribute_ok: bool

			struct_field: reflect.Struct_Field
			attribute_ptr: [^]byte

			attribute, attribute_ok = xml_parse_attribute(lexer) or_return
			if attribute_ok == false {
				break
			}

			struct_field = reflect.struct_field_by_name(T, attribute.name)
			if struct_field.type == nil {
				header: string

				header = xml_parse_generate_print_header("Warning", attribute.name_location)
				fmt.eprintfln("%s Ignoring unknown attribute: \"%s\"", header, attribute.name)
			}

			attribute_ptr = tag_ptr[struct_field.offset:]
			#partial switch variant in reflect.type_info_base(struct_field.type).variant {
			case reflect.Type_Info_String:
				(cast(^string)attribute_ptr)^ = attribute.value
			case reflect.Type_Info_Integer:
				value: int
				value_convert_success: bool

				if struct_field.type.size != size_of(int) {
					header: string

					header = xml_parse_generate_print_header("Error", attribute.name_location)
					fmt.eprintfln("%s Integer in structure was %v bytes, not %v!", header, struct_field.type.size, size_of(int))
					return tag, XML_Parse_Error.Reflection_Incorrect_Integer_Size
				}

				value, value_convert_success = strconv.parse_int(attribute.value)
				if value_convert_success == false {
					header: string

					header = xml_parse_generate_print_header("Error", attribute.value_location)
					fmt.eprintfln("%s Failed to convert \"%s\" to an integer!", header, attribute.value)
					return tag, XML_Parse_Error.Integer_Cast_Failure
				}

				(cast(^int)attribute_ptr)^ = value
			case reflect.Type_Info_Union:
				value:int
				value_convert_success: bool

				if len(variant.variants) > 1 {
					header: string

					header = xml_parse_generate_print_header("Error", attribute.name_location)
					fmt.eprintfln("%s Cannot assign \"%s\" as structure is not a maybe-like!", header, attribute.name)
					return tag, XML_Parse_Error.Reflection_Union_Is_Not_Maybe_Like
				}

				if variant.variants[0].size != size_of(int) {
					header: string

					header = xml_parse_generate_print_header("Error", attribute.name_location)
					fmt.eprintfln("%s Integer in union was %v bytes, not %v!", header, variant.variants[0].size, size_of(int))
					return tag, XML_Parse_Error.Reflection_Incorrect_Integer_Size
				}
				
				value, value_convert_success = strconv.parse_int(attribute.value)
				if value_convert_success == false {
					header: string

					header = xml_parse_generate_print_header("Error", attribute.value_location)
					fmt.eprintfln("%s Failed to convert \"%s\" to an integer!", header, attribute.value)
					return tag, XML_Parse_Error.Integer_Cast_Failure
				}

				(cast(^Maybe(int))attribute_ptr)^ = value
			case:
				header: string

				header = xml_parse_generate_print_header("Error", attribute.value_location)
				fmt.eprintfln("%s Unhandled base type encountered!", header)
				return tag, XML_Parse_Error.Reflection_Unhandled_Base_Type
			}
		}

		content_parse_loop: for {
			/*
				 TODO:
				 I need to consume the content of the tag
				 and check if a new tag is starting
				 and call 'xml_parse_tag'.

				 When there is no new tag, I should collect
				 all the data into a string builder

				 All the code below should be for after calling 'xml_parse_tag'

				 Ex:
				 if not '<' then
					add content to string builder
					continue
				 end
				 xml_parse_tag
				 if closing_tag then
					break loop
				 end
				 handle tag stuff
			*/
			child_tag: XML_Parser_Tag
			child_tag_is_closing_tag: bool
			child_tag_name: string

			struct_field: reflect.Struct_Field

			child_tag, child_tag_is_closing_tag = xml_parse_tag(lexer) or_return
			child_tag_name = xml_parser_tag_variant_to_string(child_tag.variant)

			if child_tag_is_closing_tag == true {
				if _, closing_tag_is_parent_type := child_tag.variant.(T); closing_tag_is_parent_type == false {
					header: string
					expected_name: string

					expected_name = xml_parser_tag_variant_to_string(T{})

					header = xml_parse_generate_print_header("Error", child_tag.location)
					fmt.eprintfln("%s Closing tag was not expected type \"%s\", received \"%s\"", header, expected_name, child_tag_name)

					return tag, XML_Parse_Error.Unexpected_Closing_Tag
				}
				break
			}

			struct_field = reflect.struct_field_by_name(T, child_tag_name)
			if struct_field.type == nil {
				header: string
				tag_name: string

				tag_name = xml_parser_tag_variant_to_string(T{})

				header = xml_parse_generate_print_header("Warning", child_tag.location)
				fmt.eprintfln("%s \"%s\" is not a valid tag inside a \"%s\" tag!", header, child_tag_name, tag_name)
			}
		}

		return tag, nil
	}

	token: XML_Token

	context.allocator = arena_allocator
	context.temp_allocator = scratch_allocator

	assert(lexer != nil)

	non_opening_tag_parse_loop: for {
		token = xml_parse_skip_ws(lexer) or_return
		#partial switch token.type {
		case .Angle_Bracket_Left:
			token = xml_parse_skip_ws(lexer) or_return
		case .Identifier, .Forward_Slash:
			break
		case:
			xml_parse_print_error_expected(token.location, "< (or) / (or) %identifier%", token.lexeme)
			return tag, false, XML_Parse_Error.Unexpected_Token
		}
		tag.location = token.location

		#partial switch token.type {
		case .Forward_Slash:
			header: string

			token = xml_parse_skip_ws(lexer) or_return
			switch token.lexeme {
			case "protocol": tag.variant = XML_Parser_Protocol {}
			case "copyright": tag.variant = XML_Parser_Copyright {}
			case "interface": tag.variant = XML_Parser_Interface {}
			case "description": tag.variant = XML_Parser_Description {}
			case "event": tag.variant = XML_Parser_Event {}
			case "request": tag.variant = XML_Parser_Request {}
			case "arg": tag.variant = XML_Parser_Arg {}
			case "enum": tag.variant = XML_Parser_Enum {}
			case "entry": tag.variant = XML_Parser_Entry {}
			case:
				header = xml_parse_generate_print_header("Warning", token.location)
				fmt.eprintfln("%s Ignoring unknown or unexpected closing tag: </%s...", header, token.lexeme)
				
				tag.variant = XML_Parser_Unknown { tag_name = token.lexeme }
			}

			token = xml_parse_skip_ws(lexer) or_return
			if token.type != .Angle_Bracket_Right {
				xml_parse_print_error_expected(token.location, ">", token.lexeme)
				
				header = xml_parse_generate_print_header("Error", token.location)
				fmt.eprintfln("%s Closing tags should not have any attributes!")
			}

			return tag, true, nil
		case .Exclamation:
			token = xml_lexer_token_next(lexer) or_return
			if token.type != .Hyphen {
				xml_parse_print_error_expected(token.location, "-", token.lexeme)
				return tag, false, XML_Parse_Error.Unexpected_Token
			}
			token = xml_lexer_token_next(lexer) or_return
			if token.type != .Hyphen {
				xml_parse_print_error_expected(token.location, "-", token.lexeme)
				return tag, false, XML_Parse_Error.Unexpected_Token
			}
			for {
				token = xml_parse_skip_ws(lexer) or_return
				if token.type != .Hyphen {
					continue
				}
				token = xml_lexer_token_next(lexer) or_return
				if token.type != .Hyphen {
					continue
				}
				token = xml_lexer_token_next(lexer) or_return
				if token.type == .Angle_Bracket_Right {
					break
				}
			}
		case .Identifier:
			break non_opening_tag_parse_loop
		case:
			xml_parse_print_error_expected(token.location, "%identifier%", token.lexeme)
			return tag, false, XML_Parse_Error.Unexpected_Token
		}
	}

	switch token.lexeme {
	case "protocol": tag.variant = parse_tag(lexer, XML_Parser_Protocol) or_return
	case "copyright": tag.variant = parse_tag(lexer, XML_Parser_Copyright) or_return
	case "interface": tag.variant = parse_tag(lexer, XML_Parser_Interface) or_return
	case "description": tag.variant = parse_tag(lexer, XML_Parser_Description) or_return
	case "event": tag.variant = parse_tag(lexer, XML_Parser_Event) or_return
	case "request": tag.variant = parse_tag(lexer, XML_Parser_Request) or_return
	case "arg": tag.variant = parse_tag(lexer, XML_Parser_Arg) or_return
	case "enum": tag.variant = parse_tag(lexer, XML_Parser_Enum) or_return
	case "entry": tag.variant = parse_tag(lexer, XML_Parser_Entry) or_return
	case:
		header: string

		header = xml_parse_generate_print_header("Warning", token.location)
		fmt.eprintfln("%s Unknown tag: <%s...", header, tag.name)

		tag.variant = XML_Parser_Unknown { tag_name = token.lexeme }
	}

	return tag, false, nil
}

XML_Parser_Attribute :: struct {
	name: string,
	value: string,
	name_location: XML_Token_Location,
	value_location: XML_Token_Location,
}

@(require_results)
xml_parse_attribute :: proc(
	lexer: ^XML_Lexer,
	arena_allocator := context.allocator,
	scratch_allocator := context.temp_allocator,
) -> (
	attribute: XML_Parser_Attribute,
	attribute_found: bool,
	error: XML_Error,
) {
	token: XML_Token
	value_builder: strings.Builder

	context.allocator = arena_allocator
	context.temp_allocator = scratch_allocator

	assert(lexer != nil)


	token = xml_parse_skip_ws(lexer) or_return

	#partial switch token.type {
	case .Forward_Slash:
		token = xml_parse_skip_ws(lexer) or_return
		if token.type != .Angle_Bracket_Right {
			xml_parse_print_error_expected(lexer^, ">", token.lexeme)
			return {}, false, XML_Parse_Error.Unexpected_Token
		}
		fallthrough
	case .Angle_Bracket_Right:
		return {}, false, nil
	case .Identifier:
		break
	case:
		token_type_as_string: string

		token_type_as_string = fmt.tprintf("%v", token.type)
		xml_parse_print_error_expected(lexer^, "Identifier", token_type_as_string)

		return {}, false, XML_Parse_Error.Unexpected_Token
	}

	attribute.name = token.lexeme
	attribute.name_location = token.location

	token = xml_parse_skip_ws(lexer) or_return
	if token.type != .Equals {
		xml_parse_print_error_expected(lexer^, "=", token.lexeme)
		return {}, false, XML_Parse_Error.Unexpected_Token
	}
	token = xml_parse_skip_ws(lexer) or_return
	if token.type != .Double_Quotation {
		xml_parse_print_error_expected(lexer^, "\"", token.lexeme)
		return {}, false, XML_Parse_Error.Unexpected_Token
	}

	token = xml_lexer_token_next(lexer) or_return
	attribute.value_location = token.location

	value_builder = strings.builder_make_len_cap(0, 128, scratch_allocator)
	value_parse_loop: for {
		if token.type == .Double_Quotation {
			break
		}
		strings.write_string(&value_builder, token.lexeme)
		token = xml_lexer_token_next(lexer) or_return
	}
	attribute.value = strings.to_string(value_builder)
	attribute.value_location = token.location

	return attribute, true, nil
}
