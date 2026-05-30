const std = @import("std");
const app_input_event = @import("app_input_event.zig");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);

pub const output_name = "index.html";
pub const wasm_path = "../bin/edgerun-app-runtime.wasm";
pub const immutable_marker = "GENERATED FILE. IMMUTABLE.";
pub const viewport_css = "html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}";
pub const max_total_js_bytes: usize = 8360;

const keyboard_capture_event_js =
    "k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.key_down)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.key_up)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.input)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.change)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.before_input)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.composition_start)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.composition_update)}) ++
    "||k==" ++ std.fmt.comptimePrint("{d}", .{@intFromEnum(app_input_event.Kind.composition_end)});

pub const loader_js =
    \\let W,M,I,F,N=0,R=requestAnimationFrame,C=c,G=C.getContext`webgl`,T=new TextEncoder,D=new TextDecoder;if(!G)throw`webgl`;
    \\let U=(p,l)=>new Uint8Array(M,p,l).slice(),B=(p,l)=>D.decode(new Uint8Array(M,p,l)),Q=(p,l,t,z)=>{let a=document.createElement`a`,u=URL.createObjectURL(new Blob([U(p,l)]));a.href=u;a.download=B(t,z)||`edgerun-app.wasm`;a.click();URL.revokeObjectURL(u)},P=()=>{for(let i=0,n=W.er_ui_outbox_count();i<n;i++){let k=W.er_ui_outbox_kind(i),p=W.er_ui_outbox_payload_ptr(i),l=W.er_ui_outbox_payload_len(i),t=W.er_ui_outbox_target_ptr(i),z=W.er_ui_outbox_target_len(i);if(k==1)open(B(p,l),`_blank`,`noopener`);else if(k==2)location.hash=B(p,l);else if(k==3)document.title=B(p,l);else if(k==4){let e=document.getElementById(B(t,z));if(e)e.innerHTML=B(p,l)}else if(k==5&&l)Q(p,l,t,z);else if(k==6&&l)I=[I,WebAssembly.instantiate(U(p,l),{})]}W.er_ui_outbox_clear()},A=(e,k)=>{let p=W.er_ui_input_ptr(),m=new Uint8Array(M,p,W.er_ui_input_capacity()),v=new DataView(M,p),o=36,a=[e.key||``,e.code||``,e.inputType||``,e.data||location.hash||``],l=[];for(let i=0;i<4;i++){l[i]=T.encodeInto(a[i],m.subarray(o)).written;o+=l[i]}v.setUint32(0,k,1);v.setFloat32(4,e.clientX||0,1);v.setFloat32(8,e.clientY||0,1);v.setFloat32(12,e.deltaY||0,1);v.setUint32(16,(e.ctrlKey|0)+2*(e.metaKey|0)+4*(e.altKey|0)+8*(e.shiftKey|0)+16*(e.repeat|0),1);for(let i=0;i<4;i++)v.setUint32(20+i*4,l[i],1);let r=W.er_ui_event_bytes(o,innerWidth,innerHeight,performance.now());if((r&1)||
++ keyboard_capture_event_js ++
    \\)e.preventDefault();if(r&8)P();if(r&2)N||(N=R(F))};` resize wheel pointermove pointerleave pointerdown pointerup popstate hashchange keydown contextmenu keyup input change click dblclick visibilitychange focus blur beforeinput compositionstart compositionupdate compositionend touchstart touchmove touchend touchcancel dragstart dragend drop`.split` `.map((n,k)=>n&&addEventListener(n,e=>A(e,k),{passive:0,capture:1}));addEventListener(`scroll`,e=>A(e,2));addEventListener(`pointercancel`,e=>A(e,4));
    \\let R_=(x,l)=>D.decode(new Uint8Array(W.memory.buffer,x,l));
    \\let L={glActiveTexture:t=>G.activeTexture(t),glAttachShader:(p,s)=>G.attachShader(p,s),glBindAttribLocation:(p,i,x,l)=>G.bindAttribLocation(p,i,R_(x,l)),glBindBuffer:(t,b)=>G.bindBuffer(t,b),glBindTexture:(t,x)=>G.bindTexture(t,x),glBlendFuncSeparate:(a,b,c,d)=>G.blendFuncSeparate(a,b,c,d),glBufferData:(t,s,p,u)=>G.bufferData(t,new Float32Array(W.memory.buffer,p,s/4),u),glClear:m=>G.clear(m),glClearColor:(r,g,b,a)=>G.clearColor(r,g,b,a),glCompileShader:s=>G.compileShader(s),glCreateProgram:()=>G.createProgram(),glCreateShader:t=>G.createShader(t),glDeleteBuffers:(n,b)=>G.deleteBuffers([b]),glDeleteProgram:p=>G.deleteProgram(p),glDeleteShader:s=>G.deleteShader(s),glDeleteTextures:(n,t)=>G.deleteTextures([t]),glDisable:c=>G.disable(c),glDrawArrays:(m,f,c)=>G.drawArrays(m,f,c),glEnable:c=>G.enable(c),glEnableVertexAttribArray:i=>G.enableVertexAttribArray(i),glGenBuffers:n=>G.createBuffer(),glGenTextures:n=>G.createTexture(),glGetProgramiv:(p,n)=>G.getProgramParameter(p,n)?1:0,glGetShaderiv:(s,n)=>G.getShaderParameter(s,n)?1:0,glGetUniformLocation:(p,x,l)=>G.getUniformLocation(p,R_(x,l)),glLinkProgram:p=>G.linkProgram(p),glPixelStorei:(p,v)=>G.pixelStorei(p,v),glShaderSource:(s,c,x,l)=>G.shaderSource(s,R_(x,l)),glTexImage2D:(t,l,i,w,h,b,f,tp,p)=>G.texImage2D(t,l,i,w,h,b,f,tp,p?new Uint8Array(W.memory.buffer,p):null),glTexParameteri:(t,p,v)=>G.texParameteri(t,p,v),glTexSubImage2D:(t,l,x,y,w,h,f,tp,p)=>G.texSubImage2D(t,l,x,y,w,h,f,tp,new Uint8Array(W.memory.buffer,p)),glUniform1f:(l,v)=>G.uniform1f(l,v),glUniform1i:(l,v)=>G.uniform1i(l,v),glUniform2f:(l,a,b)=>G.uniform2f(l,a,b),glUniform4f:(l,a,b,c,d)=>G.uniform4f(l,a,b,c,d),glUseProgram:p=>G.useProgram(p),glVertexAttribPointer:(i,s,t,n,st,ptr)=>G.vertexAttribPointer(i,s,t,n,st,ptr),glViewport:(x,y,w,h)=>G.viewport(x,y,w,h)};
    \\W=(await WebAssembly.instantiate(await(await fetch`../bin/edgerun-app-runtime.wasm`).arrayBuffer(),{env:L})).instance.exports;M=W.memory.buffer;W.er_ui_wasm_gl_init();W.er_ui_boot();P();A({type:`hashchange`},8);
    \\F=t=>{N=0;let w=innerWidth|0,h=innerHeight|0,d=Math.min(devicePixelRatio||1,4,W.er_ui_max_width()/w,W.er_ui_max_height()/h);C.style.width=w+`px`;C.style.height=h+`px`;C.width=w*d;C.height=h*d;W.er_ui_render_frame_wasm(w,h,d,t);P()};A({type:`hashchange`},8);N||(N=R(F))
