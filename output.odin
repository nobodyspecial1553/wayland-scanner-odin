package ns_wayland_scanner_odin

import "base:intrinsics"

@(require) import "core:fmt"
@(require) import "core:log"
import "core:io"
import "core:strings"
import "core:mem"
import big_math "core:math/big"

log2 :: big_math.ilog2

Output_Validation_Error :: enum {
	None = 0,
	Protocol_No_Name,
	Interface_No_Name,
	Description_No_Content,
	Proc_No_Name,
	Arg_Invalid_Type,
}

Output_Error :: union #shared_nil {
	Output_Validation_Error,
	io.Error,
}

output_write_header :: proc(writer: io.Writer) -> (error: Output_Error) {
	io.write_string(writer, "package wayland_protocol\n\n") or_return
	return nil
}

output_write_protocol :: proc(
	writer: io.Writer,
	protocol: XML_Parser_Protocol,
	args: Args,
	scratch_allocator := context.temp_allocator,
) -> (
	error: Output_Error,
) {
	context.allocator = mem.panic_allocator()
	context.temp_allocator = scratch_allocator

	if .Generate_Interface_FFI in args.property_flags || .Generate_Proc_FFI in args.property_flags {
		if .Generate_Proc_FFI in args.property_flags {
			io.write_string(writer, "foreign import ") or_return
			io.write_string(writer, args.proc_ffi_name) or_return
			io.write_string(writer, " \"") or_return
			io.write_string(writer, args.proc_ffi_link_path) or_return
			io.write_string(writer, "\"\n") or_return
		}
		if .Generate_Interface_FFI in args.property_flags {
			io.write_string(writer, "foreign import ") or_return
			io.write_string(writer, args.interface_ffi_name) or_return
			io.write_string(writer, " \"") or_return
			io.write_string(writer, args.interface_ffi_link_path) or_return
			io.write_string(writer, "\"\n") or_return
		}
		io.write_rune(writer, '\n') or_return
	}

	if len(protocol.name) == 0 {
		return Output_Validation_Error.Protocol_No_Name
	}
	io.write_string(writer, "/* Protocol: ") or_return
	io.write_string(writer, protocol.name) or_return
	io.write_rune(writer, '\n') or_return

	if protocol.copyright != nil {
		for line in strings.split_lines_iterator(&protocol.copyright.content) {
			io.write_rune(writer, '\t') or_return
			io.write_string(writer, strings.trim_left(line, " \t")) or_return
			io.write_rune(writer, '\n') or_return
		}
	}
	io.write_string(writer, "*/\n\n") or_return

	for interface := protocol.interface; interface != nil; interface = interface.next {
		output_write_interface(writer, interface^, args, scratch_allocator) or_return
	}

	return nil
}

