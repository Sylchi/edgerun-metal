const std = @import("std");

// ─── EGL types ──────────────────────────────────────────────

pub const EGLint = i32;
pub const EGLBoolean = i32;
pub const EGLenum = i32;
pub const EGLConfig = *anyopaque;
pub const EGLContext = ?*anyopaque;
pub const EGLDisplay = ?*anyopaque;
pub const EGLSurface = ?*anyopaque;
pub const EGLImage = ?*anyopaque;
pub const EGLClientBuffer = *anyopaque;
pub const EGLNativeDisplayType = *anyopaque;

pub const egl_no_display: EGLDisplay = null;
pub const egl_no_context: EGLContext = null;
pub const egl_no_surface: EGLSurface = null;
pub const egl_no_image: EGLImage = null;

pub const egl_false: EGLBoolean = 0;
pub const egl_true: EGLBoolean = 1;

pub const egl_render_buffer: EGLenum = 0x3086;
pub const egl_context_client_version: EGLenum = 0x3098;
pub const egl_opengl_es_api: EGLenum = 0x30A0;
pub const egl_none: EGLenum = 0x3038;
pub const egl_success: EGLenum = 0x3000;
pub const egl_width: EGLenum = 0x3057;
pub const egl_height: EGLenum = 0x3058;
pub const egl_buffer_size: EGLenum = 0x3020;
pub const egl_alpha_size: EGLenum = 0x3021;
pub const egl_blue_size: EGLenum = 0x3022;
pub const egl_green_size: EGLenum = 0x3023;
pub const egl_red_size: EGLenum = 0x3024;
pub const egl_depth_size: EGLenum = 0x3025;
pub const egl_stencil_size: EGLenum = 0x3026;
pub const egl_sample_buffers: EGLenum = 0x3032;
pub const egl_samples: EGLenum = 0x3031;
pub const egl_renderable_type: EGLenum = 0x3040;
pub const egl_surface_type: EGLenum = 0x3033;
pub const egl_opengl_es2_bit: EGLenum = 0x0004;
pub const egl_pixmap_bit: EGLenum = 0x0002;
pub const egl_window_bit: EGLenum = 0x0004;
pub const egl_pbuffer_bit: EGLenum = 0x0001;
pub const egl_platform_gbm_khr: EGLenum = 0x31D7;
pub const egl_platform_device_ext: EGLenum = 0x313F;
pub const egl_linux_dma_buf_ext: EGLenum = 0x3270;
pub const egl_dma_buf_plane0_fd_ext: EGLenum = 0x3272;
pub const egl_dma_buf_plane0_offset_ext: EGLenum = 0x3273;
pub const egl_dma_buf_plane0_pitch_ext: EGLenum = 0x3274;
pub const egl_dma_buf_plane0_modifier_lo_ext: EGLenum = 0x3443;
pub const egl_dma_buf_plane0_modifier_hi_ext: EGLenum = 0x3444;
pub const egl_dma_buf_plane1_fd_ext: EGLenum = 0x3283;
pub const egl_dma_buf_plane1_offset_ext: EGLenum = 0x3284;
pub const egl_dma_buf_plane1_pitch_ext: EGLenum = 0x3285;
pub const egl_dma_buf_plane2_fd_ext: EGLenum = 0x3286;
pub const egl_dma_buf_plane2_offset_ext: EGLenum = 0x3287;
pub const egl_dma_buf_plane2_pitch_ext: EGLenum = 0x3288;
pub const egl_linux_drm_fourcc_ext: EGLenum = 0x3271;
pub const egl_drm_master_fd_ext: EGLenum = 0x333C;
pub const egl_gl_texture_2d_khr: EGLenum = 0x30B1;
pub const egl_drm_buffer_format_mesa: EGLenum = 0x31D0;
pub const egl_drm_buffer_use_mesa: EGLenum = 0x31D1;
pub const egl_drm_buffer_format_argb32_mesa: EGLenum = 0x31D2;
pub const egl_drm_buffer_use_scanout_mesa: u32 = 0x00000001;

pub const drm_format_argb8888: u32 = 0x34325241;
pub const drm_format_xrgb8888: u32 = 0x34325258;
pub const drm_format_abgr8888: u32 = 0x34324241;
pub const drm_format_rgba8888: u32 = 0x34324152;

pub const gbm_bo_use_scanout: u32 = 1 << 0;
pub const gbm_bo_use_rendering: u32 = 1 << 1;

// ─── EGL function pointer types ─────────────────────────────

