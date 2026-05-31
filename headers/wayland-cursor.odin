/*
 * Copyright © 2012 Intel Corporation
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

cursor_theme :: struct {}
buffer       :: struct {}
shm          :: struct {}

/** A still image part of a cursor
*
* Use `wl_cursor_image_get_buffer()` to get the corresponding `struct
* wl_buffer` to attach to your `struct wl_surface`. */
cursor_image :: struct {
	/** Actual width */
	width: u32,

	/** Actual height */
	height: u32,

	/** Hot spot x (must be inside image) */
	hotspot_x: u32,

	/** Hot spot y (must be inside image) */
	hotspot_y: u32,

	/** Animation delay to next frame (ms) */
	delay: u32,
}

/** A cursor, as returned by `wl_cursor_theme_get_cursor()` */
cursor :: struct {
	/** How many images there are in this cursor’s animation */
	image_count: u32,

	/** The array of still images composing this animation */
	images: ^^cursor_image,

	/** The name of this cursor */
	name: cstring,
}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	cursor_theme_load         :: proc(name: cstring, size: i32, shm: ^shm) -> ^cursor_theme ---
	cursor_theme_destroy      :: proc(theme: ^cursor_theme) ---
	cursor_theme_get_cursor   :: proc(theme: ^cursor_theme, name: cstring) -> ^cursor ---
	cursor_image_get_buffer   :: proc(image: ^cursor_image) -> ^buffer ---
	cursor_frame              :: proc(cursor: ^cursor, time: u32) -> i32 ---
	cursor_frame_and_duration :: proc(cursor: ^cursor, time: u32, duration: ^u32) -> i32 ---
}

