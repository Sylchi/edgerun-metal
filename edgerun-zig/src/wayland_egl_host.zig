const std = @import("std");
const icon = @import("icon.zig");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const site_landing = @import("site_landing.zig");
const tabler_atlas = @import("tabler_atlas.zig");
const ui = @import("ui.zig");

const linux = std.os.linux;

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-egl.h");
    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2.h");
});

const default_width: i32 = 960;
const default_height: i32 = 540;
const default_seconds: u32 = 5;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
);

const Options = struct {
    width: i32 = default_width,
    height: i32 = default_height,
    seconds: u32 = default_seconds,
};

const WaylandState = struct {
    display: *c.wl_display,
    registry: *c.wl_registry,
    compositor: ?*c.wl_compositor = null,
    wm_base: ?*c.xdg_wm_base = null,
    surface: ?*c.wl_surface = null,
    xdg_surface: ?*c.xdg_surface = null,
    toplevel: ?*c.xdg_toplevel = null,
    configured: bool = false,
    closed: bool = false,
    width: i32,
    height: i32,
};

const EglState = struct {
    display: c.EGLDisplay,
    context: c.EGLContext,
    surface: c.EGLSurface,
    window: *c.wl_egl_window,
};

const GlState = struct {
    rect_program: c.GLuint,
    textured_program: c.GLuint,
    rect_vbo: c.GLuint,
    textured_vbo: c.GLuint,
    font_texture: c.GLuint,
    icon_texture: c.GLuint,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);

    var wl = try initWayland(options.width, options.height);
    defer deinitWayland(&wl);
    var egl = try initEgl(&wl);
    defer deinitEgl(&egl);
    var font_atlas = renderer_font_atlas.Atlas.init();
    var gl = try initGl(&font_atlas);
    defer deinitGl(&gl);

    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var ir_storage = IrStorage{};
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try site_landing.render(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(options.width),
        .h = @floatFromInt(options.height),
    }, .{
        .public_identity = "native-egl-gpu",
        .public_identity_ready = true,
    });
    const buffers = ir_storage.buffers();
    try renderer_ir.packScene(buffers, sources(&font_atlas), scene.written());

    var frames_remaining: u32 = options.seconds * 60;
    while (!wl.closed and frames_remaining != 0) : (frames_remaining -= 1) {
        while (c.wl_display_prepare_read(wl.display) != 0) {
            if (c.wl_display_dispatch_pending(wl.display) < 0) return error.WaylandDispatchFailed;
        }
        _ = c.wl_display_flush(wl.display);
        c.wl_display_cancel_read(wl.display);

        try renderFrame(gl, options.width, options.height, buffers, &font_atlas);
        if (c.eglSwapBuffers(egl.display, egl.surface) != c.EGL_TRUE) return error.EglSwapFailed;
        if (c.wl_display_dispatch_pending(wl.display) < 0) return error.WaylandDispatchFailed;
        sleepFrame();
    }
}

