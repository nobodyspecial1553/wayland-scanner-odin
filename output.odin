package ns_wayland_scanner_odin

import "base:intrinsics"

@(require) import "core:fmt"
@(require) import "core:log"
import "core:io"
import "core:strings"
import "core:mem"

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
		scratch_allocator := context.temp_allocator,
	) -> (
		error: Output_Error,
	) where intrinsics.type_is_pointer(T), type_of(_proc._proc) == XML_Parser_Proc {
		_proc := _proc

		context.allocator = mem.panic_allocator()
		context.temp_allocator = scratch_allocator

		if _proc == nil {
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
				if len(arg.summary) != 0 {
					since: int
					since_exists: bool
					deprecated_since: int
					deprecated_since_exists: bool

					io.write_string(writer, "\t// @param '") or_return
					io.write_string(writer, arg.name) or_return
					io.write_string(writer, "' = \"") or_return
					io.write_string(writer, arg.summary) or_return
					io.write_rune(writer, '"') or_return

					since, since_exists = arg.since.?
					deprecated_since, deprecated_since_exists = arg.deprecated_since.?
					if since_exists || deprecated_since_exists {
						io.write_rune(writer, '(') or_return
						if since_exists {
							io.write_string(writer, "Since: ") or_return
							io.write_int(writer, since) or_return
						}
						if deprecated_since_exists {
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
			}

			io.write_rune(writer, '\t') or_return
			io.write_string(writer, _proc.name) or_return
			io.write_string(writer, " :: #type proc \"c\" (data: rawptr, ") or_return
			io.write_string(writer, interface_name) or_return 
			io.write_string(writer, ": ^") or_return
			io.write_string(writer, interface_name) or_return

			for arg := _proc.arg; arg != nil; arg = arg.next {
				io.write_string(writer, ", ") or_return
				io.write_string(writer, arg.name) or_return
				io.write_string(writer, ": ") or_return

				switch arg.type {
				case "int", "fd":
					io.write_string(writer, "i32") or_return
				case "uint":
					if len(arg._enum) == 0 {
						io.write_string(writer, "u32") or_return
					}
					else {
						io.write_string(writer, interface_name) or_return
						io.write_rune(writer, '_') or_return
						io.write_string(writer, arg._enum) or_return
					}
				case "fixed":
					io.write_string(writer, "fixed") or_return
				case "string": // cstring
					io.write_string(writer, "cstring") or_return
				case "array":
					io.write_string(writer, "^array") or_return
				case "new_id": // specific interface struct or generic interface followed by version
					if len(arg.interface) == 0 {
						io.write_string(writer, "^interface") or_return
					}
					else {
						io.write_rune(writer, '^') or_return
						io.write_string(writer, arg.interface) or_return
					}
				case "object":
					if len(arg.interface) == 0 {
						io.write_string(writer, "^object") or_return
					}
					else {
						io.write_rune(writer, '^') or_return
						io.write_string(writer, arg.interface) or_return
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

		io.write_string(writer, interface_name) or_return
		io.write_string(writer, "_add_listener :: proc(") or_return
		io.write_string(writer, interface_name) or_return
		io.write_string(writer, ": ^") or_return
		io.write_string(writer, interface_name) or_return
		io.write_string(writer, ", ") or_return
		io.write_string(writer, "listener: ^") or_return
		io.write_string(writer, interface_name) or_return
		io.write_string(writer, "_listener, data: rawptr) -> (success: i32) {\n\treturn proxy_add_listener(cast(^proxy)") or_return
		io.write_string(writer, interface_name) or_return
		io.write_string(writer, ", cast(^rawptr)listener, data)\n}\n\n") or_return

		return nil
	}
	write_proc_interfaces :: proc(
		writer: io.Writer,
		_proc: $T,
		interface_name: string,
		scratch_allocator := context.temp_allocator,
	) -> (
		error: Output_Error,
	) where intrinsics.type_is_pointer(T), type_of(_proc._proc) == XML_Parser_Proc {
		context.allocator = mem.panic_allocator()
		context.temp_allocator = scratch_allocator

		if _proc == nil {
			return nil
		}
		// TODO:
		/*
			 Note: If an interface doesn't have a destroy request,
				it is worth generating a destroy request regardless,
				and using wl_proxy_destroy
		*/
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

	io.write_string(writer, fmt.aprintf("%s_set_user_data :: proc(%s: ^%s, user_data: rawptr) {{\n", interface_name, interface.name, interface_name, allocator = scratch_allocator)) or_return
	io.write_string(writer, fmt.aprintf("\tproxy_set_user_data((^proxy)%s, user_data)\n}}\n\n", interface.name, allocator = scratch_allocator)) or_return

	io.write_string(writer, fmt.aprintf("%s_get_user_data :: proc(%s: ^%s) -> (user_data: rawptr) {{\n", interface_name, interface.name, interface_name, allocator = scratch_allocator)) or_return
	io.write_string(writer, fmt.aprintf("\treturn proxy_get_user_data((^proxy)%s)\n}}\n\n", interface.name, allocator = scratch_allocator)) or_return

	io.write_string(writer, fmt.aprintf("%s_get_version :: proc(%s: ^%s) -> (version: u32) {{\n", interface_name, interface.name, interface_name, allocator = scratch_allocator)) or_return
	io.write_string(writer, fmt.aprintf("\treturn proxy_get_version((^proxy)%s)\n}}\n\n", interface.name, allocator = scratch_allocator)) or_return

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

			if len(entry.summary) != 0 {
				io.write_string(writer, "\t/*\n") or_return
				for line in strings.split_lines_iterator(&entry.summary) {
					io.write_string(writer, "\t\t") or_return
					io.write_string(writer, line) or_return
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
			io.write_string(writer, fmt.aprintf("\t%s = %d,\n", entry_name, entry.value, allocator = scratch_allocator)) or_return
		}
		io.write_string(writer, "}\n\n") or_return
	}

	if .Is_Server in args.property_flags {
		write_proc_listeners(writer, interface.request, interface_name, scratch_allocator) or_return
		write_proc_interfaces(writer, interface.event, interface_name, scratch_allocator) or_return
	}
	else {
		write_proc_listeners(writer, interface.event, interface_name, scratch_allocator) or_return
		write_proc_interfaces(writer, interface.request, interface_name, scratch_allocator) or_return
	}

	return nil
}