pub const PFNEGLGETPLATFORMDISPLAYEXTPROC = *const fn (platform: EGLenum, native_display: *anyopaque, attrib_list: [*]const EGLint) callconv(.c) EGLDisplay;
pub const PFNEGLGETDISPLAYPROC = *const fn (display_id: EGLNativeDisplayType) callconv(.c) EGLDisplay;
pub const PFNEGLCREATEWINDOWSURFACEPROC = *const fn (dpy: EGLDisplay, config: EGLConfig, win: *anyopaque, attrib_list: ?[*]const EGLint) callconv(.c) EGLSurface;
pub const PFNEGLSWAPBUFFERSPROC = *const fn (dpy: EGLDisplay, surface: EGLSurface) callconv(.c) EGLBoolean;
pub const PFNEGLQUERYSTRINGPROC = *const fn (dpy: EGLDisplay, name: EGLint) callconv(.c) [*:0]const u8;
pub const PFNEGLGETERRORPROC = *const fn () callconv(.c) EGLenum;
pub const PFNEGLINITIALIZEPROC = *const fn (dpy: EGLDisplay, major: *EGLint, minor: *EGLint) callconv(.c) EGLBoolean;
pub const PFNEGLCHOOSECONFIGPROC = *const fn (dpy: EGLDisplay, attrib_list: [*]const EGLint, configs: *EGLConfig, config_size: EGLint, num_config: *EGLint) callconv(.c) EGLBoolean;
pub const PFNEGLCREATECONTEXTPROC = *const fn (dpy: EGLDisplay, config: EGLConfig, share_context: EGLContext, attrib_list: [*]const EGLint) callconv(.c) EGLContext;
pub const PFNEGLDESTROYCONTEXTPROC = *const fn (dpy: EGLDisplay, ctx: EGLContext) callconv(.c) EGLBoolean;
pub const PFNEGLMAKECURRENTPROC = *const fn (dpy: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) callconv(.c) EGLBoolean;
pub const PFNEGLBINDAPIPROC = *const fn (api: EGLenum) callconv(.c) EGLBoolean;
pub const PFNEGLCREATEIMAGEPROC = *const fn (dpy: EGLDisplay, ctx: EGLContext, target: EGLenum, buffer: EGLClientBuffer, attrib_list: [*]const EGLint) callconv(.c) EGLImage;
pub const PFNEGLDESTROYIMAGEPROC = *const fn (dpy: EGLDisplay, image: EGLImage) callconv(.c) EGLBoolean;
pub const PFNEGLTERMINATEPROC = *const fn (dpy: EGLDisplay) callconv(.c) EGLBoolean;
pub const PFNEGLDESTROYSURFACEPROC = *const fn (dpy: EGLDisplay, surface: EGLSurface) callconv(.c) EGLBoolean;
pub const PFNEGLQUERYSURFACEPROC = *const fn (dpy: EGLDisplay, surface: EGLSurface, attribute: EGLint, value: *EGLint) callconv(.c) EGLBoolean;
pub const PFNEGLSWAPINTERVALPROC = *const fn (dpy: EGLDisplay, interval: EGLint) callconv(.c) EGLBoolean;

// ─── EGL wrapper ────────────────────────────────────────────

