const std = @import("std");
const gpu = @import("linux_gpu.zig");

pub const GLenum = gpu.GLenum;
pub const GLint = gpu.GLint;
pub const GLuint = gpu.GLuint;
pub const GLsizei = gpu.GLsizei;
pub const GLboolean = gpu.GLboolean;
pub const GLbitfield = gpu.GLbitfield;
pub const GLfloat = gpu.GLfloat;
pub const GLsizeiptr = gpu.GLsizeiptr;
pub const GLintptr = gpu.GLintptr;
pub const GLubyte = u8;
pub const GLchar = u8;

pub const gl_dither: GLenum = 0x0BD0;
pub const gl_blend: GLenum = 0x0BE2;
pub const gl_one: GLenum = 1;
pub const gl_one_minus_src_alpha: GLenum = 0x0303;
pub const gl_linear: GLenum = 0x2601;
pub const gl_color_buffer_bit: GLbitfield = 0x00004000;
pub const gl_framebuffer: GLenum = 0x8D40;
pub const gl_color_attachment0: GLenum = 0x8CE0;
pub const gl_texture_2d: GLenum = 0x0DE1;
pub const gl_framebuffer_complete: GLenum = 0x8CD5;
pub const gl_pack_alignment: GLenum = 0x0D05;
pub const gl_rgba: GLenum = 0x1908;
pub const gl_unsigned_byte: GLenum = 0x1401;
pub const gl_renderer: GLenum = 0x1F01;
pub const gl_array_buffer: GLenum = 0x8892;
pub const gl_static_draw: GLenum = 0x88E4;
pub const gl_float: GLenum = 0x1406;
pub const gl_false: GLboolean = 0;
pub const gl_triangle_strip: GLenum = 0x0005;
pub const gl_texture0: GLenum = 0x84C0;
pub const gl_triangles: GLenum = 0x0004;
pub const gl_dynamic_draw: GLenum = 0x88E8;
pub const gl_texture_min_filter: GLenum = 0x2801;
pub const gl_texture_mag_filter: GLenum = 0x2800;
pub const gl_texture_wrap_s: GLenum = 0x2802;
pub const gl_texture_wrap_t: GLenum = 0x2803;
pub const gl_clamp_to_edge: GLenum = 0x812F;
pub const gl_alpha: GLenum = 0x1906;
pub const gl_unpack_alignment: GLenum = 0x0CF5;
pub const gl_nearest: GLenum = 0x2600;
pub const gl_vertex_shader: GLenum = 0x8B31;
pub const gl_fragment_shader: GLenum = 0x8B30;
pub const gl_link_status: GLenum = 0x8B82;
pub const gl_compile_status: GLenum = 0x8B81;