fn sleepFrame() void {
    const req = linux.timespec{ .sec = 0, .nsec = 16 * std.time.ns_per_ms };
    _ = linux.nanosleep(&req, null);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.width = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.height = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width <= 0 or options.height <= 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

fn initWayland(width: i32, height: i32) !WaylandState {
    const display = c.wl_display_connect(null) orelse return error.WaylandConnectFailed;
    errdefer c.wl_display_disconnect(display);
    const registry = c.wl_display_get_registry(display) orelse return error.WaylandRegistryFailed;
    var state = WaylandState{ .display = display, .registry = registry, .width = width, .height = height };
    if (c.wl_registry_add_listener(registry, &registry_listener, &state) != 0) return error.WaylandRegistryFailed;
    if (c.wl_display_roundtrip(display) < 0) return error.WaylandRoundtripFailed;
    const compositor = state.compositor orelse return error.MissingWaylandCompositor;
    const wm_base = state.wm_base orelse return error.MissingXdgWmBase;
    if (c.xdg_wm_base_add_listener(wm_base, &wm_base_listener, &state) != 0) return error.XdgListenerFailed;
    state.surface = c.wl_compositor_create_surface(compositor) orelse return error.WaylandSurfaceFailed;
    state.xdg_surface = c.xdg_wm_base_get_xdg_surface(wm_base, state.surface) orelse return error.XdgSurfaceFailed;
    if (c.xdg_surface_add_listener(state.xdg_surface, &xdg_surface_listener, &state) != 0) return error.XdgListenerFailed;
    state.toplevel = c.xdg_surface_get_toplevel(state.xdg_surface) orelse return error.XdgToplevelFailed;
    if (c.xdg_toplevel_add_listener(state.toplevel, &xdg_toplevel_listener, &state) != 0) return error.XdgListenerFailed;
    c.xdg_toplevel_set_title(state.toplevel, "EdgeRun EGL GPU");
    c.wl_surface_commit(state.surface);
    while (!state.configured) {
        if (c.wl_display_dispatch(display) < 0) return error.WaylandDispatchFailed;
    }
    return state;
}

fn deinitWayland(state: *WaylandState) void {
    if (state.toplevel) |value| c.xdg_toplevel_destroy(value);
    if (state.xdg_surface) |value| c.xdg_surface_destroy(value);
    if (state.surface) |value| c.wl_surface_destroy(value);
    if (state.wm_base) |value| c.xdg_wm_base_destroy(value);
    if (state.compositor) |value| c.wl_compositor_destroy(value);
    c.wl_registry_destroy(state.registry);
    c.wl_display_disconnect(state.display);
}

fn initEgl(wl: *WaylandState) !EglState {
    const egl_display = c.eglGetDisplay(@ptrCast(wl.display));
    if (egl_display == c.EGL_NO_DISPLAY) return error.EglDisplayFailed;
    var major: c.EGLint = 0;
    var minor: c.EGLint = 0;
    if (c.eglInitialize(egl_display, &major, &minor) != c.EGL_TRUE) return error.EglInitializeFailed;
    if (c.eglBindAPI(c.EGL_OPENGL_ES_API) != c.EGL_TRUE) return error.EglApiFailed;
    const attrs = [_]c.EGLint{
        c.EGL_SURFACE_TYPE,    c.EGL_WINDOW_BIT,
        c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES2_BIT,
        c.EGL_RED_SIZE,        8,
        c.EGL_GREEN_SIZE,      8,
        c.EGL_BLUE_SIZE,       8,
        c.EGL_ALPHA_SIZE,      8,
        c.EGL_NONE,
    };
    var config: c.EGLConfig = null;
    var count: c.EGLint = 0;
    if (c.eglChooseConfig(egl_display, &attrs, &config, 1, &count) != c.EGL_TRUE or count == 0) return error.EglConfigFailed;
    const context_attrs = [_]c.EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };
    const context = c.eglCreateContext(egl_display, config, c.EGL_NO_CONTEXT, &context_attrs);
    if (context == c.EGL_NO_CONTEXT) return error.EglContextFailed;
    errdefer _ = c.eglDestroyContext(egl_display, context);
    const surface = wl.surface orelse return error.WaylandSurfaceFailed;
    const window = c.wl_egl_window_create(surface, wl.width, wl.height) orelse return error.EglWindowFailed;
    errdefer c.wl_egl_window_destroy(window);
    const egl_surface = c.eglCreateWindowSurface(egl_display, config, @ptrCast(window), null);
    if (egl_surface == c.EGL_NO_SURFACE) return error.EglSurfaceFailed;
    if (c.eglMakeCurrent(egl_display, egl_surface, egl_surface, context) != c.EGL_TRUE) return error.EglMakeCurrentFailed;
    return .{ .display = egl_display, .context = context, .surface = egl_surface, .window = window };
}

fn deinitEgl(egl: *EglState) void {
    _ = c.eglMakeCurrent(egl.display, c.EGL_NO_SURFACE, c.EGL_NO_SURFACE, c.EGL_NO_CONTEXT);
    _ = c.eglDestroySurface(egl.display, egl.surface);
    _ = c.eglDestroyContext(egl.display, egl.context);
    c.wl_egl_window_destroy(egl.window);
    _ = c.eglTerminate(egl.display);
}

