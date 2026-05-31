package ns_wayland_scanner_odin

@(require) import "core:fmt"
@(require) import "core:log"
import "core:os"
import "core:strings"
import "core:io"

HEADERS_WAYLAND_VERSION_PATH :: "headers/wayland-version.odin"
HEADERS_WAYLAND_VERSION :: #load(HEADERS_WAYLAND_VERSION_PATH, string)

HEADERS_WAYLAND_CLIENT_UTIL_PATH :: "headers/wayland-client-util.odin"
HEADERS_WAYLAND_CLIENT_UTIL :: #load(HEADERS_WAYLAND_CLIENT_UTIL_PATH, string)
HEADERS_WAYLAND_CLIENT_CORE_PATH :: "headers/wayland-client-core.odin"
HEADERS_WAYLAND_CLIENT_CORE :: #load(HEADERS_WAYLAND_CLIENT_CORE_PATH, string)

HEADERS_WAYLAND_SERVER_UTIL_PATH :: "headers/wayland-server-util.odin"
HEADERS_WAYLAND_SERVER_UTIL :: #load(HEADERS_WAYLAND_SERVER_UTIL_PATH, string)
HEADERS_WAYLAND_SERVER_PATH :: "headers/wayland-server.odin"
HEADERS_WAYLAND_SERVER :: #load(HEADERS_WAYLAND_SERVER_PATH, string)
HEADERS_WAYLAND_SERVER_CORE_PATH :: "headers/wayland-server-core.odin"
HEADERS_WAYLAND_SERVER_CORE :: #load(HEADERS_WAYLAND_SERVER_CORE_PATH, string)

@(private="file")
@(require_results)
_copy_to_file :: proc(dst_path: string, string_stream: io.Reader) -> (error: os.Error) {
	file: ^os.File

	file = os.open(dst_path, { .Read, .Write, .Create, .Trunc }, os.Permissions_Default_File) or_return
	defer {
		os.sync(file)
		os.close(file)
	}

	io.copy(os.to_writer(file), string_stream) or_return

	return nil
}

@(require_results)
headers_clone_client_files :: proc(dst_directory: string, temp_allocator := context.temp_allocator) -> (error: os.Error) {
	string_reader: strings.Reader
	string_stream: io.Reader
	dst_path: string

	if os.is_directory(dst_directory) == false {
		return os.General_Error.Invalid_Dir
	}

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_VERSION_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_VERSION)
	_copy_to_file(dst_path, string_stream) or_return

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_CLIENT_UTIL_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_CLIENT_UTIL)
	_copy_to_file(dst_path, string_stream) or_return

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_CLIENT_CORE_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_CLIENT_CORE)
	_copy_to_file(dst_path, string_stream) or_return

	return nil
}

@(require_results)
headers_clone_server_files :: proc(dst_directory: string, temp_allocator := context.temp_allocator) -> (error: os.Error) {
	string_reader: strings.Reader
	string_stream: io.Reader
	dst_path: string

	if os.is_directory(dst_directory) == false {
		return os.General_Error.Invalid_Dir
	}

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_VERSION_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_VERSION)
	_copy_to_file(dst_path, string_stream) or_return

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_SERVER_UTIL_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_SERVER_UTIL)
	_copy_to_file(dst_path, string_stream) or_return

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_SERVER_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_SERVER)
	_copy_to_file(dst_path, string_stream) or_return

	dst_path = os.join_path([]string { dst_directory,  os.base(HEADERS_WAYLAND_SERVER_CORE_PATH) }, temp_allocator) or_return
	string_stream = strings.to_reader(&string_reader, HEADERS_WAYLAND_SERVER_CORE)
	_copy_to_file(dst_path, string_stream) or_return

	return nil
}