pub const Egl = struct {
    lib: std.DynLib,
    eglGetPlatformDisplay: PFNEGLGETPLATFORMDISPLAYEXTPROC,
    eglGetDisplay: PFNEGLGETDISPLAYPROC,
    eglQueryString: PFNEGLQUERYSTRINGPROC,
    eglGetError: PFNEGLGETERRORPROC,
    eglInitialize: PFNEGLINITIALIZEPROC,
    eglChooseConfig: PFNEGLCHOOSECONFIGPROC,
    eglCreateContext: PFNEGLCREATECONTEXTPROC,
    eglDestroyContext: PFNEGLDESTROYCONTEXTPROC,
    eglMakeCurrent: PFNEGLMAKECURRENTPROC,
    eglBindAPI: PFNEGLBINDAPIPROC,
    eglCreateImage: PFNEGLCREATEIMAGEPROC,
    eglDestroyImage: PFNEGLDESTROYIMAGEPROC,
    eglCreateWindowSurface: PFNEGLCREATEWINDOWSURFACEPROC,
    eglSwapBuffers: PFNEGLSWAPBUFFERSPROC,
    eglTerminate: PFNEGLTERMINATEPROC,
    eglDestroySurface: PFNEGLDESTROYSURFACEPROC,
    eglQuerySurface: PFNEGLQUERYSURFACEPROC,
    eglSwapInterval: PFNEGLSWAPINTERVALPROC,

    pub fn open() !Egl {
        var lib = try openEglLibrary();
        errdefer lib.close();
        return Egl{
            .lib = lib,
            .eglGetPlatformDisplay = lib.lookup(PFNEGLGETPLATFORMDISPLAYEXTPROC, "eglGetPlatformDisplayEXT") orelse lib.lookup(PFNEGLGETPLATFORMDISPLAYEXTPROC, "eglGetPlatformDisplay") orelse return error.Unexpected,
            .eglGetDisplay = lib.lookup(PFNEGLGETDISPLAYPROC, "eglGetDisplay") orelse return error.Unexpected,
            .eglQueryString = lib.lookup(PFNEGLQUERYSTRINGPROC, "eglQueryString") orelse return error.Unexpected,
            .eglGetError = lib.lookup(PFNEGLGETERRORPROC, "eglGetError") orelse return error.Unexpected,
            .eglInitialize = lib.lookup(PFNEGLINITIALIZEPROC, "eglInitialize") orelse return error.Unexpected,
            .eglChooseConfig = lib.lookup(PFNEGLCHOOSECONFIGPROC, "eglChooseConfig") orelse return error.Unexpected,
            .eglCreateContext = lib.lookup(PFNEGLCREATECONTEXTPROC, "eglCreateContext") orelse return error.Unexpected,
            .eglDestroyContext = lib.lookup(PFNEGLDESTROYCONTEXTPROC, "eglDestroyContext") orelse return error.Unexpected,
            .eglMakeCurrent = lib.lookup(PFNEGLMAKECURRENTPROC, "eglMakeCurrent") orelse return error.Unexpected,
            .eglBindAPI = lib.lookup(PFNEGLBINDAPIPROC, "eglBindAPI") orelse return error.Unexpected,
            .eglCreateImage = lib.lookup(PFNEGLCREATEIMAGEPROC, "eglCreateImage") orelse lib.lookup(PFNEGLCREATEIMAGEPROC, "eglCreateImageKHR") orelse return error.Unexpected,
            .eglDestroyImage = lib.lookup(PFNEGLDESTROYIMAGEPROC, "eglDestroyImage") orelse lib.lookup(PFNEGLDESTROYIMAGEPROC, "eglDestroyImageKHR") orelse return error.Unexpected,
            .eglCreateWindowSurface = lib.lookup(PFNEGLCREATEWINDOWSURFACEPROC, "eglCreateWindowSurface") orelse return error.Unexpected,
            .eglSwapBuffers = lib.lookup(PFNEGLSWAPBUFFERSPROC, "eglSwapBuffers") orelse return error.Unexpected,
            .eglTerminate = lib.lookup(PFNEGLTERMINATEPROC, "eglTerminate") orelse return error.Unexpected,
            .eglDestroySurface = lib.lookup(PFNEGLDESTROYSURFACEPROC, "eglDestroySurface") orelse return error.Unexpected,
            .eglQuerySurface = lib.lookup(PFNEGLQUERYSURFACEPROC, "eglQuerySurface") orelse return error.Unexpected,
            .eglSwapInterval = lib.lookup(PFNEGLSWAPINTERVALPROC, "eglSwapInterval") orelse return error.Unexpected,
        };
    }

    pub fn getError(self: *const Egl) EGLenum {
        return self.eglGetError();
    }

    pub fn queryString(self: *const Egl, dpy: EGLDisplay, name: EGLenum) ?[]const u8 {
        const ptr = self.eglQueryString(dpy, @intCast(name));
        return if (ptr == null) null else std.mem.sliceTo(ptr.?, 0);
    }
};

fn openEglLibrary() !std.DynLib {
    if (std.DynLib.openZ("libEGL.so.1")) |opened| {
        var lib = opened;
        if (lib.lookup(PFNEGLGETDISPLAYPROC, "eglGetDisplay") != null) return lib;
        lib.close();
    } else |_| {}
    if (std.DynLib.openZ("libEGL.so")) |opened| {
        var lib = opened;
        if (lib.lookup(PFNEGLGETDISPLAYPROC, "eglGetDisplay") != null) return lib;
        lib.close();
    } else |_| {}
    if (std.DynLib.openZ("libmali.so.0")) |lib| return lib else |_| {}
    return std.DynLib.openZ("libmali.so");
}

// ─── GBM types ──────────────────────────────────────────────

pub const GbmDevice = opaque {};
pub const GbmSurface = opaque {};
pub const GbmBo = opaque {};

pub const PFNGBMCREATEDEVICE = *const fn (fd: i32) callconv(.c) ?*GbmDevice;
pub const PFNGBMDEVICEDESTROY = *const fn (gbm: *GbmDevice) callconv(.c) void;
pub const PFNGBMDEVICEGETFD = *const fn (gbm: *GbmDevice) callconv(.c) i32;
pub const PFNGBMCREATESURFACE = *const fn (gbm: *GbmDevice, width: u32, height: u32, format: u32, flags: u32) callconv(.c) ?*GbmSurface;
pub const PFNGBMSURFACEDESTROY = *const fn (gs: *GbmSurface) callconv(.c) void;
pub const PFNGBMSURFACELOCKFRONTBUFFER = *const fn (gs: *GbmSurface) callconv(.c) ?*GbmBo;
pub const PFNGBMBOGETHANDLE = *const fn (bo: *GbmBo) callconv(.c) u32;
pub const PFNGBMBOGETSTRIDE = *const fn (bo: *GbmBo) callconv(.c) u32;
pub const PFNGBMBOGETWIDTH = *const fn (bo: *GbmBo) callconv(.c) u32;
pub const PFNGBMBOGETHEIGHT = *const fn (bo: *GbmBo) callconv(.c) u32;
pub const PFNGBMBORELEASE = *const fn (bo: *GbmBo) callconv(.c) void;
pub const PFNGBMSURFACERELEASEBUFFER = *const fn (gs: *GbmSurface, bo: *GbmBo) callconv(.c) void;

