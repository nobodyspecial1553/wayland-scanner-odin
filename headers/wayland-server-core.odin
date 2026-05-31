/*
 * Copyright © 2008 Kristian Høgsberg
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
package wayland_protocol

import "core:sys/posix"

EVENT_READABLE :: 1
EVENT_WRITABLE :: 2
EVENT_HANGUP   :: 4
EVENT_ERROR    :: 8

/** File descriptor dispatch function type
*
* Functions of this type are used as callbacks for file descriptor events.
*
* \param fd The file descriptor delivering the event.
* \param mask Describes the kind of the event as a bitwise-or of:
* \c EVENT_READABLE, \c EVENT_WRITABLE, \c EVENT_HANGUP,
* \c EVENT_ERROR.
* \param data The user data argument of the related wl_event_loop_add_fd()
* call.
* \return If the event source is registered for re-check with
* wl_event_source_check(): 0 for all done, 1 for needing a re-check.
* If not registered, the return value is ignored and should be zero.
*
* \sa wl_event_loop_add_fd()
* \memberof wl_event_source
*/
event_loop_fd_func_t :: proc "c" (fd: i32, mask: u32, data: rawptr) -> i32

/** Timer dispatch function type
*
* Functions of this type are used as callbacks for timer expiry.
*
* \param data The user data argument of the related wl_event_loop_add_timer()
* call.
* \return If the event source is registered for re-check with
* wl_event_source_check(): 0 for all done, 1 for needing a re-check.
* If not registered, the return value is ignored and should be zero.
*
* \sa wl_event_loop_add_timer()
* \memberof wl_event_source
*/
event_loop_timer_func_t :: proc "c" (data: rawptr) -> i32

/** Signal dispatch function type
*
* Functions of this type are used as callbacks for (POSIX) signals.
*
* \param signal_number
* \param data The user data argument of the related wl_event_loop_add_signal()
* call.
* \return If the event source is registered for re-check with
* wl_event_source_check(): 0 for all done, 1 for needing a re-check.
* If not registered, the return value is ignored and should be zero.
*
* \sa wl_event_loop_add_signal()
* \memberof wl_event_source
*/
event_loop_signal_func_t :: proc "c" (signal_number: i32, data: rawptr) -> i32

/** Idle task function type
*
* Functions of this type are used as callbacks before blocking in
* wl_event_loop_dispatch().
*
* \param data The user data argument of the related wl_event_loop_add_idle()
* call.
*
* \sa wl_event_loop_add_idle() wl_event_loop_dispatch()
* \memberof wl_event_source
*/
event_loop_idle_func_t :: proc "c" (data: rawptr)
event_loop             :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	/** \struct wl_event_source
	*
	* \brief An abstract event source
	*
	* This is the generic type for fd, timer, signal, and idle sources.
	* Functions that operate on specific source types must not be used with
	* a different type, even if the function signature allows it.
	*/
	event_loop_create  :: proc() -> ^event_loop ---
	event_loop_destroy :: proc(loop: ^event_loop) ---
}

event_source :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	event_loop_add_fd         :: proc(loop: ^event_loop, fd: i32, mask: u32, func: event_loop_fd_func_t, data: rawptr) -> ^event_source ---
	event_source_fd_update    :: proc(source: ^event_source, mask: u32) -> i32 ---
	event_loop_add_timer      :: proc(loop: ^event_loop, func: event_loop_timer_func_t, data: rawptr) -> ^event_source ---
	event_loop_add_signal     :: proc(loop: ^event_loop, signal_number: i32, func: event_loop_signal_func_t, data: rawptr) -> ^event_source ---
	event_source_timer_update :: proc(source: ^event_source, ms_delay: i32) -> i32 ---
	event_source_remove       :: proc(source: ^event_source) -> i32 ---
	event_source_check        :: proc(source: ^event_source) ---
	event_loop_dispatch       :: proc(loop: ^event_loop, timeout: i32) -> i32 ---
	event_loop_dispatch_idle  :: proc(loop: ^event_loop) ---
	event_loop_add_idle       :: proc(loop: ^event_loop, func: event_loop_idle_func_t, data: rawptr) -> ^event_source ---
	event_loop_get_fd         :: proc(loop: ^event_loop) -> i32 ---
}

