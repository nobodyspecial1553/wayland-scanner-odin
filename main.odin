package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
@(require) import "core:mem"
import os "core:os/os2"
import "core:io"
import "core:bufio"

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

		bufio.reader_init(&buffered_reader, {}, mem.Megabyte)
		defer bufio.reader_destroy(&buffered_reader)

		for file_path_in in args.file_path_in_array {
			file: ^os.File
			file_open_error: os.Error

			buffered_stream: io.Reader

			xml_lexer: XML_Lexer

			protocol: XML_Parser_Protocol
			xml_parse_error: XML_Error

			file, file_open_error = os.open(file_path_in)
			if file_open_error != nil {
				fmt.eprintfln("Failed to open file '%s': %v", file_open_error)
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
			case:
				log.panicf("Failed to parse: %v", xml_parse_error)
			}
		}
	}
}

Args_Property :: enum {
	No_FFI = 0,
}
Args_Property_Flags :: bit_set[Args_Property]

Args :: struct {
	file_path_in_array: []string,
	file_path_out: string,
	property_flags: Args_Property_Flags,
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

	file_path_in_array = make([dynamic]string, 0, len(arg_array), allocator) or_return

	_ = arg_pop_next(&arg_array)
	for len(arg_array) > 0 {
		arg: string

		arg = arg_pop_next(&arg_array)

		switch arg {
		case "-o":
			args.file_path_out = arg_pop_next(&arg_array) or_break
		case "-ffi":
			args.property_flags -= { .No_FFI }
		case "-no-ffi":
			args.property_flags += { .No_FFI }
		case "-h":
			print_help()
		case:
			if arg[0] == '-' {
				fmt.eprintfln("'%s' is not a valid flag!", arg)
				os.exit(1)
			}
			append(&file_path_in_array, arg)
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
	-o <output_file_path>: Sets the output path (appends .odin if it isn't present)
	-ffi (default): Generates odin ffi linked against 'system:wayland-(client/server)'
	-no-ffi: Disables ffi generation, useful if generating each protocol file individually
	-h: Prints help message and exits`, os.args[0], os.args[0],
	)

	os.exit(0)
}