pub const Gbm = struct {
    lib: std.DynLib,
    gbmCreateDevice: PFNGBMCREATEDEVICE,
    gbmDeviceDestroy: PFNGBMDEVICEDESTROY,
    gbmDeviceGetFd: PFNGBMDEVICEGETFD,
    gbmCreateSurface: PFNGBMCREATESURFACE,
    gbmSurfaceDestroy: PFNGBMSURFACEDESTROY,
    gbmBoGetHandle: PFNGBMBOGETHANDLE,
    gbmBoGetStride: PFNGBMBOGETSTRIDE,
    gbmBoGetWidth: PFNGBMBOGETWIDTH,
    gbmBoGetHeight: PFNGBMBOGETHEIGHT,
    gbmBoRelease: PFNGBMBORELEASE,
    gbmSurfaceReleaseBuffer: PFNGBMSURFACERELEASEBUFFER,
    gbmSurfaceLockFrontBuffer: PFNGBMSURFACELOCKFRONTBUFFER,

    pub fn open() !Gbm {
        var lib = if (std.DynLib.openZ("libgbm.so.1")) |l| l else |_| try std.DynLib.openZ("libgbm.so");
        errdefer lib.close();
        return Gbm{
            .lib = lib,
            .gbmCreateDevice = lib.lookup(PFNGBMCREATEDEVICE, "gbm_create_device") orelse return error.Unexpected,
            .gbmDeviceDestroy = lib.lookup(PFNGBMDEVICEDESTROY, "gbm_device_destroy") orelse return error.Unexpected,
            .gbmDeviceGetFd = lib.lookup(PFNGBMDEVICEGETFD, "gbm_device_get_fd") orelse return error.Unexpected,
            .gbmCreateSurface = lib.lookup(PFNGBMCREATESURFACE, "gbm_surface_create") orelse return error.Unexpected,
            .gbmSurfaceDestroy = lib.lookup(PFNGBMSURFACEDESTROY, "gbm_surface_destroy") orelse return error.Unexpected,
            .gbmBoGetHandle = lib.lookup(PFNGBMBOGETHANDLE, "gbm_bo_get_handle") orelse return error.Unexpected,
            .gbmBoGetStride = lib.lookup(PFNGBMBOGETSTRIDE, "gbm_bo_get_stride") orelse return error.Unexpected,
            .gbmBoGetWidth = lib.lookup(PFNGBMBOGETWIDTH, "gbm_bo_get_width") orelse return error.Unexpected,
            .gbmBoGetHeight = lib.lookup(PFNGBMBOGETHEIGHT, "gbm_bo_get_height") orelse return error.Unexpected,
            .gbmBoRelease = lib.lookup(PFNGBMBORELEASE, "gbm_bo_release") orelse return error.Unexpected,
            .gbmSurfaceReleaseBuffer = lib.lookup(PFNGBMSURFACERELEASEBUFFER, "gbm_surface_release_buffer") orelse return error.Unexpected,
            .gbmSurfaceLockFrontBuffer = lib.lookup(PFNGBMSURFACELOCKFRONTBUFFER, "gbm_surface_lock_front_buffer") orelse return error.Unexpected,
        };
    }
};

// ─── GL types ───────────────────────────────────────────────

pub const GLenum = i32;
pub const GLint = i32;
pub const GLuint = u32;
pub const GLsizei = i32;
pub const GLboolean = u8;
pub const GLbitfield = i32;
pub const GLfloat = f32;
pub const GLsizeiptr = isize;
pub const GLintptr = isize;

pub const gl_texture_2d: GLenum = 0x0DE1;
pub const gl_texture0: GLenum = 0x84C0;
pub const gl_rgba: GLenum = 0x1908;
pub const gl_rgb: GLenum = 0x1907;
pub const gl_bgra: GLenum = 0x80E1;
pub const gl_unsigned_byte: GLenum = 0x1401;
pub const gl_texture_min_filter: GLenum = 0x2801;
pub const gl_texture_mag_filter: GLenum = 0x2800;
pub const gl_texture_wrap_s: GLenum = 0x2802;
pub const gl_texture_wrap_t: GLenum = 0x2803;
pub const gl_linear: GLenum = 0x2601;
pub const gl_clamp_to_edge: GLenum = 0x812F;
pub const gl_blend: GLenum = 0x0BE2;
pub const gl_one: GLenum = 1;
pub const gl_one_minus_src_alpha: GLenum = 0x0303;
pub const gl_src_alpha: GLenum = 0x0302;
pub const gl_func_add: GLenum = 0x8006;
pub const gl_color_buffer_bit: GLbitfield = 0x00004000;
pub const gl_array_buffer: GLenum = 0x8892;
pub const gl_element_array_buffer: GLenum = 0x8893;
pub const gl_static_draw: GLenum = 0x88E4;
pub const gl_float: GLenum = 0x1406;
pub const gl_false: GLboolean = 0;
pub const gl_true: GLboolean = 1;
pub const gl_fragment_shader: GLenum = 0x8B30;
pub const gl_vertex_shader: GLenum = 0x8B31;
pub const gl_compile_status: GLenum = 0x8B81;
pub const gl_link_status: GLenum = 0x8B82;
pub const gl_framebuffer: GLenum = 0x8D40;
pub const gl_color_attachment0: GLenum = 0x8CE0;
pub const gl_framebuffer_complete: GLenum = 0x8CD5;
pub const gl_triangles: GLenum = 0x0004;
pub const gl_unsigned_short: GLenum = 0x1403;