pub const PFNGLACTIVETEXTUREPROC = *const fn (texture: GLenum) callconv(.c) void;
pub const PFNGLATTACHSHADERPROC = *const fn (program: GLuint, shader: GLuint) callconv(.c) void;
pub const PFNGLBINDATTRIBLOCATIONPROC = *const fn (program: GLuint, index: GLuint, name: [*:0]const GLchar) callconv(.c) void;
pub const PFNGLBINDBUFFERPROC = *const fn (target: GLenum, buffer: GLuint) callconv(.c) void;
pub const PFNGLBINDFRAMEBUFFERPROC = *const fn (target: GLenum, fb: GLuint) callconv(.c) void;
pub const PFNGLBINDTEXTUREPROC = *const fn (target: GLenum, texture: GLuint) callconv(.c) void;
pub const PFNGLBLENDFUNCSEPARATEPROC = *const fn (src_rgb: GLenum, dst_rgb: GLenum, src_a: GLenum, dst_a: GLenum) callconv(.c) void;
pub const PFNGLBUFFERDATAPROC = *const fn (target: GLenum, size: GLsizeiptr, data: *const anyopaque, usage: GLenum) callconv(.c) void;
pub const PFNGLCHECKFRAMEBUFFERSTATUSPROC = *const fn (target: GLenum) callconv(.c) GLenum;
pub const PFNGLCLEARPROC = *const fn (mask: GLbitfield) callconv(.c) void;
pub const PFNGLCLEARCOLORPROC = *const fn (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.c) void;
pub const PFNGLCOMPILESHADERPROC = *const fn (shader: GLuint) callconv(.c) void;
pub const PFNGLCREATEPROGRAMPROC = *const fn () callconv(.c) GLuint;
pub const PFNGLCREATESHADERPROC = *const fn (type_: GLenum) callconv(.c) GLuint;
pub const PFNGLDELETEBUFFERSPROC = *const fn (n: GLsizei, buffers: [*]const GLuint) callconv(.c) void;
pub const PFNGLDELETEFRAMEBUFFERSPROC = *const fn (n: GLsizei, fbs: [*]const GLuint) callconv(.c) void;
pub const PFNGLDELETEPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLDELETESHADERPROC = *const fn (shader: GLuint) callconv(.c) void;
pub const PFNGLDELETETEXTURESPROC = *const fn (n: GLsizei, textures: [*]const GLuint) callconv(.c) void;
pub const PFNGLDISABLEPROC = *const fn (cap: GLenum) callconv(.c) void;
pub const PFNGLDRAWARRAYSPROC = *const fn (mode: GLenum, first: GLint, count: GLsizei) callconv(.c) void;
pub const PFNGLENABLEPROC = *const fn (cap: GLenum) callconv(.c) void;
pub const PFNGLENABLEVERTEXATTRIBARRAYPROC = *const fn (index: GLuint) callconv(.c) void;
pub const PFNGLFINISHPROC = *const fn () callconv(.c) void;
pub const PFNGLFRAMEBUFFERTEXTURE2DPROC = *const fn (target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) callconv(.c) void;
pub const PFNGLGENBUFFERSPROC = *const fn (n: GLsizei, buffers: [*]GLuint) callconv(.c) void;
pub const PFNGLGENFRAMEBUFFERSPROC = *const fn (n: GLsizei, fbs: [*]GLuint) callconv(.c) void;
pub const PFNGLGENTEXTURESPROC = *const fn (n: GLsizei, textures: [*]GLuint) callconv(.c) void;
pub const PFNGLGETPROGRAMIVPROC = *const fn (program: GLuint, pname: GLenum, params: *GLint) callconv(.c) void;
pub const PFNGLGETSHADERINFOLOGPROC = *const fn (shader: GLuint, buf_size: GLsizei, length: ?*GLsizei, info_log: [*]GLchar) callconv(.c) void;
pub const PFNGLGETSHADERIVPROC = *const fn (shader: GLuint, pname: GLenum, params: *GLint) callconv(.c) void;
pub const PFNGLGETSTRINGPROC = *const fn (name: GLenum) callconv(.c) ?[*:0]const GLubyte;
pub const PFNGLGETUNIFORMLOCATIONPROC = *const fn (program: GLuint, name: [*:0]const GLchar) callconv(.c) GLint;
pub const PFNGLLINKPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLPIXELSTOREIPROC = *const fn (pname: GLenum, param: GLint) callconv(.c) void;
pub const PFNGLREADPIXELSPROC = *const fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, type_: GLenum, pixels: *anyopaque) callconv(.c) void;
pub const PFNGLSHADERSOURCEPROC = *const fn (shader: GLuint, count: GLsizei, string: [*]const [*:0]const GLchar, length: ?[*]const GLint) callconv(.c) void;
pub const PFNGLTEXIMAGE2DPROC = *const fn (target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, type_: GLenum, pixels: ?*const anyopaque) callconv(.c) void;
pub const PFNGLTEXPARAMETERIPROC = *const fn (target: GLenum, pname: GLenum, param: GLint) callconv(.c) void;
pub const PFNGLTEXSUBIMAGE2DPROC = *const fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, type_: GLenum, pixels: *const anyopaque) callconv(.c) void;
pub const PFNGLUNIFORM1FPROC = *const fn (location: GLint, v0: GLfloat) callconv(.c) void;
pub const PFNGLUNIFORM1IPROC = *const fn (location: GLint, v0: GLint) callconv(.c) void;
pub const PFNGLUNIFORM2FPROC = *const fn (location: GLint, v0: GLfloat, v1: GLfloat) callconv(.c) void;
pub const PFNGLUNIFORM4FPROC = *const fn (location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat, v3: GLfloat) callconv(.c) void;
pub const PFNGLUSEPROGRAMPROC = *const fn (program: GLuint) callconv(.c) void;
pub const PFNGLVERTEXATTRIBPOINTERPROC = *const fn (index: GLuint, size: GLint, type_: GLenum, normalized: GLboolean, stride: GLsizei, pointer: *const anyopaque) callconv(.c) void;
pub const PFNGLVIEWPORTPROC = *const fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei) callconv(.c) void;