fn initGl(font_atlas: *renderer_font_atlas.Atlas) !GlState {
    c.glClearColor(0.043, 0.043, 0.043, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    return .{
        .rect_program = try makeProgram(rect_vertex_shader, rect_fragment_shader),
        .textured_program = try makeProgram(textured_vertex_shader, textured_fragment_shader),
        .rect_vbo = makeBuffer(),
        .textured_vbo = makeBuffer(),
        .font_texture = makeAlphaTexture(renderer_font_atlas.width, renderer_font_atlas.height, font_atlas.alphaSlice()),
        .icon_texture = makeAlphaTexture(tabler_atlas.width, tabler_atlas.height, tabler_atlas.alpha),
    };
}

fn deinitGl(gl: *GlState) void {
    c.glDeleteTextures(1, &gl.font_texture);
    c.glDeleteTextures(1, &gl.icon_texture);
    c.glDeleteBuffers(1, &gl.rect_vbo);
    c.glDeleteBuffers(1, &gl.textured_vbo);
    c.glDeleteProgram(gl.rect_program);
    c.glDeleteProgram(gl.textured_program);
}

fn renderFrame(gl: GlState, width: i32, height: i32, buffers: renderer_ir.Buffers, font_atlas: *renderer_font_atlas.Atlas) !void {
    _ = font_atlas;
    c.glViewport(0, 0, width, height);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    try drawRects(gl, width, height, buffers.liveRects());
    try drawTextured(gl, width, height, buffers.liveTextVertices(), gl.font_texture);
    try drawTextured(gl, width, height, buffers.liveIconVertices(), gl.icon_texture);
    try drawRects(gl, width, height, buffers.liveOverlayRects());
    try drawTextured(gl, width, height, buffers.liveOverlayTextVertices(), gl.font_texture);
    try drawTextured(gl, width, height, buffers.liveOverlayIconVertices(), gl.icon_texture);
}

fn drawRects(gl: GlState, width: i32, height: i32, values: []const f32) !void {
    var iter = renderer_ir.RectIterator.init(values) catch return error.InvalidIrBuffer;
    c.glUseProgram(gl.rect_program);
    c.glUniform2f(c.glGetUniformLocation(gl.rect_program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(verts.len * @sizeOf(f32)), &verts, c.GL_STATIC_DRAW);
    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
    while (try iter.next()) |rect| {
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_rect"), rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color"), colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color2"), colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_radius"), rect.radius);
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_shadow"), rect.shadow);
        c.glUniform1i(c.glGetUniformLocation(gl.rect_program, "u_mode"), rectMode(rect.mode));
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
}

fn drawTextured(gl: GlState, width: i32, height: i32, values: []const f32, texture: c.GLuint) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.text_vertex_float_stride != 0) return error.InvalidIrBuffer;
    c.glUseProgram(gl.textured_program);
    c.glUniform2f(c.glGetUniformLocation(gl.textured_program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glUniform1i(c.glGetUniformLocation(gl.textured_program, "u_tex"), 0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.textured_vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), values.ptr, c.GL_DYNAMIC_DRAW);
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);
    c.glEnableVertexAttribArray(2);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), null);
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    c.glVertexAttribPointer(2, 4, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(4 * @sizeOf(f32)));
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(values.len / renderer_ir.text_vertex_float_stride));
}

fn makeBuffer() c.GLuint {
    var buffer: c.GLuint = 0;
    c.glGenBuffers(1, &buffer);
    return buffer;
}

fn makeAlphaTexture(width: usize, height: usize, alpha: []const u8) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_ALPHA, @intCast(width), @intCast(height), 0, c.GL_ALPHA, c.GL_UNSIGNED_BYTE, alpha.ptr);
    return texture;
}

fn makeProgram(vertex_source: [:0]const u8, fragment_source: [:0]const u8) !c.GLuint {
    const vertex = try makeShader(c.GL_VERTEX_SHADER, vertex_source);
    defer c.glDeleteShader(vertex);
    const fragment = try makeShader(c.GL_FRAGMENT_SHADER, fragment_source);
    defer c.glDeleteShader(fragment);
    const program = c.glCreateProgram();
    c.glAttachShader(program, vertex);
    c.glAttachShader(program, fragment);
    c.glLinkProgram(program);
    var ok: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &ok);
    if (ok == 0) return error.GlProgramFailed;
    return program;
}

fn makeShader(kind: c.GLenum, source: [:0]const u8) !c.GLuint {
    const shader = c.glCreateShader(kind);
    var ptr = source.ptr;
    c.glShaderSource(shader, 1, &ptr, null);
    c.glCompileShader(shader);
    var ok: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &ok);
    if (ok == 0) return error.GlShaderFailed;
    return shader;
}

fn colorF(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn rectMode(mode: ui.RectMode) c.GLint {
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 3,
        .pie_slice => 0,
    };
}

fn sources(font_atlas: *renderer_font_atlas.Atlas) renderer_ir.Sources {
    return .{
        .font = font_atlas.source(),
        .icon = .{ .context = font_atlas, .rect = iconAtlasRect },
    };
}