// ─── GL function pointer types ──────────────────────────────

pub const PFNGLGENTEXTURESPROC = *const fn (n: GLsizei, textures: *GLuint) callconv(.c) void;
pub const PFNGLBINDTEXTUREPROC = *const fn (target: GLenum, texture: GLuint) callconv(.c) void;
pub const PFNGLTEXPARAMETERIPROC = *const fn (target: GLenum, pname: GLenum, param: GLint) callconv(.c) void;
pub const PFNGLTEXIMAGE2DPROC = *const fn (target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, ty: GLenum, pixels: *const anyopaque) callconv(.c) void;
pub const PFNGLTEXSUBIMAGE2DPROC = *const fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, ty: GLenum, pixels: *const anyopaque) callconv(.c) void;
pub const PFNGLDELETETEXTURESPROC = *const fn (n: GLsizei, textures: *const GLuint) callconv(.c) void;
pub const PFNGLENABLEPROC = *const fn (cap: GLenum) callconv(.c) void;
pub const PFNGLDISABLEPROC = *const fn (cap: GLenum) callconv(.c) void;
pub const PFNGLBLENDFUNCPROC = *const fn (sfactor: GLenum, dfactor: GLenum) callconv(.c) void;
pub const PFNGLBLENDEQUATIONPROC = *const fn (mode: GLenum) callconv(.c) void;
pub const PFNGLCLEARCOLORPROC = *const fn (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.c) void;
pub const PFNGLCLEARPROC = *const fn (mask: GLbitfield) callconv(.c) void;
pub const PFNGLDRAWARRAYSPROC = *const fn (mode: GLenum, first: GLint, count: GLsizei) callconv(.c) void;
pub const PFNGLDRAWELEMENTSPROC = *const fn (mode: GLenum, count: GLsizei, ty: GLenum, indices: *const anyopaque) callconv(.c) void;
pub const PFNGLACTIVETEXTUREPROC = *const fn (texture: GLenum) callconv(.c) void;
pub const PFNGLVIEWPORTPROC = *const fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei) callconv(.c) void;
pub const PFNGLFINISHPROC = *const fn () callconv(.c) void;
pub const PFNGLFLUSHPROC = *const fn () callconv(.c) void;
pub const PFNGLREADPIXELSPROC = *const fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, ty: GLenum, pixels: *anyopaque) callconv(.c) void;
pub const PFNGLCREATESHADERPROC = *const fn (shaderType: GLenum) callconv(.c) GLuint;
pub const PFNGLSHADERSOURCEPROC = *const fn (shader: GLuint, count: GLsizei, string: [*]const [*:0]const u8, length: [*]const GLint) callconv(.c) void;
pub const PFNGLCOMPILESHADERPROC = *const fn (shader: GLuint) callconv(.c) void;
pub const PFNGLGETSHADERIVPROC = *const fn (shader: GLuint, pname: GLenum, params: *GLint) callconv(.c) void;
pub const PFNGLGETSHADERINFOLOGPROC = *const fn (shader: GLuint, bufSize: GLsizei, length: *GLsizei, infoLog: [*]u8) callconv(.c) void;
pub const PFNGLCREATEPROGRAMPROC = *const fn () callconv(.c) GLuint;
pub const PFNGLATTACHSHADERPROC = *const fn (program: GLuint, shader: GLuint) callconv(.c) void;
pub const PFNGLLINKPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLGETPROGRAMIVPROC = *const fn (program: GLuint, pname: GLenum, params: *GLint) callconv(.c) void;
pub const PFNGLGETPROGRAMINFOLOGPROC = *const fn (program: GLuint, bufSize: GLsizei, length: *GLsizei, infoLog: [*]u8) callconv(.c) void;
pub const PFNGLUSEPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLGETATTRIBLOCATIONPROC = *const fn (program: GLuint, name: [*:0]const u8) callconv(.c) GLint;
pub const PFNGLGETUNIFORMLOCATIONPROC = *const fn (program: GLuint, name: [*:0]const u8) callconv(.c) GLint;
pub const PFNGLENABLEVERTEXATTRIBARRAYPROC = *const fn (index: GLuint) callconv(.c) void;
pub const PFNGLVERTEXATTRIBPOINTERPROC = *const fn (index: GLuint, size: GLint, ty: GLenum, normalized: GLboolean, stride: GLsizei, pointer: *const anyopaque) callconv(.c) void;
pub const PFNGLUNIFORM1IPROC = *const fn (location: GLint, v0: GLint) callconv(.c) void;
pub const PFNGLDELETESHADERPROC = *const fn (shader: GLuint) callconv(.c) void;
pub const PFNGLDELETEPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLGENFRAMEBUFFERSPROC = *const fn (n: GLsizei, framebuffers: *GLuint) callconv(.c) void;
pub const PFNGLBINDFRAMEBUFFERPROC = *const fn (target: GLenum, framebuffer: GLuint) callconv(.c) void;
pub const PFNGLFRAMEBUFFERTEXTURE2DPROC = *const fn (target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) callconv(.c) void;
pub const PFNGLCHECKFRAMEBUFFERSTATUSPROC = *const fn (target: GLenum) callconv(.c) GLenum;
pub const PFNGLDELETEFRAMEBUFFERSPROC = *const fn (n: GLsizei, framebuffers: *const GLuint) callconv(.c) void;
pub const PFNGLGENRENDERBUFFERSPROC = *const fn (n: GLsizei, renderbuffers: *GLuint) callconv(.c) void;
pub const PFNGLBINDRENDERBUFFERPROC = *const fn (target: GLenum, renderbuffer: GLuint) callconv(.c) void;
pub const PFNGLRENDERBUFFERSTORAGEPROC = *const fn (target: GLenum, internalformat: GLenum, width: GLsizei, height: GLsizei) callconv(.c) void;
pub const PFNGLFRAMEBUFFERRENDERBUFFERPROC = *const fn (target: GLenum, attachment: GLenum, renderbuffertarget: GLenum, renderbuffer: GLuint) callconv(.c) void;
pub const PFNGLDELETERENDERBUFFERSPROC = *const fn (n: GLsizei, renderbuffers: *const GLuint) callconv(.c) void;
pub const PFNGLGENVERTEXARRAYSPROC = *const fn (n: GLsizei, arrays: *GLuint) callconv(.c) void;
pub const PFNGLBINDVERTEXARRAYPROC = *const fn (array: GLuint) callconv(.c) void;
pub const PFNGLGENBUFFERSPROC = *const fn (n: GLsizei, buffers: *GLuint) callconv(.c) void;
pub const PFNGLBINDBUFFERPROC = *const fn (target: GLenum, buffer: GLuint) callconv(.c) void;
pub const PFNGLBUFFERDATAPROC = *const fn (target: GLenum, size: GLsizeiptr, data: *const anyopaque, usage: GLenum) callconv(.c) void;
pub const PFNGLDELETEBUFFERSPROC = *const fn (n: GLsizei, buffers: *const GLuint) callconv(.c) void;
pub const PFNGLDELETEVERTEXARRAYSPROC = *const fn (n: GLsizei, arrays: *const GLuint) callconv(.c) void;

