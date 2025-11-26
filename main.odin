package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
@(require) import "core:mem"
import os "core:os/os2"
import "core:io"
import "core:bufio"
import "core:strings"

main :: proc() {
	context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Info)
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		// No panic!!! >:(
		// I want information!
		tracking_allocator.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer {
			if len(tracking_allocator.allocation_map) > 0 {
				fmt.eprint("\n--== Memory Leaks ==--\n")
				fmt.eprintf("Total Leaks: %v\n", len(tracking_allocator.allocation_map))
				for _, leak in tracking_allocator.allocation_map {
					fmt.eprintf("Leak: %v bytes @%v\n", leak.size, leak.location)
				}
			}
			if len(tracking_allocator.bad_free_array) > 0 {
				fmt.eprint("\n--== Bad Frees ==--\n")
				for bad_free in tracking_allocator.bad_free_array {
					fmt.eprintf("Bad Free: %p @%v\n", bad_free.memory, bad_free.location)
				}
			}
		}
	}

	{
		lexer_scratch: mem.Scratch
		lexer_scratch_allocator: mem.Allocator

		parser_scratch: mem.Scratch
		parser_scratch_allocator: mem.Allocator

		string_arena: mem.Dynamic_Arena
		string_allocator: mem.Allocator

		args_allocator_error: mem.Allocator_Error
		args: Args

		buffered_reader: bufio.Reader

		output_file: ^os.File
		output_file_open_error: os.Error
		buffered_output_writer: bufio.Writer
		buffered_output_stream: io.Writer

		mem.scratch_init(&lexer_scratch, mem.Megabyte)
		lexer_scratch_allocator = mem.scratch_allocator(&lexer_scratch)
		defer mem.scratch_destroy(&lexer_scratch)

		mem.scratch_init(&parser_scratch, mem.Megabyte)
		parser_scratch_allocator = mem.scratch_allocator(&parser_scratch)
		defer mem.scratch_destroy(&parser_scratch)

		mem.dynamic_arena_init(&string_arena)
		string_allocator = mem.dynamic_arena_allocator(&string_arena)
		defer mem.dynamic_arena_destroy(&string_arena)

		args, args_allocator_error = parse_args(os.args, string_allocator)
		if args_allocator_error != nil {
			log.fatalf("Args Parsing Allocator Error: %v", args_allocator_error)
		}

		output_file, output_file_open_error = os.open(args.file_path_out, { .Write, .Create, .Trunc }, os.Permissions_Read_Write_All)
		if output_file_open_error != nil {
			fmt.eprintfln("Failed to open file \"%s\": %v", args.file_path_out, output_file_open_error)
			os.exit(1)
		}
		defer os.close(output_file)

		bufio.writer_init(&buffered_output_writer, output_file.stream, mem.Megabyte)
		defer {
			bufio.writer_flush(&buffered_output_writer)
			bufio.writer_destroy(&buffered_output_writer)
		}
		buffered_output_stream = bufio.writer_to_stream(&buffered_output_writer)

		bufio.reader_init(&buffered_reader, {}, mem.Megabyte)
		defer bufio.reader_destroy(&buffered_reader)

		output_write_header(buffered_output_stream)
		for file_path_in in args.file_path_in_array {
			file: ^os.File
			file_open_error: os.Error

			buffered_stream: io.Reader

			xml_lexer: XML_Lexer

			protocol: XML_Parser_Protocol
			xml_parse_error: XML_Error

			file, file_open_error = os.open(file_path_in)
			if file_open_error != nil {
				fmt.eprintfln("Failed to open file \"%s\": %v", file_open_error)
				os.exit(1)
			}
			defer os.close(file)

			bufio.reader_reset(&buffered_reader, file.stream)
			buffered_stream = bufio.reader_to_stream(&buffered_reader)

			xml_lexer_init(&xml_lexer, buffered_stream, string_allocator, lexer_scratch_allocator)

			protocol, xml_parse_error = xml_parse(&xml_lexer, string_allocator, parser_scratch_allocator)
			#partial switch xml_parse_error_variant in xml_parse_error {
			case io.Error:
				#partial switch xml_parse_error_variant {
				case .EOF, .Unexpected_EOF:
					break
				case:
					log.panicf("Failed to parse: %v", xml_parse_error)
				}
			case nil:
				break
			case:
				log.panicf("Failed to parse: %v", xml_parse_error)
			}
			output_write_protocol(buffered_output_stream, protocol, args)

			free_all(context.temp_allocator)
		}
	}
}

