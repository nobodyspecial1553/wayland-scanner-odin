package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
@(require) import "core:mem"
import os "core:os/os2"

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

	args := parse_args(os.args)

	/*
	xml_lexer: XML_Lexer
	xml_lexer_init(&xml_lexer)

	for {
		xml_token := xml_lexer_token_next
		fmt.printfln("Token Type: %v", xml_token.type)
	}
	*/
}

Args :: struct {
	file_path_in_array: []string,
}

@(require_results)
parse_args :: proc(
	arg_array: []string,
	allocator := context.allocator,
) -> (
	args: Args,
	allocator_error: mem.Allocator_Error
) #optional_allocator_error {
	@(require_results)
	arg_pop_next :: proc "contextless" (arg_array: ^[]string) -> (arg: string) {
		arg = arg_array[0]
		arg_array^ = arg_array[1:]
		return
	}

	arg_array := arg_array

	assert(arg_array != nil)

	for len(arg_array) > 0 {
		arg := arg_pop_next(&arg_array)
		fmt.printfln("Arg: %v", arg)
	}

	return args, nil
}