;
pub const total_js_bytes: usize = loader_js.len;

pub const html =
    \\<!doctype html>
    \\<!-- GENERATED FILE. IMMUTABLE. Browser/WASM bootstrap only. -->
    \\<html lang="en">
    \\<head>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <title>EdgeRun</title>
    \\  <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}</style>
    \\</head>
    \\<body>
    \\  <canvas id="c"></canvas>
    \\  <script type="module">
    \\
++ loader_js ++
    \\
    \\  </script>
    \\</body>
    \\</html>
    \\
;

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();

    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    if (args.next() != null) return error.TooManyArguments;

    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(init.io, output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    const file = try cwd.createFile(init.io, output_path, .{ .truncate = true });
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, html);
    try file.setPermissions(init.io, output_file_permissions);
}

fn contains(needle: []const u8) bool {
    return std.mem.indexOf(u8, html, needle) != null;
}

test "generated entry declares itself immutable bootstrap only" {
    try std.testing.expect(contains(immutable_marker));
    try std.testing.expect(contains("Browser/WASM bootstrap only"));
    try std.testing.expect(contains(viewport_css));
    try std.testing.expect(total_js_bytes <= max_total_js_bytes);
    try std.testing.expect(contains("<canvas id=\"c\"></canvas>"));
    try std.testing.expect(!contains("<main"));
}

