/*
 * Copyright © 2011 Kristian Høgsberg
 * Copyright © 2011 Benjamin Franzke
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

WL_EGL_PLATFORM :: 1

egl_window :: struct {}
surface    :: struct {}

@(default_calling_convention="c", link_prefix="wl_")
foreign lib {
	egl_window_create            :: proc(surface: ^surface, width: i32, height: i32) -> ^egl_window ---
	egl_window_destroy           :: proc(egl_window: ^egl_window) ---
	egl_window_resize            :: proc(egl_window: ^egl_window, width: i32, height: i32, dx: i32, dy: i32) ---
	egl_window_get_attached_size :: proc(egl_window: ^egl_window, width: ^i32, height: ^i32) ---
}