notify_func_t :: proc "c" (listener: ^listener, data: rawptr)

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	event_loop_add_destroy_listener :: proc(loop: ^event_loop, listener: ^listener) ---
	event_loop_get_destroy_listener :: proc(loop: ^event_loop, notify: notify_func_t) -> ^listener ---
}

// display :: struct {} // !Redeclaration!

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	display_create                      :: proc() -> ^display ---
	display_destroy                     :: proc(display: ^display) ---
	display_get_event_loop              :: proc(display: ^display) -> ^event_loop ---
	display_add_socket                  :: proc(display: ^display, name: cstring) -> i32 ---
	display_add_socket_auto             :: proc(display: ^display) -> cstring ---
	display_add_socket_fd               :: proc(display: ^display, sock_fd: i32) -> i32 ---
	display_terminate                   :: proc(display: ^display) ---
	display_run                         :: proc(display: ^display) ---
	display_flush_clients               :: proc(display: ^display) ---
	display_destroy_clients             :: proc(display: ^display) ---
	display_set_default_max_buffer_size :: proc(display: ^display, max_buffer_size: i32) ---
}

client             :: struct {}
global_bind_func_t :: proc "c" (client: ^client, data: rawptr, version: u32, id: u32)

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	display_get_serial                  :: proc(display: ^display) -> u32 ---
	display_next_serial                 :: proc(display: ^display) -> u32 ---
	display_add_destroy_listener        :: proc(display: ^display, listener: ^listener) ---
	display_add_client_created_listener :: proc(display: ^display, listener: ^listener) ---
	display_get_destroy_listener        :: proc(display: ^display, notify: notify_func_t) -> ^listener ---
}

global :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	global_create  :: proc(display: ^display, interface: ^interface, version: i32, data: rawptr, bind: global_bind_func_t) -> ^global ---
	global_remove  :: proc(global: ^global) ---
	global_destroy :: proc(global: ^global) ---
}