Args_Property :: enum {
	Is_Server = 0,
	Generate_Proc_FFI,
	Disable_Proc_Generation,
	Generate_Interface_FFI,
	Disable_Interface_Generation,
}
Args_Property_Flags :: bit_set[Args_Property]

Args :: struct {
	file_path_in_array: []string,
	file_path_out: string,
	property_flags: Args_Property_Flags,
	proc_ffi_link_path: string,
	proc_ffi_name: string,
	interface_ffi_link_path: string,
	interface_ffi_name: string,
}

@(require_results)
parse_args :: proc(
	arg_array: []string,
	allocator := context.allocator,
) -> (
	args: Args,
	allocator_error: mem.Allocator_Error,
) #optional_allocator_error {
	@(require_results)
	arg_pop_next :: #force_inline proc "contextless" (arg_array: ^[]string) -> (arg: string, ok: bool) #optional_ok {
		if len(arg_array^) == 0 {
			return "", false
		}
		arg = arg_array[0]
		arg_array^ = arg_array[1:]
		return arg, true
	}

	file_path_in_array: [dynamic]string

	arg_array := arg_array

	context.allocator = allocator
	context.temp_allocator = mem.panic_allocator()

	assert(arg_array != nil)

	args.file_path_out = "wayland.odin"

	file_path_in_array = make([dynamic]string, 0, len(arg_array), allocator) or_return

	_ = arg_pop_next(&arg_array)
	for len(arg_array) > 0 {
		arg: string

		arg = arg_pop_next(&arg_array)

		switch arg {
		case "-o":
			args.file_path_out = arg_pop_next(&arg_array) or_break
		case "-client":
			args.property_flags -= { .Is_Server }
		case "-server":
			args.property_flags += { .Is_Server }
		case "-disable-proc-generation":
			args.property_flags += { .Disable_Proc_Generation }
		case "-disable-interface-generation":
			args.property_flags += { .Disable_Interface_Generation }
		case "-h":
			print_help()
		case:
			switch {
			case strings.contains(arg, "-generate-proc-ffi") == true:
				colon_index: int
				equal_sign_index: int

				equal_sign_index = strings.index_byte(arg, '=')
				if equal_sign_index < 0 || equal_sign_index + 1 >= len(arg) {
					break
				}
				colon_index = strings.index_byte(arg, ':')
				if colon_index < 0 || colon_index + 1 >= len(arg) || colon_index > equal_sign_index {
					break
				}

				args.proc_ffi_name = arg[colon_index + 1:equal_sign_index]
				args.proc_ffi_link_path = arg[equal_sign_index + 1:]
				args.property_flags += { .Generate_Proc_FFI }
			case strings.contains(arg, "-generate-interface-ffi") == true:
				colon_index: int
				equal_sign_index: int

				equal_sign_index = strings.index_byte(arg, '=')
				if equal_sign_index < 0 || equal_sign_index + 1 >= len(arg) {
					break
				}
				colon_index = strings.index_byte(arg, ':')
				if colon_index < 0 || colon_index + 1 >= len(arg) || colon_index > equal_sign_index {
					break
				}

				args.interface_ffi_name = arg[colon_index + 1:equal_sign_index]
				args.interface_ffi_link_path = arg[equal_sign_index + 1:]
				args.property_flags += { .Generate_Interface_FFI }
			case arg[0] == '-':
				fmt.eprintfln("'%s' is not a valid flag!", arg)
				os.exit(1)
			case:
				append(&file_path_in_array, arg)
			}
		}
	}

	if len(file_path_in_array) == 0 {
		delete(file_path_in_array)
		print_help()
	}

	args.file_path_in_array = file_path_in_array[:]

	return args, nil
}

print_help :: proc() -> ! {
	fmt.printfln(`Usage: %s [options] [-o output_file_path] <input file paths>

%s is a tool for generating odin code from wayland protocol xml files

[Flags]:
	-o <output_file_path>: Sets the output path
	-client (default): Generates wayland client odin file
	-server: Generates wayland server odin file
	-generate-proc-ffi:<foreign import name>=<odin-style link path>: Generates FFI for proxy procs instead of procs with bodies
	-disable-proc-generation: Disables proc, listener and enum generation
	-generate-interface-ffi:<foreign import name>=<odin-style link path>: Generates FFI for interface structures
	-disable-interface-generation: Disables generation for interface structures
	-h: Prints help message and exits`, os.args[0], os.args[0])

	os.exit(0)
}