fn iconAtlasRect(_: *anyopaque, atlas_id: u32) ?renderer_ir.AtlasRect {
    const value = icon.fromAtlasId(atlas_id) orelse return null;
    const found = tabler_atlas.rect(value);
    return .{
        .u0 = (@as(f32, @floatFromInt(found.x)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
        .u1 = (@as(f32, @floatFromInt(found.x + found.w)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v1 = (@as(f32, @floatFromInt(found.y + found.h)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
    };
}

const registry_listener = c.wl_registry_listener{ .global = registryGlobal, .global_remove = registryRemove };
fn registryGlobal(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    const reg = registry.?;
    const iface = std.mem.span(interface);
    if (std.mem.eql(u8, iface, "wl_compositor")) {
        state.compositor = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_compositor_interface, @min(version, 4)));
    } else if (std.mem.eql(u8, iface, "xdg_wm_base")) {
        state.wm_base = @ptrCast(c.wl_registry_bind(reg, name, &c.xdg_wm_base_interface, @min(version, 1)));
    }
}
fn registryRemove(_: ?*anyopaque, _: ?*c.wl_registry, _: u32) callconv(.c) void {}

const wm_base_listener = c.xdg_wm_base_listener{ .ping = wmBasePing };
fn wmBasePing(_: ?*anyopaque, wm_base: ?*c.xdg_wm_base, serial: u32) callconv(.c) void {
    c.xdg_wm_base_pong(wm_base, serial);
}

const xdg_surface_listener = c.xdg_surface_listener{ .configure = xdgSurfaceConfigure };
fn xdgSurfaceConfigure(data: ?*anyopaque, surface: ?*c.xdg_surface, serial: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    c.xdg_surface_ack_configure(surface, serial);
    state.configured = true;
}

const xdg_toplevel_listener = c.xdg_toplevel_listener{ .configure = xdgToplevelConfigure, .close = xdgToplevelClose };
fn xdgToplevelConfigure(data: ?*anyopaque, _: ?*c.xdg_toplevel, width: i32, height: i32, _: ?*c.wl_array) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if (width > 0 and height > 0) {
        state.width = width;
        state.height = height;
    }
}
fn xdgToplevelClose(data: ?*anyopaque, _: ?*c.xdg_toplevel) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.closed = true;
}

const rect_vertex_shader =
    \\attribute vec2 a_pos;
    \\uniform vec2 u_screen;
    \\uniform vec4 u_rect;
    \\varying vec2 v_local;
    \\varying vec2 v_size;
    \\void main() {
    \\  vec2 px = u_rect.xy + a_pos * u_rect.zw;
    \\  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_local = a_pos * u_rect.zw;
    \\  v_size = u_rect.zw;
    \\}
;

const rect_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_local;
    \\varying vec2 v_size;
    \\uniform vec4 u_color;
    \\uniform vec4 u_color2;
    \\uniform float u_radius;
    \\uniform float u_shadow;
    \\uniform int u_mode;
    \\float rounded_box(vec2 p, vec2 b, float r) {
    \\  vec2 q = abs(p) - b + vec2(r);
    \\  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    \\}
    \\void main() {
    \\  vec2 p = v_local - v_size * 0.5;
    \\  float d = rounded_box(p, v_size * 0.5, u_radius);
    \\  float aa = 1.0;
    \\  float alpha = 1.0 - smoothstep(0.0, aa, d);
    \\  if (u_mode == 1) {
    \\    float sd = rounded_box(p - vec2(0.0, -u_shadow * 0.18), v_size * 0.5, u_radius + u_shadow * 0.35);
    \\    float blur = max(u_shadow, 1.0);
    \\    alpha = 1.0 - smoothstep(-blur, blur, sd);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * alpha * 0.28);
    \\  } else if (u_mode == 2) {
    \\    float inner = rounded_box(p, v_size * 0.5 - vec2(1.25), max(u_radius - 1.25, 0.0));
    \\    float border = (1.0 - smoothstep(0.0, aa, d)) * smoothstep(0.0, aa, inner);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * border);
    \\  } else if (u_mode == 3) {
    \\    float t = clamp(v_local.y / max(v_size.y, 1.0), 0.0, 1.0);
    \\    vec4 color = mix(u_color, u_color2, t);
    \\    gl_FragColor = vec4(color.rgb, color.a * alpha);
    \\  } else {
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * alpha);
    \\  }
    \\}
;

const textured_vertex_shader =
    \\attribute vec2 a_pos;
    \\attribute vec2 a_uv;
    \\attribute vec4 a_color;
    \\uniform vec2 u_screen;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\void main() {
    \\  vec2 ndc = vec2(a_pos.x / u_screen.x * 2.0 - 1.0, 1.0 - a_pos.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_uv = a_uv;
    \\  v_color = a_color;
    \\}
;

const textured_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  float a = texture2D(u_tex, v_uv).a;
    \\  gl_FragColor = vec4(v_color.rgb, v_color.a * a);
    \\}
;
