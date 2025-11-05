package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
import "core:io"

OUTPUT_WRITE_HEADER_STR :: #load("templates/header.odin", string)

output_write_header :: proc(writer: io.Writer) -> (error: io.Error) {
	io.write_string(writer, OUTPUT_WRITE_HEADER_STR) or_return
	return nil
}

OUTPUT_WRITE_FFI_CLIENT_STR :: #load("templates/ffi_client.odin", string)
OUTPUT_WRITE_FFI_SERVER_STR :: #load("templates/ffi_server.odin", string)

output_write_ffi :: proc(writer: io.Writer, args: Args) -> (error: io.Error) {
	if .No_FFI in args.property_flags {
		return nil
	}
	if .Is_Server not_in args.property_flags {
		io.write_string(writer, OUTPUT_WRITE_FFI_CLIENT_STR) or_return
	}
	else {
		io.write_string(writer, OUTPUT_WRITE_FFI_SERVER_STR) or_return
	}
	return nil
}