/** A filter function for wl_global objects
*
* \param client The client object
* \param global The global object to show or hide
* \param data   The user data pointer
*
* A filter function enables the server to decide which globals to
* advertise to each client.
*
* When a wl_global filter is set, the given callback function will be
* called during wl_global advertisement and binding.
*
* This function should return true if the global object should be made
* visible to the client or false otherwise.
*/
bool :: proc "c" (^i32) -> i32 /*
 * Copyright © 2008 Kristian Høgsberg
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	display_set_global_filter        :: proc(display: ^display, filter: i32, data: rawptr) ---
	global_get_interface             :: proc(global: ^global) -> ^interface ---
	global_get_name                  :: proc(global: ^global, client: ^client) -> u32 ---
	global_get_version               :: proc(global: ^global) -> u32 ---
	global_get_display               :: proc(global: ^global) -> ^display ---
	global_get_user_data             :: proc(global: ^global) -> rawptr ---
	global_set_user_data             :: proc(global: ^global, data: rawptr) ---
	client_create                    :: proc(display: ^display, fd: i32) -> ^client ---
	display_get_client_list          :: proc(display: ^display) -> ^list ---
	client_get_link                  :: proc(client: ^client) -> ^list ---
	client_from_link                 :: proc(link: ^list) -> ^client ---
	client_destroy                   :: proc(client: ^client) ---
	client_flush                     :: proc(client: ^client) ---
	client_get_credentials           :: proc(client: ^client, pid: ^posix.pid_t, uid: ^uid_t, gid: ^posix.gid_t) ---
	client_get_fd                    :: proc(client: ^client) -> i32 ---
	client_add_destroy_listener      :: proc(client: ^client, listener: ^listener) ---
	client_get_destroy_listener      :: proc(client: ^client, notify: notify_func_t) -> ^listener ---
	client_add_destroy_late_listener :: proc(client: ^client, listener: ^listener) ---
	client_get_destroy_late_listener :: proc(client: ^client, notify: notify_func_t) -> ^listener ---
}

resource :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	client_get_object                    :: proc(client: ^client, id: u32) -> ^resource ---
	client_post_no_memory                :: proc(client: ^client) ---
	client_post_implementation_error     :: proc(client: ^client, msg: cstring, #c_vararg _: ..any) ---
	client_add_resource_created_listener :: proc(client: ^client, listener: ^listener) ---
}

client_for_each_resource_iterator_func_t :: proc "c" (resource: ^resource, user_data: rawptr) -> iterator_result

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	client_for_each_resource :: proc(client: ^client, iterator: client_for_each_resource_iterator_func_t, user_data: rawptr) ---
}

user_data_destroy_func_t :: proc "c" (data: rawptr)

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	client_set_user_data       :: proc(client: ^client, data: rawptr, dtor: user_data_destroy_func_t) ---
	client_get_user_data       :: proc(client: ^client) -> rawptr ---
	client_set_max_buffer_size :: proc(client: ^client, max_buffer_size: i32) ---
}

/** \class wl_listener
*
* \brief A single listener for Wayland signals
*
* wl_listener provides the means to listen for wl_signal notifications. Many
* Wayland objects use wl_listener for notification of significant events like
* object destruction.
*
* Clients should create wl_listener objects manually and can register them as
* listeners to signals using #wl_signal_add, assuming the signal is
* directly accessible. For opaque structs like wl_event_loop, adding a
* listener should be done through provided accessor methods. A listener can
* only listen to one signal at a time.
*
* \code
* struct wl_listener your_listener;
*
* your_listener.notify = your_callback_method;
*
* // Direct access
* wl_signal_add(&some_object->destroy_signal, &your_listener);
*
* // Accessor access
* wl_event_loop *loop = ...;
* wl_event_loop_add_destroy_listener(loop, &your_listener);
* \endcode
*
* If the listener is part of a larger struct, #wl_container_of can be used
* to retrieve a pointer to it:
*
* \code
* void your_listener(struct wl_listener *listener, void *data)
* {
* 	struct your_data *data;
*
* 	your_data = wl_container_of(listener, data, your_member_name);
* }
* \endcode
*
* If you need to remove a listener from a signal, use wl_list_remove().
*
* \code
* wl_list_remove(&your_listener.link);
* \endcode
*
* \sa wl_signal
*/
listener :: struct {}

/** \class wl_signal
*
* \brief A source of a type of observable event
*
* Signals are recognized points where significant events can be observed.
* Compositors as well as the server can provide signals. Observers are
* wl_listener's that are added through #wl_signal_add. Signals are emitted
* using #wl_signal_emit, which will invoke all listeners until that
* listener is removed by wl_list_remove() (or whenever the signal is
* destroyed).
*
* \sa wl_listener for more information on using wl_signal
*/
signal :: struct {
	listener_list: list,
}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	signal_emit_mutable :: proc(signal: ^signal, data: rawptr) ---
}