pub const Gles2 = struct {
    lib: std.DynLib,
    glActiveTexture: PFNGLACTIVETEXTUREPROC,
    glAttachShader: PFNGLATTACHSHADERPROC,
    glBindAttribLocation: PFNGLBINDATTRIBLOCATIONPROC,
    glBindBuffer: PFNGLBINDBUFFERPROC,
    glBindFramebuffer: PFNGLBINDFRAMEBUFFERPROC,
    glBindTexture: PFNGLBINDTEXTUREPROC,
    glBlendFuncSeparate: PFNGLBLENDFUNCSEPARATEPROC,
    glBufferData: PFNGLBUFFERDATAPROC,
    glCheckFramebufferStatus: PFNGLCHECKFRAMEBUFFERSTATUSPROC,
    glClear: PFNGLCLEARPROC,
    glClearColor: PFNGLCLEARCOLORPROC,
    glCompileShader: PFNGLCOMPILESHADERPROC,
    glCreateProgram: PFNGLCREATEPROGRAMPROC,
    glCreateShader: PFNGLCREATESHADERPROC,
    glDeleteBuffers: PFNGLDELETEBUFFERSPROC,
    glDeleteFramebuffers: PFNGLDELETEFRAMEBUFFERSPROC,
    glDeleteProgram: PFNGLDELETEPROGRAMPROC,
    glDeleteShader: PFNGLDELETESHADERPROC,
    glDeleteTextures: PFNGLDELETETEXTURESPROC,
    glDisable: PFNGLDISABLEPROC,
    glDrawArrays: PFNGLDRAWARRAYSPROC,
    glEnable: PFNGLENABLEPROC,
    glEnableVertexAttribArray: PFNGLENABLEVERTEXATTRIBARRAYPROC,
    glFinish: PFNGLFINISHPROC,
    glFramebufferTexture2D: PFNGLFRAMEBUFFERTEXTURE2DPROC,
    glGenBuffers: PFNGLGENBUFFERSPROC,
    glGenFramebuffers: PFNGLGENFRAMEBUFFERSPROC,
    glGenTextures: PFNGLGENTEXTURESPROC,
    glGetProgramiv: PFNGLGETPROGRAMIVPROC,
    glGetShaderInfoLog: PFNGLGETSHADERINFOLOGPROC,
    glGetShaderiv: PFNGLGETSHADERIVPROC,
    glGetString: PFNGLGETSTRINGPROC,
    glGetUniformLocation: PFNGLGETUNIFORMLOCATIONPROC,
    glLinkProgram: PFNGLLINKPROGRAMPROC,
    glPixelStorei: PFNGLPIXELSTOREIPROC,
    glReadPixels: PFNGLREADPIXELSPROC,
    glShaderSource: PFNGLSHADERSOURCEPROC,
    glTexImage2D: PFNGLTEXIMAGE2DPROC,
    glTexParameteri: PFNGLTEXPARAMETERIPROC,
    glTexSubImage2D: PFNGLTEXSUBIMAGE2DPROC,
    glUniform1f: PFNGLUNIFORM1FPROC,
    glUniform1i: PFNGLUNIFORM1IPROC,
    glUniform2f: PFNGLUNIFORM2FPROC,
    glUniform4f: PFNGLUNIFORM4FPROC,
    glUseProgram: PFNGLUSEPROGRAMPROC,
    glVertexAttribPointer: PFNGLVERTEXATTRIBPOINTERPROC,
    glViewport: PFNGLVIEWPORTPROC,

    pub fn open() !Gles2 {
        var lib = if (std.DynLib.openZ("libGLESv2.so.2")) |l| l else |_| try std.DynLib.openZ("libGLESv2.so");
        errdefer lib.close();
        return Gles2{
            .lib = lib,
            .glActiveTexture = lib.lookup(PFNGLACTIVETEXTUREPROC, "glActiveTexture") orelse return error.Unexpected,
            .glAttachShader = lib.lookup(PFNGLATTACHSHADERPROC, "glAttachShader") orelse return error.Unexpected,
            .glBindAttribLocation = lib.lookup(PFNGLBINDATTRIBLOCATIONPROC, "glBindAttribLocation") orelse return error.Unexpected,
            .glBindBuffer = lib.lookup(PFNGLBINDBUFFERPROC, "glBindBuffer") orelse return error.Unexpected,
            .glBindFramebuffer = lib.lookup(PFNGLBINDFRAMEBUFFERPROC, "glBindFramebuffer") orelse return error.Unexpected,
            .glBindTexture = lib.lookup(PFNGLBINDTEXTUREPROC, "glBindTexture") orelse return error.Unexpected,
            .glBlendFuncSeparate = lib.lookup(PFNGLBLENDFUNCSEPARATEPROC, "glBlendFuncSeparate") orelse return error.Unexpected,
            .glBufferData = lib.lookup(PFNGLBUFFERDATAPROC, "glBufferData") orelse return error.Unexpected,
            .glCheckFramebufferStatus = lib.lookup(PFNGLCHECKFRAMEBUFFERSTATUSPROC, "glCheckFramebufferStatus") orelse return error.Unexpected,
            .glClear = lib.lookup(PFNGLCLEARPROC, "glClear") orelse return error.Unexpected,
            .glClearColor = lib.lookup(PFNGLCLEARCOLORPROC, "glClearColor") orelse return error.Unexpected,
            .glCompileShader = lib.lookup(PFNGLCOMPILESHADERPROC, "glCompileShader") orelse return error.Unexpected,
            .glCreateProgram = lib.lookup(PFNGLCREATEPROGRAMPROC, "glCreateProgram") orelse return error.Unexpected,
            .glCreateShader = lib.lookup(PFNGLCREATESHADERPROC, "glCreateShader") orelse return error.Unexpected,
            .glDeleteBuffers = lib.lookup(PFNGLDELETEBUFFERSPROC, "glDeleteBuffers") orelse return error.Unexpected,
            .glDeleteFramebuffers = lib.lookup(PFNGLDELETEFRAMEBUFFERSPROC, "glDeleteFramebuffers") orelse return error.Unexpected,
            .glDeleteProgram = lib.lookup(PFNGLDELETEPROGRAMPROC, "glDeleteProgram") orelse return error.Unexpected,
            .glDeleteShader = lib.lookup(PFNGLDELETESHADERPROC, "glDeleteShader") orelse return error.Unexpected,
            .glDeleteTextures = lib.lookup(PFNGLDELETETEXTURESPROC, "glDeleteTextures") orelse return error.Unexpected,
            .glDisable = lib.lookup(PFNGLDISABLEPROC, "glDisable") orelse return error.Unexpected,
            .glDrawArrays = lib.lookup(PFNGLDRAWARRAYSPROC, "glDrawArrays") orelse return error.Unexpected,
            .glEnable = lib.lookup(PFNGLENABLEPROC, "glEnable") orelse return error.Unexpected,
            .glEnableVertexAttribArray = lib.lookup(PFNGLENABLEVERTEXATTRIBARRAYPROC, "glEnableVertexAttribArray") orelse return error.Unexpected,
            .glFinish = lib.lookup(PFNGLFINISHPROC, "glFinish") orelse return error.Unexpected,
            .glFramebufferTexture2D = lib.lookup(PFNGLFRAMEBUFFERTEXTURE2DPROC, "glFramebufferTexture2D") orelse return error.Unexpected,
            .glGenBuffers = lib.lookup(PFNGLGENBUFFERSPROC, "glGenBuffers") orelse return error.Unexpected,
            .glGenFramebuffers = lib.lookup(PFNGLGENFRAMEBUFFERSPROC, "glGenFramebuffers") orelse return error.Unexpected,
            .glGenTextures = lib.lookup(PFNGLGENTEXTURESPROC, "glGenTextures") orelse return error.Unexpected,
            .glGetProgramiv = lib.lookup(PFNGLGETPROGRAMIVPROC, "glGetProgramiv") orelse return error.Unexpected,
            .glGetShaderInfoLog = lib.lookup(PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog") orelse return error.Unexpected,
            .glGetShaderiv = lib.lookup(PFNGLGETSHADERIVPROC, "glGetShaderiv") orelse return error.Unexpected,
            .glGetString = lib.lookup(PFNGLGETSTRINGPROC, "glGetString") orelse return error.Unexpected,
            .glGetUniformLocation = lib.lookup(PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation") orelse return error.Unexpected,
            .glLinkProgram = lib.lookup(PFNGLLINKPROGRAMPROC, "glLinkProgram") orelse return error.Unexpected,
            .glPixelStorei = lib.lookup(PFNGLPIXELSTOREIPROC, "glPixelStorei") orelse return error.Unexpected,
            .glReadPixels = lib.lookup(PFNGLREADPIXELSPROC, "glReadPixels") orelse return error.Unexpected,
            .glShaderSource = lib.lookup(PFNGLSHADERSOURCEPROC, "glShaderSource") orelse return error.Unexpected,
            .glTexImage2D = lib.lookup(PFNGLTEXIMAGE2DPROC, "glTexImage2D") orelse return error.Unexpected,
            .glTexParameteri = lib.lookup(PFNGLTEXPARAMETERIPROC, "glTexParameteri") orelse return error.Unexpected,
            .glTexSubImage2D = lib.lookup(PFNGLTEXSUBIMAGE2DPROC, "glTexSubImage2D") orelse return error.Unexpected,
            .glUniform1f = lib.lookup(PFNGLUNIFORM1FPROC, "glUniform1f") orelse return error.Unexpected,
            .glUniform1i = lib.lookup(PFNGLUNIFORM1IPROC, "glUniform1i") orelse return error.Unexpected,
            .glUniform2f = lib.lookup(PFNGLUNIFORM2FPROC, "glUniform2f") orelse return error.Unexpected,
            .glUniform4f = lib.lookup(PFNGLUNIFORM4FPROC, "glUniform4f") orelse return error.Unexpected,
            .glUseProgram = lib.lookup(PFNGLUSEPROGRAMPROC, "glUseProgram") orelse return error.Unexpected,
            .glVertexAttribPointer = lib.lookup(PFNGLVERTEXATTRIBPOINTERPROC, "glVertexAttribPointer") orelse return error.Unexpected,
            .glViewport = lib.lookup(PFNGLVIEWPORTPROC, "glViewport") orelse return error.Unexpected,
        };
    }
};