// ─── GL wrapper ─────────────────────────────────────────────

pub const Gl = struct {
    lib: std.DynLib,
    glGenTextures: PFNGLGENTEXTURESPROC,
    glBindTexture: PFNGLBINDTEXTUREPROC,
    glTexParameteri: PFNGLTEXPARAMETERIPROC,
    glTexImage2D: PFNGLTEXIMAGE2DPROC,
    glTexSubImage2D: PFNGLTEXSUBIMAGE2DPROC,
    glDeleteTextures: PFNGLDELETETEXTURESPROC,
    glEnable: PFNGLENABLEPROC,
    glDisable: PFNGLDISABLEPROC,
    glBlendFunc: PFNGLBLENDFUNCPROC,
    glBlendEquation: PFNGLBLENDEQUATIONPROC,
    glClearColor: PFNGLCLEARCOLORPROC,
    glClear: PFNGLCLEARPROC,
    glDrawArrays: PFNGLDRAWARRAYSPROC,
    glDrawElements: PFNGLDRAWELEMENTSPROC,
    glActiveTexture: PFNGLACTIVETEXTUREPROC,
    glViewport: PFNGLVIEWPORTPROC,
    glFinish: PFNGLFINISHPROC,
    glFlush: PFNGLFLUSHPROC,
    glReadPixels: PFNGLREADPIXELSPROC,
    glCreateShader: PFNGLCREATESHADERPROC,
    glShaderSource: PFNGLSHADERSOURCEPROC,
    glCompileShader: PFNGLCOMPILESHADERPROC,
    glGetShaderiv: PFNGLGETSHADERIVPROC,
    glGetShaderInfoLog: PFNGLGETSHADERINFOLOGPROC,
    glCreateProgram: PFNGLCREATEPROGRAMPROC,
    glAttachShader: PFNGLATTACHSHADERPROC,
    glLinkProgram: PFNGLLINKPROGRAMPROC,
    glGetProgramiv: PFNGLGETPROGRAMIVPROC,
    glGetProgramInfoLog: PFNGLGETPROGRAMINFOLOGPROC,
    glUseProgram: PFNGLUSEPROGRAMPROC,
    glGetAttribLocation: PFNGLGETATTRIBLOCATIONPROC,
    glGetUniformLocation: PFNGLGETUNIFORMLOCATIONPROC,
    glEnableVertexAttribArray: PFNGLENABLEVERTEXATTRIBARRAYPROC,
    glVertexAttribPointer: PFNGLVERTEXATTRIBPOINTERPROC,
    glUniform1i: PFNGLUNIFORM1IPROC,
    glDeleteShader: PFNGLDELETESHADERPROC,
    glDeleteProgram: PFNGLDELETEPROGRAMPROC,
    glGenFramebuffers: PFNGLGENFRAMEBUFFERSPROC,
    glBindFramebuffer: PFNGLBINDFRAMEBUFFERPROC,
    glFramebufferTexture2D: PFNGLFRAMEBUFFERTEXTURE2DPROC,
    glCheckFramebufferStatus: PFNGLCHECKFRAMEBUFFERSTATUSPROC,
    glDeleteFramebuffers: PFNGLDELETEFRAMEBUFFERSPROC,
    glGenRenderbuffers: PFNGLGENRENDERBUFFERSPROC,
    glBindRenderbuffer: PFNGLBINDRENDERBUFFERPROC,
    glRenderbufferStorage: PFNGLRENDERBUFFERSTORAGEPROC,
    glFramebufferRenderbuffer: PFNGLFRAMEBUFFERRENDERBUFFERPROC,
    glDeleteRenderbuffers: PFNGLDELETERENDERBUFFERSPROC,
    glGenVertexArrays: PFNGLGENVERTEXARRAYSPROC,
    glBindVertexArray: PFNGLBINDVERTEXARRAYPROC,
    glGenBuffers: PFNGLGENBUFFERSPROC,
    glBindBuffer: PFNGLBINDBUFFERPROC,
    glBufferData: PFNGLBUFFERDATAPROC,
    glDeleteBuffers: PFNGLDELETEBUFFERSPROC,
    glDeleteVertexArrays: PFNGLDELETEVERTEXARRAYSPROC,

    pub fn open() !Gl {
        const lib = std.DynLib.openZ("libGL.so.1") catch return error.Unexpected;
        errdefer lib.close();
        return Gl{
            .lib = lib,
            .glGenTextures = lib.lookup(PFNGLGENTEXTURESPROC, "glGenTextures") orelse return error.Unexpected,
            .glBindTexture = lib.lookup(PFNGLBINDTEXTUREPROC, "glBindTexture") orelse return error.Unexpected,
            .glTexParameteri = lib.lookup(PFNGLTEXPARAMETERIPROC, "glTexParameteri") orelse return error.Unexpected,
            .glTexImage2D = lib.lookup(PFNGLTEXIMAGE2DPROC, "glTexImage2D") orelse return error.Unexpected,
            .glTexSubImage2D = lib.lookup(PFNGLTEXSUBIMAGE2DPROC, "glTexSubImage2D") orelse return error.Unexpected,
            .glDeleteTextures = lib.lookup(PFNGLDELETETEXTURESPROC, "glDeleteTextures") orelse return error.Unexpected,
            .glEnable = lib.lookup(PFNGLENABLEPROC, "glEnable") orelse return error.Unexpected,
            .glDisable = lib.lookup(PFNGLDISABLEPROC, "glDisable") orelse return error.Unexpected,
            .glBlendFunc = lib.lookup(PFNGLBLENDFUNCPROC, "glBlendFunc") orelse return error.Unexpected,
            .glBlendEquation = lib.lookup(PFNGLBLENDEQUATIONPROC, "glBlendEquation") orelse return error.Unexpected,
            .glClearColor = lib.lookup(PFNGLCLEARCOLORPROC, "glClearColor") orelse return error.Unexpected,
            .glClear = lib.lookup(PFNGLCLEARPROC, "glClear") orelse return error.Unexpected,
            .glDrawArrays = lib.lookup(PFNGLDRAWARRAYSPROC, "glDrawArrays") orelse return error.Unexpected,
            .glDrawElements = lib.lookup(PFNGLDRAWELEMENTSPROC, "glDrawElements") orelse return error.Unexpected,
            .glActiveTexture = lib.lookup(PFNGLACTIVETEXTUREPROC, "glActiveTexture") orelse return error.Unexpected,
            .glViewport = lib.lookup(PFNGLVIEWPORTPROC, "glViewport") orelse return error.Unexpected,
            .glFinish = lib.lookup(PFNGLFINISHPROC, "glFinish") orelse return error.Unexpected,
            .glFlush = lib.lookup(PFNGLFLUSHPROC, "glFlush") orelse return error.Unexpected,
            .glReadPixels = lib.lookup(PFNGLREADPIXELSPROC, "glReadPixels") orelse return error.Unexpected,
            .glCreateShader = lib.lookup(PFNGLCREATESHADERPROC, "glCreateShader") orelse return error.Unexpected,
            .glShaderSource = lib.lookup(PFNGLSHADERSOURCEPROC, "glShaderSource") orelse return error.Unexpected,
            .glCompileShader = lib.lookup(PFNGLCOMPILESHADERPROC, "glCompileShader") orelse return error.Unexpected,
            .glGetShaderiv = lib.lookup(PFNGLGETSHADERIVPROC, "glGetShaderiv") orelse return error.Unexpected,
            .glGetShaderInfoLog = lib.lookup(PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog") orelse return error.Unexpected,
            .glCreateProgram = lib.lookup(PFNGLCREATEPROGRAMPROC, "glCreateProgram") orelse return error.Unexpected,
            .glAttachShader = lib.lookup(PFNGLATTACHSHADERPROC, "glAttachShader") orelse return error.Unexpected,
            .glLinkProgram = lib.lookup(PFNGLLINKPROGRAMPROC, "glLinkProgram") orelse return error.Unexpected,
            .glGetProgramiv = lib.lookup(PFNGLGETPROGRAMIVPROC, "glGetProgramiv") orelse return error.Unexpected,
            .glGetProgramInfoLog = lib.lookup(PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog") orelse return error.Unexpected,
            .glUseProgram = lib.lookup(PFNGLUSEPROGRAMPROC, "glUseProgram") orelse return error.Unexpected,
            .glGetAttribLocation = lib.lookup(PFNGLGETATTRIBLOCATIONPROC, "glGetAttribLocation") orelse return error.Unexpected,
            .glGetUniformLocation = lib.lookup(PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation") orelse return error.Unexpected,
            .glEnableVertexAttribArray = lib.lookup(PFNGLENABLEVERTEXATTRIBARRAYPROC, "glEnableVertexAttribArray") orelse return error.Unexpected,
            .glVertexAttribPointer = lib.lookup(PFNGLVERTEXATTRIBPOINTERPROC, "glVertexAttribPointer") orelse return error.Unexpected,
            .glUniform1i = lib.lookup(PFNGLUNIFORM1IPROC, "glUniform1i") orelse return error.Unexpected,
            .glDeleteShader = lib.lookup(PFNGLDELETESHADERPROC, "glDeleteShader") orelse return error.Unexpected,
            .glDeleteProgram = lib.lookup(PFNGLDELETEPROGRAMPROC, "glDeleteProgram") orelse return error.Unexpected,
            .glGenFramebuffers = lib.lookup(PFNGLGENFRAMEBUFFERSPROC, "glGenFramebuffers") orelse return error.Unexpected,
            .glBindFramebuffer = lib.lookup(PFNGLBINDFRAMEBUFFERPROC, "glBindFramebuffer") orelse return error.Unexpected,
            .glFramebufferTexture2D = lib.lookup(PFNGLFRAMEBUFFERTEXTURE2DPROC, "glFramebufferTexture2D") orelse return error.Unexpected,
            .glCheckFramebufferStatus = lib.lookup(PFNGLCHECKFRAMEBUFFERSTATUSPROC, "glCheckFramebufferStatus") orelse return error.Unexpected,
            .glDeleteFramebuffers = lib.lookup(PFNGLDELETEFRAMEBUFFERSPROC, "glDeleteFramebuffers") orelse return error.Unexpected,
            .glGenRenderbuffers = lib.lookup(PFNGLGENRENDERBUFFERSPROC, "glGenRenderbuffers") orelse return error.Unexpected,
            .glBindRenderbuffer = lib.lookup(PFNGLBINDRENDERBUFFERPROC, "glBindRenderbuffer") orelse return error.Unexpected,
            .glRenderbufferStorage = lib.lookup(PFNGLRENDERBUFFERSTORAGEPROC, "glRenderbufferStorage") orelse return error.Unexpected,
            .glFramebufferRenderbuffer = lib.lookup(PFNGLFRAMEBUFFERRENDERBUFFERPROC, "glFramebufferRenderbuffer") orelse return error.Unexpected,
            .glDeleteRenderbuffers = lib.lookup(PFNGLDELETERENDERBUFFERSPROC, "glDeleteRenderbuffers") orelse return error.Unexpected,
            .glGenVertexArrays = lib.lookup(PFNGLGENVERTEXARRAYSPROC, "glGenVertexArrays") orelse return error.Unexpected,
            .glBindVertexArray = lib.lookup(PFNGLBINDVERTEXARRAYPROC, "glBindVertexArray") orelse return error.Unexpected,
            .glGenBuffers = lib.lookup(PFNGLGENBUFFERSPROC, "glGenBuffers") orelse return error.Unexpected,
            .glBindBuffer = lib.lookup(PFNGLBINDBUFFERPROC, "glBindBuffer") orelse return error.Unexpected,
            .glBufferData = lib.lookup(PFNGLBUFFERDATAPROC, "glBufferData") orelse return error.Unexpected,
            .glDeleteBuffers = lib.lookup(PFNGLDELETEBUFFERSPROC, "glDeleteBuffers") orelse return error.Unexpected,
            .glDeleteVertexArrays = lib.lookup(PFNGLDELETEVERTEXARRAYSPROC, "glDeleteVertexArrays") orelse return error.Unexpected,
        };
    }
};