test "generated entry has the only javascript byte bridge" {
    try std.testing.expect(std.mem.eql(u8, output_name, "index.html"));
    try std.testing.expect(contains(wasm_path));
    try std.testing.expect(contains("WebAssembly.instantiate"));
    try std.testing.expect(contains("arrayBuffer"));
    try std.testing.expect(!contains("instantiateStreaming"));
    try std.testing.expect(contains("fetch`../bin/edgerun-app-runtime.wasm`"));
    try std.testing.expect(contains("er_ui_event_bytes"));
    try std.testing.expect(contains("getContext`webgl`"));
    try std.testing.expect(contains("er_ui_wasm_gl_init"));
    try std.testing.expect(contains("er_ui_render_frame_wasm"));
    try std.testing.expect(!contains("er_ui_build_frame"));
    try std.testing.expect(!contains("er_ui_set_device_scale"));
    try std.testing.expect(contains("er_ui_outbox_count"));
    try std.testing.expect(contains("new DataView"));
    try std.testing.expect(contains("setUint32(0,k,1)"));
    try std.testing.expect(contains("setFloat32(4"));
    try std.testing.expect(contains("setUint32(20+i*4"));
    try std.testing.expect(contains("glCreateShader"));
    try std.testing.expect(contains("glShaderSource"));
    try std.testing.expect(contains("glBindAttribLocation"));
    try std.testing.expect(contains("TextDecoder"));
    try std.testing.expect(contains("TextEncoder"));
    try std.testing.expect(contains("glUniform4f"));
    try std.testing.expect(contains("glDrawArrays"));
    try std.testing.expect(contains("glClearColor"));
    try std.testing.expect(contains("glViewport"));
    try std.testing.expect(contains("download=B(t,z)"));
    try std.testing.expect(contains("location.hash=B(p,l)"));
    try std.testing.expect(contains("I=[I,WebAssembly.instantiate"));
    try std.testing.expect(contains("beforeinput"));
    try std.testing.expect(contains("dblclick"));
    try std.testing.expect(contains("if((r&1)||" ++ keyboard_capture_event_js ++ ")e.preventDefault()"));
    try std.testing.expect(contains("{passive:0,capture:1}"));
    try std.testing.expect(contains("if(r&2)N||(N=R(F))"));
    try std.testing.expect(contains("F=t=>{N=0;"));
    try std.testing.expect(contains("A({type:`hashchange`},8);N||(N=R(F))"));
    try std.testing.expect(!contains("R(F)};W="));
    try std.testing.expect(!contains("er_ui_bootstrap_js_ptr"));
    try std.testing.expect(!contains("er_ui_bootstrap_js_len"));
    try std.testing.expect(!contains("eval"));
    try std.testing.expect(!contains("globalThis"));
    try std.testing.expect(!contains("e.type+`\\n`"));
    try std.testing.expect(!contains("replaceAll"));
    try std.testing.expect(!contains("ui.css"));
    try std.testing.expect(!contains("ui.js"));
    try std.testing.expect(!contains("<link rel=\"stylesheet\""));
    try std.testing.expect(!contains("<script type=\"module\" src="));
    try std.testing.expect(!contains("putImageData"));
    try std.testing.expect(!contains("er_ui_render_frame_hd"));
    try std.testing.expect(!contains("vertexSource"));
    try std.testing.expect(!contains("hostCommandHandlers"));
    try std.testing.expect(!contains("addEventListener(\"keydown\""));
    try std.testing.expect(!contains("er_ui_packed_rect_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_packed_image_vertex_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_packed_icon_line_vertex_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_packed_overlay_rect_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_packed_overlay_icon_line_vertex_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_font_atlas_ptr"));
    try std.testing.expect(!contains("er_ui_post_image_rgba_ptr"));
    try std.testing.expect(contains("G.vertexAttribPointer"));
    try std.testing.expect(contains("G.bindAttribLocation"));
    try std.testing.expect(contains("blendFuncSeparate"));
    try std.testing.expect(!contains("rect_vertex_shader"));
    try std.testing.expect(!contains("rect_fragment_shader"));
    try std.testing.expect(!contains("textured_vertex_shader"));
    try std.testing.expect(!contains("text_fragment_shader"));
    try std.testing.expect(!contains("image_fragment_shader"));
    try std.testing.expect(!contains("line_vertex_shader"));
    try std.testing.expect(!contains("line_fragment_shader"));
    try std.testing.expect(!contains("er_ui_font_atlas_generation"));
    try std.testing.expect(!contains("er_ui_packed_rect_float_stride"));
    try std.testing.expect(!contains("i+="));
    try std.testing.expect(!contains("m=a[i+"));
    try std.testing.expect(!contains("sh=a[i+"));
    try std.testing.expect(!contains("G.getUniformLocation(pt,`"));
    try std.testing.expect(!contains("er_ui_post_image_width"));
    try std.testing.expect(!contains("er_ui_font_atlas_width"));
}