resource_destroy_func_t :: proc "c" (resource: ^resource)

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	/*
	* Post an event to the client's object referred to by 'resource'.
	* 'opcode' is the event number generated from the protocol XML
	* description (the event name). The variable arguments are the event
	* parameters, in the order they appear in the protocol XML specification.
	*
	* The variable arguments' types are:
	* - type=uint:	uint32_t
	* - type=int:		int32_t
	* - type=fixed:	wl_fixed_t
	* - type=string:	(const char *) to a nil-terminated string
	* - type=array:	(struct wl_array *)
	* - type=fd:		int, that is an open file descriptor
	* - type=new_id:	(struct wl_object *) or (struct wl_resource *)
	* - type=object:	(struct wl_object *) or (struct wl_resource *)
	*/
	resource_post_event           :: proc(resource: ^resource, opcode: u32, #c_vararg _: ..any) ---
	resource_post_event_array     :: proc(resource: ^resource, opcode: u32, args: ^argument) ---
	resource_queue_event          :: proc(resource: ^resource, opcode: u32, #c_vararg _: ..any) ---
	resource_queue_event_array    :: proc(resource: ^resource, opcode: u32, args: ^argument) ---
	resource_post_error_vargs     :: proc(resource: ^resource, code: u32, msg: cstring, argp: i32) ---
	resource_post_error           :: proc(resource: ^resource, code: u32, msg: cstring, #c_vararg _: ..any) ---
	resource_post_no_memory       :: proc(resource: ^resource) ---
	client_get_display            :: proc(client: ^client) -> ^display ---
	resource_create               :: proc(client: ^client, interface: ^interface, version: i32, id: u32) -> ^resource ---
	resource_set_implementation   :: proc(resource: ^resource, implementation: rawptr, data: rawptr, destroy: resource_destroy_func_t) ---
	resource_set_dispatcher       :: proc(resource: ^resource, dispatcher: dispatcher_func_t, implementation: rawptr, data: rawptr, destroy: resource_destroy_func_t) ---
	resource_destroy              :: proc(resource: ^resource) ---
	resource_get_id               :: proc(resource: ^resource) -> u32 ---
	resource_get_link             :: proc(resource: ^resource) -> ^list ---
	resource_from_link            :: proc(resource: ^list) -> ^resource ---
	resource_find_for_client      :: proc(list: ^list, client: ^client) -> ^resource ---
	resource_get_client           :: proc(resource: ^resource) -> ^client ---
	resource_set_user_data        :: proc(resource: ^resource, data: rawptr) ---
	resource_get_user_data        :: proc(resource: ^resource) -> rawptr ---
	resource_get_version          :: proc(resource: ^resource) -> i32 ---
	resource_set_destructor       :: proc(resource: ^resource, destroy: resource_destroy_func_t) ---
	resource_instance_of          :: proc(resource: ^resource, interface: ^interface, implementation: rawptr) -> i32 ---
	resource_get_class            :: proc(resource: ^resource) -> cstring ---
	resource_get_interface        :: proc(resource: ^resource) -> ^interface ---
	resource_add_destroy_listener :: proc(resource: ^resource, listener: ^listener) ---
	resource_get_destroy_listener :: proc(resource: ^resource, notify: notify_func_t) -> ^listener ---
}

shm_buffer :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	shm_buffer_get          :: proc(resource: ^resource) -> ^shm_buffer ---
	shm_buffer_begin_access :: proc(buffer: ^shm_buffer) ---
	shm_buffer_end_access   :: proc(buffer: ^shm_buffer) ---
	shm_buffer_get_data     :: proc(buffer: ^shm_buffer) -> rawptr ---
	shm_buffer_get_stride   :: proc(buffer: ^shm_buffer) -> i32 ---
	shm_buffer_get_format   :: proc(buffer: ^shm_buffer) -> u32 ---
	shm_buffer_get_width    :: proc(buffer: ^shm_buffer) -> i32 ---
	shm_buffer_get_height   :: proc(buffer: ^shm_buffer) -> i32 ---
	shm_buffer_ref          :: proc(buffer: ^shm_buffer) -> ^shm_buffer ---
	shm_buffer_unref        :: proc(buffer: ^shm_buffer) ---
}

shm_pool :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	shm_buffer_ref_pool    :: proc(buffer: ^shm_buffer) -> ^shm_pool ---
	shm_pool_unref         :: proc(pool: ^shm_pool) ---
	display_init_shm       :: proc(display: ^display) -> i32 ---
	display_add_shm_format :: proc(display: ^display, format: u32) -> ^u32 ---
	shm_buffer_create      :: proc(client: ^client, id: u32, width: i32, height: i32, stride: i32, format: u32) -> ^shm_buffer ---
	log_set_handler_server :: proc(handler: log_func_t) ---
}

protocol_logger_type :: enum u32 {
	REQUEST = 0,
	EVENT   = 1,
}

protocol_logger_message :: struct {
	resource:        ^resource,
	message_opcode:  i32,
	message:         ^message,
	arguments_count: i32,
	arguments:       ^argument,
}

protocol_logger_func_t :: proc "c" (user_data: rawptr, direction: protocol_logger_type, message: ^protocol_logger_message)
protocol_logger        :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	display_add_protocol_logger :: proc(display: ^display, _: protocol_logger_func_t, user_data: rawptr) -> ^protocol_logger ---
	protocol_logger_destroy     :: proc(logger: ^protocol_logger) ---
}