output_write_interface :: proc(
	writer: io.Writer,
	interface: XML_Parser_Interface,
	args: Args,
	scratch_allocator := context.temp_allocator,
) -> (
	error: Output_Error,
) {
	write_proc_listeners :: proc(
		writer: io.Writer,
		_proc: $T,
		interface_name: string,
		args: Args,
		scratch_allocator := context.temp_allocator,
	) -> (
		error: Output_Error,
	) where intrinsics.type_is_pointer(T), type_of(_proc._proc) == XML_Parser_Proc {
		_proc := _proc

		context.allocator = mem.panic_allocator()
		context.temp_allocator = scratch_allocator

		if _proc == nil || .Disable_Proc_Generation in args.property_flags {
			return nil
		}

		io.write_string(writer, interface_name) or_return
		io.write_string(writer, "_listener :: struct {\n") or_return
		for ; _proc != nil; _proc = _proc.next {
			if _proc.description != nil {
				io.write_string(writer, "\t/*\n") or_return
				for line in strings.split_lines_iterator(&_proc.description.content) {
					io.write_string(writer, "\t\t") or_return
					io.write_string(writer, strings.trim_left(line, " \t")) or_return
					io.write_rune(writer, '\n') or_return
				}
				io.write_string(writer, "\t*/\n") or_return
			}
			if since, since_exists := _proc.since.?; since_exists == true {
				io.write_string(writer, fmt.aprintf("\t// Since Version: %d\n", since, allocator = scratch_allocator)) or_return
			}
			if deprecated_since, deprecated_since_exists := _proc.deprecated_since.?; deprecated_since_exists == true {
				io.write_string(writer, fmt.aprintf("\t// Deprecated Since Version: %d\n", deprecated_since, allocator = scratch_allocator)) or_return
			}

			for arg := _proc.arg; arg != nil; arg = arg.next {
				since: int
				since_exists: bool
				deprecated_since: int
				deprecated_since_exists: bool

				if len(arg.summary) == 0 && arg.description == nil {
					continue
				}

				io.write_string(writer, "\t// @param '") or_return
				io.write_string(writer, arg.name) or_return
				io.write_string(writer, "' = \"") or_return
				if arg.description != nil {
					if len(arg.description.content) != 0 {
						io.write_string(writer, "\n") or_return
					}
					if len(arg.description.summary) != 0 {
						io.write_rune(writer, '\t') or_return
						if len(arg.description.content) != 0 {
							io.write_string(writer, "Summary: ") or_return
						}
						io.write_string(writer, arg.description.summary) or_return
						io.write_string(writer, "\n\n\t") or_return
					}
					for line in strings.split_lines_iterator(&arg.description.content) {
						trimmed_line: string

						trimmed_line = strings.trim_left(line, " \t")
						io.write_rune(writer, '\t') or_return
						io.write_string(writer, trimmed_line) or_return
						io.write_rune(writer, '\n') or_return
					}
				}
				else if len(arg.summary) != 0 {
					io.write_string(writer, arg.summary) or_return
				}
				io.write_rune(writer, '"') or_return

				since, since_exists = arg.since.?
				deprecated_since, deprecated_since_exists = arg.deprecated_since.?
				if since_exists || deprecated_since_exists {
					io.write_rune(writer, '(') or_return
					if since_exists == true {
						io.write_string(writer, "Since: ") or_return
						io.write_int(writer, since) or_return
					}
					if deprecated_since_exists == true {
						if since_exists {
							io.write_string(writer, "; ") or_return
						}
						io.write_string(writer, "Deprecated Since: ") or_return
						io.write_int(writer, deprecated_since) or_return
					}
					io.write_rune(writer, ')') or_return
				}

				io.write_rune(writer, '\n') or_return
			}

			io.write_rune(writer, '\t') or_return
			io.write_string(writer, _proc.name) or_return
			io.write_string(writer, ": #type proc \"c\" (") or_return
			when T == ^XML_Parser_Event {
				io.write_string(writer, "_data: rawptr, ") or_return
				io.write_string(writer, interface_name) or_return 
				io.write_string(writer, ": ^") or_return
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, "_struct") or_return
			}
			else when T == ^XML_Parser_Request {
				io.write_string(writer, "_client: ^client, _resource: ^resource") or_return
			}
			else {
				#panic("Invalid Type!")
			}

			for arg := _proc.arg; arg != nil; arg = arg.next {
				switch arg.type {
				case "int", "fd":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					io.write_string(writer, "i32") or_return
				case "uint":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					if len(arg._enum) == 0 {
						io.write_string(writer, "u32") or_return
					}
					else {
						period_index: int

						period_index = strings.index_byte(arg._enum, '.')
						if period_index < 0 {
							io.write_string(writer, interface_name) or_return
							io.write_rune(writer, '_') or_return
							io.write_string(writer, arg._enum) or_return
						}
						else {
							new_enum_string: string

							new_enum_string, _ = strings.replace_all(arg._enum, ".", "_", scratch_allocator)
							if new_enum_string[:3] == "wl_" {
								io.write_string(writer, new_enum_string[3:]) or_return
							}
							else {
								io.write_string(writer, new_enum_string) or_return
							}
						}
					}
				case "fixed":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					io.write_string(writer, "fixed") or_return
				case "string": // cstring
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					io.write_string(writer, "cstring") or_return
				case "array":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					io.write_string(writer, "^array") or_return
				case "new_id": // specific interface struct or generic interface followed by version
					if len(arg.interface) == 0 {
						when T == ^XML_Parser_Event {
							io.write_string(writer, ", ") or_return
							io.write_string(writer, arg.name) or_return
							io.write_string(writer, ": ^interface") or_return
						}
						else when T == ^XML_Parser_Request {
							io.write_string(writer, ", interface: cstring, version: u32, id: u32") or_return
						}
						else {
							#panic("Invalid Type!")
						}
					}
					else {
						when T == ^XML_Parser_Event {
							arg_interface_name: string

							if arg.interface[:3] == "wl_" {
								arg_interface_name = arg.interface[3:]
							}
							else {
								arg_interface_name = arg.interface
							}

							io.write_string(writer, ", ") or_return
							io.write_string(writer, arg.name) or_return
							io.write_string(writer, ": ^") or_return
							io.write_string(writer, arg_interface_name) or_return
						}
						else when T == ^XML_Parser_Request {
							io.write_string(writer, ", ") or_return
							io.write_string(writer, arg.name) or_return
							io.write_string(writer, ": u32") or_return
						}
						else {
							#panic("Invalid Type!")
						}
					}
				case "object":
					when T == ^XML_Parser_Event {
						io.write_string(writer, ", ") or_return
						io.write_string(writer, arg.name) or_return
						io.write_string(writer, ": ^") or_return
						if len(arg.interface) == 0 {
							io.write_string(writer, "object") or_return
						}
						else {
							arg_interface_name: string

							if arg.interface[:3] == "wl_" {
								arg_interface_name = arg.interface[3:]
							}
							else {
								arg_interface_name = arg.interface
							}

							io.write_string(writer, arg_interface_name) or_return
						}
					}
					else when T == ^XML_Parser_Request {
						io.write_string(writer, ", ") or_return
						io.write_string(writer, arg.name) or_return
						io.write_string(writer, ": ^resource") or_return
					}
					else {
						#panic("Invalid Type!")
					}
				case:
					fmt.eprintfln("Invalid Arg Type: %s", arg.type)
					return Output_Validation_Error.Arg_Invalid_Type
				}
			}

			io.write_rune(writer, ')') or_return

			io.write_string(writer, ",\n") or_return
		}
		io.write_string(writer, "}\n") or_return

		when T == ^XML_Parser_Event {
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, "_add_listener :: proc \"c\" (") or_return
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, ": ^") or_return
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, ", ") or_return
			io.write_string(writer, "listener: ^") or_return
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, "_listener, data: rawptr) -> (success: i32) {\n\treturn proxy_add_listener(cast(^proxy)") or_return
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, ", cast(^rawptr)listener, data)\n}\n\n") or_return
		}
		else when T == ^XML_Parser_Request {
			io.write_rune(writer, '\n') or_return
		}
		else {
			#panic("Invalid Type!")
		}

		return nil
	}
	write_proc_interfaces :: proc(
		writer: io.Writer,
		_proc: $T,
		interface_name: string,
		args: Args,
		scratch_allocator := context.temp_allocator,
	) -> (
		error: Output_Error,
	) where intrinsics.type_is_pointer(T), type_of(_proc._proc) == XML_Parser_Proc {
		has_destroy_request: bool
		proc_index: int

		_proc := _proc

		context.allocator = mem.panic_allocator()
		context.temp_allocator = scratch_allocator

		if _proc == nil || .Disable_Proc_Generation in args.property_flags {
			return nil
		}
		
		if .Generate_Proc_FFI in args.property_flags {
			if len(args.proc_ffi_link_prefix) != 0 {
				io.write_string(writer, "@(link_prefix=\"") or_return
				io.write_string(writer, args.proc_ffi_link_prefix) or_return
				io.write_string(writer, "\")\n") or_return
			}
			io.write_string(writer, "foreign ") or_return
			io.write_string(writer, args.proc_ffi_name) or_return
			io.write_string(writer, " {\n") or_return
		}

		for ; _proc != nil; _proc = _proc.next {
			when T == ^XML_Parser_Request {
				ret_arg: ^XML_Parser_Arg
			}
			proc_index_name_string: string

			if _proc.name == "destroy" {
				has_destroy_request = true
			}

			if _proc.description != nil {
				io.write_string(writer, "/*\n") or_return
				if len(_proc.description.summary) != 0 {
					io.write_string(writer, "\tSummary: ") or_return
					io.write_string(writer, _proc.description.summary) or_return
					io.write_rune(writer, '\n') or_return
					if len(_proc.description.content) != 0 {
						io.write_rune(writer, '\n') or_return
					}
				}
				for line in strings.split_lines_iterator(&_proc.description.content) {
					io.write_rune(writer, '\t') or_return
					io.write_string(writer, strings.trim_left(line, " \t")) or_return
					io.write_rune(writer, '\n') or_return
				}
				io.write_string(writer, "*/\n") or_return
			}
			if since, since_exists := _proc.since.?; since_exists == true {
				io.write_string(writer, "// Since Version: ") or_return
				io.write_int(writer, since) or_return
				io.write_rune(writer, '\n') or_return
			}
			if deprecated_since, deprecated_since_exists := _proc.deprecated_since.?; deprecated_since_exists == true {
				io.write_string(writer, "// Deprecated Since Version: ") or_return
				io.write_int(writer, deprecated_since) or_return
				io.write_rune(writer, '\n') or_return
			}

			if _proc.arg != nil {
				for arg := _proc.arg; arg != nil; arg = arg.next {
					since: int
					since_exists: bool
					deprecated_since: int
					deprecated_since_exists: bool

					if len(arg.summary) == 0 && arg.description == nil {
						continue
					}

					io.write_string(writer, "/* @param '") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, "' = \"") or_return
					if arg.description != nil {
						if len(arg.description.content) != 0 {
							io.write_string(writer, "\n") or_return
						}
						if len(arg.description.summary) != 0 {
							io.write_rune(writer, '\t') or_return
							if len(arg.description.content) != 0 {
								io.write_string(writer, "Summary: ") or_return
							}
							io.write_string(writer, arg.description.summary) or_return
							io.write_string(writer, "\n\n\t") or_return
						}
						for line in strings.split_lines_iterator(&arg.description.content) {
							trimmed_line: string

							trimmed_line = strings.trim_left(line, " \t")
							io.write_rune(writer, '\t') or_return
							io.write_string(writer, trimmed_line) or_return
							io.write_rune(writer, '\n') or_return
						}
					}
					else if len(arg.summary) != 0 {
						io.write_string(writer, arg.summary) or_return
					}
					io.write_string(writer, "\"") or_return

					since, since_exists = arg.since.?
					deprecated_since, deprecated_since_exists = arg.deprecated_since.?
					if since_exists || deprecated_since_exists {
						io.write_rune(writer, '(') or_return
						if since_exists == true {
							io.write_string(writer, "Since: ") or_return
							io.write_int(writer, since) or_return
						}
						if deprecated_since_exists == true {
							if since_exists {
								io.write_string(writer, "; ") or_return
							}
							io.write_string(writer, "Deprecated Since: ") or_return
							io.write_int(writer, deprecated_since) or_return
						}
						io.write_rune(writer, ')') or_return
					}

					io.write_string(writer, " */\n") or_return
				}
			}

			{
				string_arena: mem.Arena
				string_arena_allocator: mem.Allocator
				interface_constant_string_builder: strings.Builder

				mem.arena_init(&string_arena, new([2048]byte, scratch_allocator)[:])
				string_arena_allocator = mem.arena_allocator(&string_arena)

				interface_constant_string_builder = strings.builder_make_len_cap(0, len(interface_name) + len(_proc.name), string_arena_allocator)

				strings.write_string(&interface_constant_string_builder, strings.to_screaming_snake_case(interface_name, string_arena_allocator))
				strings.write_rune(&interface_constant_string_builder, '_')
				strings.write_string(&interface_constant_string_builder, strings.to_screaming_snake_case(_proc.name, string_arena_allocator))

				proc_index_name_string = strings.to_string(interface_constant_string_builder)

				if .Generate_Proc_FFI not_in args.property_flags {
					io.write_string(writer, proc_index_name_string) or_return
					io.write_string(writer, " :: ") or_return
					io.write_int(writer, proc_index) or_return
					io.write_rune(writer, '\n') or_return
				}

				proc_index += 1
			}

			when T == ^XML_Parser_Request {
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, "_request_") or_return
				io.write_string(writer, _proc.name) or_return
				io.write_string(writer, " :: proc \"c\" (") or_return
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, ": ^") or_return
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, "_struct") or_return
			}
			else when T == ^XML_Parser_Event {
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, "_send_") or_return
				io.write_string(writer, _proc.name) or_return
				io.write_string(writer, " :: proc \"c\" (_resource: ^resource") or_return
			}
			else {
				#panic("Invalid Type!")
			}

			for arg := _proc.arg; arg != nil; arg = arg.next {
				switch arg.type {
				case "int", "fd":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					io.write_string(writer, "i32") or_return
				case "uint":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					if len(arg._enum) == 0 {
						io.write_string(writer, "u32") or_return
					}
					else {
						period_index: int

						period_index = strings.index_byte(arg._enum, '.')
						if period_index < 0 {
							io.write_string(writer, interface_name) or_return
							io.write_rune(writer, '_') or_return
							io.write_string(writer, arg._enum) or_return
						}
						else {
							new_enum_string: string

							new_enum_string, _ = strings.replace_all(arg._enum, ".", "_", scratch_allocator)
							if new_enum_string[:3] == "wl_" {
								io.write_string(writer, new_enum_string[3:]) or_return
							}
							else {
								io.write_string(writer, new_enum_string) or_return
							}
						}
					}
				case "fixed":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": fixed") or_return
				case "string": // cstring
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": cstring") or_return
				case "array":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ^array") or_return
				case "new_id": // specific interface struct or generic interface followed by version
					when T == ^XML_Parser_Request {
						ret_arg = arg

						if len(arg.interface) == 0 {
							io.write_string(writer, ", interface: ^interface, version: u32") or_return
						}
					}
					else when T == ^XML_Parser_Event {
						io.write_string(writer, ", ") or_return
						io.write_string(writer, arg.name) or_return
						io.write_string(writer, ": ^resource") or_return
					}
					else {
						#panic("Invalid Type!")
					}
				case "object":
					io.write_string(writer, ", ") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, ": ") or_return
					when T == ^XML_Parser_Request {
						if len(arg.interface) == 0 {
							io.write_string(writer, "^object") or_return
						}
						else {
							arg_interface_name: string
							io.write_rune(writer, '^') or_return
							if arg.interface[:3] == "wl_" {
								arg_interface_name = arg.interface[3:]
							}
							else {
								arg_interface_name = arg.interface
							}
							io.write_string(writer, arg_interface_name) or_return
							io.write_string(writer, "_struct") or_return
						}
					}
					else when T == ^XML_Parser_Event {
						io.write_string(writer, "^resource") or_return
					}
					else {
						#panic("Invalid Type!")
					}
				case:
					fmt.eprintfln("Invalid Arg Type: %s", arg.type)
					return Output_Validation_Error.Arg_Invalid_Type
				}
			}
			io.write_string(writer, ")") or_return
			when T == ^XML_Parser_Request {
				if ret_arg != nil {
					io.write_string(writer, " -> (") or_return
					io.write_string(writer, ret_arg.name) or_return
					io.write_string(writer, ": ") or_return
					if len(ret_arg.interface) != 0 {
						ret_arg_interface_name: string

						io.write_rune(writer, '^') or_return
						if ret_arg.interface[:3] == "wl_" {
							ret_arg_interface_name = ret_arg.interface[3:]
						}
						else {
							ret_arg_interface_name = ret_arg.interface
						}
						io.write_string(writer, ret_arg_interface_name) or_return
						io.write_rune(writer, ')') or_return
					}
					else {
						io.write_string(writer, "rawptr)") or_return
					}
				}
			}
			if .Generate_Proc_FFI in args.property_flags {
				io.write_string(writer, " ---\n") or_return
				continue
			}
			io.write_string(writer, " {\n\t") or_return
			when T == ^XML_Parser_Request {
				if ret_arg != nil {
					io.write_string(writer, "return cast(") or_return
					if len(ret_arg.interface) == 0 {
						io.write_string(writer, "rawptr)") or_return
					}
					else {
						ret_arg_interface_name: string

						io.write_rune(writer, '^') or_return
						if ret_arg.interface[:3] == "wl_" {
							ret_arg_interface_name = ret_arg.interface[3:]
						}
						else {
							ret_arg_interface_name = ret_arg.interface
						}
						io.write_string(writer, ret_arg_interface_name) or_return
						io.write_string(writer, "_struct") or_return // Resolves potential naming conflicts
						io.write_rune(writer, ')') or_return
					}
				}
				io.write_string(writer, "proxy_marshal_flags(cast(^proxy)") or_return
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, ", ") or_return
				io.write_string(writer, proc_index_name_string) or_return
				io.write_string(writer, ", ") or_return
				if ret_arg != nil {
					if len(ret_arg.interface) == 0 {
						io.write_string(writer, "interface, version") or_return
					}
					else {
						ret_arg_interface_name: string

						if ret_arg.interface[:3] == "wl_" {
							ret_arg_interface_name = ret_arg.interface[3:]
						}
						else {
							ret_arg_interface_name = ret_arg.interface
						}
						io.write_rune(writer, '&') or_return
						io.write_string(writer, ret_arg_interface_name) or_return
						io.write_string(writer, "_interface, ") or_return
						io.write_string(writer, "proxy_get_version(cast(^proxy)") or_return
						io.write_string(writer, interface_name) or_return
						io.write_rune(writer, ')') or_return
					}
				}
				else {
					io.write_string(writer, "nil, ") or_return
					io.write_string(writer, "proxy_get_version(cast(^proxy)") or_return
					io.write_string(writer, interface_name) or_return
					io.write_rune(writer, ')') or_return
				}
				switch _proc.type {
				case "destructor":
					io.write_string(writer, ", MARSHAL_FLAG_DESTROY") or_return
				case "":
					io.write_string(writer, ", 0") or_return
				case:
					fmt.eprintfln("Invalid Proc Type: ", _proc.type)
					return Output_Validation_Error.Arg_Invalid_Type
				}
			}
			else when T == ^XML_Parser_Event {
				io.write_string(writer, "resource_post_event(resource, ") or_return
				io.write_string(writer, proc_index_name_string) or_return
			}
			else {
				#panic("Invalid Type!")
			}
			for arg := _proc.arg; arg != nil; arg = arg.next {
				io.write_string(writer, ", ") or_return
				switch arg.type {
				case "new_id":
					when T == ^XML_Parser_Request {
						if len(arg.interface) == 0 {
							io.write_string(writer, "interface.name, version, nil") or_return
							break
						}
						else {
							io.write_string(writer, "nil") or_return
						}
					}
					else when T == ^XML_Parser_Event {
						fallthrough
					}
					else {
						#panic("Invalid Type!")
					}
				case:
					io.write_string(writer, arg.name) or_return
				}
			}
			io.write_string(writer, ")\n}\n\n") or_return
		}

		when T == ^XML_Parser_Request {
			if has_destroy_request == false {
				if .Generate_Proc_FFI in args.property_flags && len(args.proc_ffi_link_prefix) != 0 {
					io.write_string(writer, "@(link_prefix=\"") or_return
					io.write_string(writer, args.proc_ffi_link_prefix) or_return
					io.write_string(writer, "\")\n") or_return
				}
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, "_request_destroy :: proc \"c\" (") or_return
				io.write_string(writer, interface_name) or_return
				io.write_string(writer, ": ^") or_return
				io.write_string(writer, interface_name) or_return
				if .Generate_Proc_FFI in args.property_flags {
					io.write_string(writer, ") ---\n") or_return
				}
				else {
					io.write_string(writer, ") {\n\tproxy_destroy(cast(^proxy)") or_return
					io.write_string(writer, interface_name) or_return
					io.write_string(writer, ")\n}\n") or_return
				}
			}
		}

		if .Generate_Proc_FFI in args.property_flags {
			io.write_string(writer, "}\n") or_return
		}

		io.write_rune(writer, '\n') or_return
		return nil
	}

	interface_name: string

	if len(interface.name) == 0 {
		return Output_Validation_Error.Interface_No_Name
	}
	if interface.name[:3] == "wl_" {
		interface_name = interface.name[3:]
	}
	else {
		interface_name = interface.name
	}

	io.write_string(writer, "/* Interface: ") or_return
	io.write_string(writer, interface.name) or_return
	io.write_string(writer, " - version: ") or_return
	io.write_int(writer, interface.version) or_return
	io.write_rune(writer, '\n') or_return

	if interface.description != nil {
		for line in strings.split_lines_iterator(&interface.description.content) {
			io.write_rune(writer, '\t') or_return
			io.write_string(writer, strings.trim_left(line, " \t")) or_return
			io.write_rune(writer, '\n') or_return
		}
	}

	io.write_string(writer, "*/\n\n") or_return

	io.write_string(writer, interface_name) or_return
	io.write_string(writer, " :: struct {}\n") or_return
	io.write_string(writer, interface_name) or_return
	io.write_string(writer, "_struct :: ") or_return
	io.write_string(writer, interface_name) or_return
	io.write_string(writer, "\n\n") or_return

	if .Disable_Interface_Generation not_in args.property_flags {
		method_count: int
		event_count: int

		if interface.request != nil && .Generate_Interface_FFI not_in args.property_flags {
			io.write_string(writer, fmt.aprintf("%s_requests := [?]message {{\n", interface.name, allocator = scratch_allocator)) or_return
			for request := interface.request; request != nil; request = request.next {
				method_count += 1
				io.write_string(writer, "\t{ \"") or_return
				io.write_string(writer, request.name) or_return
				io.write_string(writer, "\", \"") or_return
				if since, since_exists := request.since.?; since_exists == true && since > 1 {
					io.write_int(writer, since) or_return
				}
				for arg := request.arg; arg != nil; arg = arg.next {
					if arg.allow_null == true {
						io.write_rune(writer, '?') or_return
					}
					switch arg.type {
					case "int": io.write_rune(writer, 'i') or_return
					case "uint": io.write_rune(writer, 'u') or_return
					case "fixed": io.write_rune(writer, 'f') or_return
					case "string": io.write_rune(writer, 's') or_return
					case "object":
						if len(arg.interface) == 0 {
							io.write_string(writer, "suo") or_return
						}
						else {
							io.write_rune(writer, 'o') or_return
						}
					case "new_id":
						if len(arg.interface) == 0 {
							io.write_string(writer, "sun") or_return
						}
						else {
							io.write_rune(writer, 'n') or_return
						}
					case "array": io.write_rune(writer, 'a') or_return
					case "fd": io.write_rune(writer, 'h') or_return
					}
				}
				io.write_string(writer, "\", raw_data(&[?]^interface {") or_return
				if request.arg != nil {
					io.write_rune(writer, ' ') or_return
					for arg := request.arg; arg != nil; {
						switch arg.type {
						case "new_id", "object":
							if len(arg.interface) == 0 {
								io.write_string(writer, "nil, nil, nil") or_return
							}
							else {
								request_interface_name: string
								if arg.interface[:3] == "wl_" {
									request_interface_name = arg.interface[3:]
								}
								else {
									request_interface_name = arg.interface
								}
								io.write_string(writer, fmt.aprintf("&%s_interface", request_interface_name, allocator = scratch_allocator)) or_return
							}
						case:
							io.write_string(writer, "nil") or_return
						}

						if arg.next == nil {
							break
						}
						else {
							arg = arg.next
							io.write_string(writer, ", ") or_return
						}
					}
					io.write_rune(writer, ' ') or_return
				}
				io.write_string(writer, "}) },\n") or_return
			}
			io.write_string(writer, "}\n") or_return
		}

		if interface.event != nil && .Generate_Interface_FFI not_in args.property_flags {
			io.write_string(writer, fmt.aprintf("%s_events := [?]message {{\n", interface.name, allocator = scratch_allocator)) or_return
			for event := interface.event; event != nil; event = event.next {
				event_count += 1
				io.write_string(writer, "\t{ \"") or_return
				io.write_string(writer, event.name) or_return
				io.write_string(writer, "\", \"") or_return
				if since, since_exists := event.since.?; since_exists == true && since > 1 {
					io.write_int(writer, since) or_return
				}
				for arg := event.arg; arg != nil; arg = arg.next {
					if arg.allow_null == true {
						io.write_rune(writer, '?') or_return
					}
					switch arg.type {
					case "int": io.write_rune(writer, 'i') or_return
					case "uint": io.write_rune(writer, 'u') or_return
					case "fixed": io.write_rune(writer, 'f') or_return
					case "string": io.write_rune(writer, 's') or_return
					case "object":
						if len(arg.interface) == 0 {
							io.write_string(writer, "suo") or_return
						}
						else {
							io.write_rune(writer, 'o') or_return
						}
					case "new_id":
						if len(arg.interface) == 0 {
							io.write_string(writer, "sun") or_return
						}
						else {
							io.write_rune(writer, 'n') or_return
						}
					case "array": io.write_rune(writer, 'a') or_return
					case "fd": io.write_rune(writer, 'h') or_return
					}
				}
				io.write_string(writer, "\", raw_data(&[?]^interface {") or_return
				if event.arg != nil {
					io.write_rune(writer, ' ') or_return
					for arg := event.arg; arg != nil; {
						switch arg.type {
						case "new_id", "object":
							if len(arg.interface) == 0 {
								io.write_string(writer, "nil, nil, nil") or_return
							}
							else {
								event_interface_name: string
								if arg.interface[:3] == "wl_" {
									event_interface_name = arg.interface[3:]
								}
								else {
									event_interface_name = arg.interface
								}
								io.write_string(writer, fmt.aprintf("&%s_interface", event_interface_name, allocator = scratch_allocator)) or_return
							}
						case:
							io.write_string(writer, "nil") or_return
						}

						if arg.next == nil {
							break
						}
						else {
							arg = arg.next
							io.write_string(writer, ", ") or_return
						}
					}
					io.write_rune(writer, ' ') or_return
				}
				io.write_string(writer, "}) },\n") or_return
			}
			io.write_string(writer, "}\n") or_return
		}

		if .Generate_Interface_FFI in args.property_flags {
			if len(args.interface_ffi_link_prefix) != 0 {
				io.write_string(writer, "@(link_prefix=\"") or_return
				io.write_string(writer, args.interface_ffi_link_prefix) or_return
				io.write_string(writer, "\")\n") or_return
			}
			io.write_string(writer, "foreign ") or_return
			io.write_string(writer, args.interface_ffi_name) or_return
			io.write_string(writer, " {\n") or_return
			io.write_string(writer, interface_name) or_return
			io.write_string(writer, "_interface: interface\n") or_return
			io.write_string(writer, "}\n\n") or_return
		}
		else {
			io.write_string(writer, fmt.aprintf("%s_interface := interface {{\n\tname = \"%s\",\n\tversion = %d,\n", interface_name, interface.name, interface.version, allocator = scratch_allocator)) or_return
			io.write_string(writer, "\tmethod_count = ") or_return
			io.write_int(writer, method_count) or_return
			io.write_string(writer, ",\n\tmethods = ") or_return
			if method_count <= 0 {
				io.write_string(writer, "nil,\n") or_return
			}
			else {
				io.write_string(writer, fmt.aprintf("raw_data(&%s_requests),\n", interface.name, allocator = scratch_allocator)) or_return
			}
			io.write_string(writer, "\tevent_count = ") or_return
			io.write_int(writer, event_count) or_return
			io.write_string(writer, ",\n\tevents = ") or_return
			if event_count <= 0 {
				io.write_string(writer, "nil,\n") or_return
			}
			else {
				io.write_string(writer, fmt.aprintf("raw_data(&%s_events),\n", interface.name, allocator = scratch_allocator)) or_return
			}

			io.write_string(writer, "}\n\n") or_return
		}
	}

	if .Is_Server not_in args.property_flags && .Disable_Proc_Generation not_in args.property_flags{
		if .Generate_Proc_FFI in args.property_flags {
			if len(args.proc_ffi_link_prefix) != 0 {
				io.write_string(writer, "@(link_prefix=\"") or_return
				io.write_string(writer, args.proc_ffi_link_prefix) or_return
				io.write_string(writer, "\")\n") or_return
			}
			io.write_string(writer, "foreign ") or_return
			io.write_string(writer, args.proc_ffi_name) or_return
			io.write_string(writer, " {\n") or_return
		}

		io.write_string(writer, fmt.aprintf("%s_set_user_data :: proc \"c\" (%s: ^%s, user_data: rawptr)", interface_name, interface_name, interface_name, allocator = scratch_allocator)) or_return
		if .Generate_Proc_FFI not_in args.property_flags {
			io.write_string(writer, fmt.aprintf(" {{\n\tproxy_set_user_data(cast(^proxy)%s, user_data)\n}}\n\n", interface_name, allocator = scratch_allocator)) or_return
		}
		else {
			io.write_string(writer, " ---\n") or_return
		}

		io.write_string(writer, fmt.aprintf("%s_get_user_data :: proc \"c\" (%s: ^%s) -> (user_data: rawptr)", interface_name, interface_name, interface_name, allocator = scratch_allocator)) or_return
		if .Generate_Proc_FFI not_in args.property_flags {
			io.write_string(writer, fmt.aprintf(" {{\n\treturn proxy_get_user_data(cast(^proxy)%s)\n}}\n\n", interface_name, allocator = scratch_allocator)) or_return
		}
		else {
			io.write_string(writer, " ---\n") or_return
		}

		io.write_string(writer, fmt.aprintf("%s_get_version :: proc \"c\" (%s: ^%s) -> (version: u32)", interface_name, interface_name, interface_name, allocator = scratch_allocator)) or_return
		if .Generate_Proc_FFI not_in args.property_flags {
			io.write_string(writer, fmt.aprintf(" {{\n\treturn proxy_get_version(cast(^proxy)%s)\n}}\n\n", interface_name, allocator = scratch_allocator)) or_return
		}
		else {
			io.write_string(writer, " ---\n") or_return
		}

		if .Generate_Proc_FFI in args.property_flags {
			io.write_string(writer, "}\n\n") or_return
		}
	}

	if .Disable_Proc_Generation not_in args.property_flags {
		for _enum := interface._enum; _enum != nil; _enum = _enum.next {
			enum_name: string

			if _enum.name[:3] == "wl_" {
				enum_name = _enum.name[3:]
			}
			else {
				enum_name = _enum.name
			}

			if _enum.description != nil {
				io.write_string(writer, "/*\n") or_return
				for line in strings.split_lines_iterator(&_enum.description.content) {
					io.write_rune(writer, '\t') or_return
					io.write_string(writer, strings.trim_left(line, " \t")) or_return
					io.write_rune(writer, '\n') or_return
				}
				io.write_string(writer, "*/\n") or_return
			}
			if since, since_exists := _enum.since.?; since_exists == true {
				io.write_string(writer, "// Since Version: ") or_return
				io.write_int(writer, since) or_return
				io.write_rune(writer, '\n') or_return
			}
			if deprecated_since, deprecated_since_exists := _enum.deprecated_since.?; deprecated_since_exists == true {
				io.write_string(writer, "// Deprecated Since Version: ") or_return
				io.write_int(writer, deprecated_since) or_return
				io.write_rune(writer, '\n') or_return
			}
			if _enum.bitfield == true {
				io.write_string(writer, fmt.aprintf("%s_%s :: bit_set[%s_%s_flag; u32]\n", interface_name, enum_name, interface_name, enum_name, allocator = scratch_allocator)) or_return
			}
			io.write_string(writer, interface_name) or_return
			io.write_rune(writer, '_') or_return
			io.write_string(writer, enum_name) or_return
			if _enum.bitfield == true {
				io.write_string(writer, "_flag") or_return
			}
			io.write_string(writer, " :: enum u32 {\n") or_return
			for entry := _enum.entry; entry != nil; entry = entry.next {
				entry_name: string

				if entry.description != nil {
					io.write_string(writer, "\t/*\n") or_return
					if len(entry.description.summary) != 0 {
						io.write_string(writer, "\t\tSummary: ") or_return
						io.write_string(writer, entry.description.summary) or_return
						io.write_rune(writer, '\n') or_return
						if len(entry.description.content) != 0 {
							io.write_rune(writer, '\n')
						}
					}
					for line in strings.split_lines_iterator(&entry.description.content) {
						trimmed_line: string

						trimmed_line = strings.trim_left(line, " \t")
						io.write_string(writer, "\t\t") or_return
						io.write_string(writer, trimmed_line) or_return
						io.write_rune(writer, '\n') or_return
					}
					io.write_string(writer, "\t*/\n") or_return
				}
				else if len(entry.summary) != 0 {
					io.write_string(writer, "\t/*\n") or_return
					for line in strings.split_lines_iterator(&entry.summary) {
						trimmed_line: string

						trimmed_line = strings.trim_left(line, " \t")
						io.write_string(writer, "\t\t Summary: ") or_return
						io.write_string(writer, trimmed_line) or_return
						io.write_rune(writer, '\n') or_return
					}
					io.write_string(writer, "\t*/\n") or_return
				}

				if since, since_exists := entry.since.?; since_exists == true {
					io.write_rune(writer, '\t') or_return
					io.write_string(writer, "// Since Version: ") or_return
					io.write_int(writer, since) or_return
					io.write_rune(writer, '\n') or_return
				}
				if deprecated_since, deprecated_since_exists := entry.deprecated_since.?; deprecated_since_exists == true {
					io.write_rune(writer, '\t') or_return
					io.write_string(writer, "// Deprecated Since Version: ") or_return
					io.write_int(writer, deprecated_since) or_return
					io.write_rune(writer, '\n') or_return
				}
				entry_name, _ = strings.to_screaming_snake_case(entry.name, scratch_allocator)
				io.write_rune(writer, '\t') or_return
				switch entry_name[0] {
				case '0'..='9':
					io.write_rune(writer, '_') or_return
				}
				io.write_string(writer, entry_name) or_return
				io.write_string(writer, " = ") or_return
				if _enum.bitfield == false {
					io.write_int(writer, entry.value)
				}
				else {
					io.write_int(writer, log2(entry.value))
				}
				io.write_string(writer, ",\n") or_return
			}
			io.write_string(writer, "}\n") or_return
			if .Is_Server not_in args.property_flags {
				io.write_rune(writer, '\n') or_return
			}
			else {
				io.write_string(writer, interface_name) or_return
				io.write_rune(writer, '_') or_return
				io.write_string(writer, _enum.name) or_return
				io.write_string(writer, "_is_valid :: proc \"c\" (value: ") or_return
				io.write_string(writer, interface_name) or_return
				io.write_rune(writer, '_') or_return
				io.write_string(writer, _enum.name) or_return
				io.write_string(writer, ", version: u32) -> (valid: bool) {\n\tswitch value {\n") or_return
				for entry := _enum.entry; entry != nil; entry = entry.next {
					io.write_string(writer, "\tcase .") or_return
					io.write_string(writer, strings.to_screaming_snake_case(entry.name, scratch_allocator)) or_return
					io.write_string(writer, ": return version >= ") or_return
					if since, since_exists := entry.since.?; since_exists == true {
						io.write_int(writer, since) or_return
					}
					else {
						io.write_rune(writer, '1') or_return
					}
					if deprecated_since, deprecated_since_exists := entry.deprecated_since.?; deprecated_since_exists == true {
						io.write_string(writer, " && version < ") or_return
						io.write_int(writer, deprecated_since) or_return
					}
					io.write_rune(writer, '\n') or_return
				}
				io.write_string(writer, "\tcase:\n\t\treturn false\n") or_return
				io.write_string(writer, "\t}\n}\n\n") or_return
			}
		}
	}

	if .Is_Server in args.property_flags {
		write_proc_listeners(writer, interface.request, interface_name, args, scratch_allocator) or_return
		write_proc_interfaces(writer, interface.event, interface_name, args, scratch_allocator) or_return
	}
	else {
		write_proc_listeners(writer, interface.event, interface_name, args, scratch_allocator) or_return
		write_proc_interfaces(writer, interface.request, interface_name, args, scratch_allocator) or_return
	}

	return nil
}
