const std = @import("std");
const gl_contract = @import("render/gl_contract.zig");
const icon_line_buffer = @import("render/icon_line_buffer.zig");
const renderer_ir = @import("render/ir.zig");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);

pub const output_name = "index.html";
pub const wasm_path = "../bin/edgerun-app-runtime.wasm";
pub const immutable_marker = "GENERATED FILE. IMMUTABLE.";
pub const viewport_css = "html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}";
pub const max_total_js_bytes: usize = 8192;

const attr_pos_location_js = std.fmt.comptimePrint("{d}", .{gl_contract.attr_pos_location});
const attr_uv_location_js = std.fmt.comptimePrint("{d}", .{gl_contract.attr_uv_location});
const attr_color_location_js = std.fmt.comptimePrint("{d}", .{gl_contract.attr_color_location});
const rect_float_stride_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_float_stride});
const rect_x_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_x_index});
const rect_y_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_y_index});
const rect_w_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_w_index});
const rect_h_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_h_index});
const rect_radius_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_radius_index});
const rect_shadow_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_shadow_index});
const rect_color_r_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color_r_index});
const rect_color_g_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color_g_index});
const rect_color_b_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color_b_index});
const rect_color_a_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color_a_index});
const rect_color2_r_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color2_r_index});
const rect_color2_g_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color2_g_index});
const rect_color2_b_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color2_b_index});
const rect_color2_a_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_color2_a_index});
const rect_mode_index_js = std.fmt.comptimePrint("{d}", .{renderer_ir.rect_mode_index});
const text_vertex_float_stride_js = std.fmt.comptimePrint("{d}", .{renderer_ir.text_vertex_float_stride});
const text_vertex_byte_stride_js = std.fmt.comptimePrint("{d}", .{renderer_ir.text_vertex_float_stride * @sizeOf(f32)});
const textured_u_byte_offset_js = std.fmt.comptimePrint("{d}", .{renderer_ir.textured_u_index * @sizeOf(f32)});
const textured_color_byte_offset_js = std.fmt.comptimePrint("{d}", .{renderer_ir.textured_color_r_index * @sizeOf(f32)});
const icon_line_vertex_float_stride_js = std.fmt.comptimePrint("{d}", .{icon_line_buffer.vertex_float_stride});
const icon_line_vertex_byte_stride_js = std.fmt.comptimePrint("{d}", .{icon_line_buffer.vertex_float_stride * @sizeOf(f32)});
const icon_line_color_byte_offset_js = std.fmt.comptimePrint("{d}", .{icon_line_buffer.vertex_color_r_index * @sizeOf(f32)});
const gl_attr_bindings =
    "G.bindAttribLocation(p," ++ attr_pos_location_js ++ ",`" ++ gl_contract.attr_pos ++ "`);" ++
    "G.bindAttribLocation(p," ++ attr_uv_location_js ++ ",`" ++ gl_contract.attr_uv ++ "`);" ++
    "G.bindAttribLocation(p," ++ attr_color_location_js ++ ",`" ++ gl_contract.attr_color ++ "`);";
const gl_shader_sources =
    "V=`" ++ gl_contract.rect_vertex_shader ++
    "`,Rr=`" ++ gl_contract.rect_fragment_shader ++
    "`,Tv=`" ++ gl_contract.textured_vertex_shader ++
    "`,Tf=`" ++ gl_contract.text_fragment_shader ++
    "`,If=`" ++ gl_contract.image_fragment_shader ++
    "`,Lv=`" ++ gl_contract.line_vertex_shader ++
    "`,Lf=`" ++ gl_contract.line_fragment_shader ++ "`";

pub const loader_js =
    \\let W,M,I,F,R=requestAnimationFrame,C=c,G=C.getContext`webgl`,T=new TextEncoder,D=new TextDecoder;if(!G)throw`webgl`;let U=(p,l)=>new Uint8Array(M,p,l).slice(),B=(p,l)=>D.decode(new Uint8Array(M,p,l)),Q=(p,l,t,z)=>{let a=document.createElement`a`,u=URL.createObjectURL(new Blob([U(p,l)]));a.href=u;a.download=B(t,z)||`edgerun-app.wasm`;a.click();URL.revokeObjectURL(u)},P=()=>{for(let i=0,n=W.er_ui_outbox_count();i<n;i++){let k=W.er_ui_outbox_kind(i),p=W.er_ui_outbox_payload_ptr(i),l=W.er_ui_outbox_payload_len(i),t=W.er_ui_outbox_target_ptr(i),z=W.er_ui_outbox_target_len(i);if(k==1)open(B(p,l),`_blank`,`noopener`);else if(k==2)location.hash=B(p,l);else if(k==3)document.title=B(p,l);else if(k==4){let e=document.getElementById(B(t,z));if(e)e.innerHTML=B(p,l)}else if(k==5&&l)Q(p,l,t,z);else if(k==6&&l)I=[I,WebAssembly.instantiate(U(p,l),{})]}W.er_ui_outbox_clear()},A=(e,k)=>{let p=W.er_ui_input_ptr(),m=new Uint8Array(M,p,W.er_ui_input_capacity()),v=new DataView(M,p),o=36,a=[e.key||``,e.code||``,e.inputType||``,e.data||location.hash||``],l=[];for(let i=0;i<4;i++){l[i]=T.encodeInto(a[i],m.subarray(o)).written;o+=l[i]}v.setUint32(0,k,1);v.setFloat32(4,e.clientX||0,1);v.setFloat32(8,e.clientY||0,1);v.setFloat32(12,e.deltaY||0,1);v.setUint32(16,(e.ctrlKey|0)+2*(e.metaKey|0)+4*(e.altKey|0)+8*(e.shiftKey|0)+16*(e.repeat|0),1);for(let i=0;i<4;i++)v.setUint32(20+i*4,l[i],1);let r=W.er_ui_event_bytes(o,innerWidth,innerHeight,performance.now());if(r&1)e.preventDefault();if(r&8)P()};` resize wheel pointermove pointerleave pointerdown pointerup popstate hashchange keydown contextmenu keyup input change click dblclick visibilitychange focus blur beforeinput compositionstart compositionupdate compositionend touchstart touchmove touchend touchcancel dragstart dragend drop`.split` `.map((n,k)=>n&&addEventListener(n,e=>A(e,k),{passive:0}));addEventListener(`scroll`,e=>A(e,2));addEventListener(`pointercancel`,e=>A(e,4));
    \\let S=(t,s)=>{let h=G.createShader(t);G.shaderSource(h,s);G.compileShader(h);if(!G.getShaderParameter(h,G.COMPILE_STATUS))throw G.getShaderInfoLog(h);return h},O=(v,f)=>{let p=G.createProgram();G.attachShader(p,S(G.VERTEX_SHADER,v));G.attachShader(p,S(G.FRAGMENT_SHADER,f));
++ gl_attr_bindings ++
    \\G.linkProgram(p);if(!G.getProgramParameter(p,G.LINK_STATUS))throw G.getProgramInfoLog(p);return p},
++ gl_shader_sources ++
    \\;
    \\let pr=O(V,Rr),pt=O(Tv,Tf),pi=O(Tv,If),pl=O(Lv,Lf),rb=G.createBuffer(),tb=G.createBuffer(),lb=G.createBuffer(),ft=G.createTexture(),it=G.createTexture(),fg=0,up=(x,w,h,fmt)=>{G.bindTexture(G.TEXTURE_2D,x);G.texParameteri(G.TEXTURE_2D,G.TEXTURE_MIN_FILTER,G.LINEAR);G.texParameteri(G.TEXTURE_2D,G.TEXTURE_MAG_FILTER,G.LINEAR);G.texParameteri(G.TEXTURE_2D,G.TEXTURE_WRAP_S,G.CLAMP_TO_EDGE);G.texParameteri(G.TEXTURE_2D,G.TEXTURE_WRAP_T,G.CLAMP_TO_EDGE);G.texImage2D(G.TEXTURE_2D,0,fmt,w,h,0,fmt,G.UNSIGNED_BYTE,new Uint8Array(M,fmt==G.RGBA?W.er_ui_post_image_rgba_ptr():W.er_ui_font_atlas_ptr(),fmt==G.RGBA?W.er_ui_post_image_rgba_len():w*h))},dr=(p,l)=>{let a=new Float32Array(M,p,l);G.bindBuffer(G.ARRAY_BUFFER,rb);G.bufferData(G.ARRAY_BUFFER,new Float32Array([0,0,1,0,0,1,1,1]),G.STATIC_DRAW);G.vertexAttribPointer(0,2,G.FLOAT,0,0,0);G.enableVertexAttribArray(0);G.useProgram(pr);G.uniform2f(G.getUniformLocation(pr,`z`),W.er_ui_width(),W.er_ui_height());G.uniform1f(G.getUniformLocation(pr,`u`),C.width/W.er_ui_width());for(let i=0;i<l;i+=
++ rect_float_stride_js ++
    \\){let x=a[i+
++ rect_x_index_js ++
    \\],y=a[i+
++ rect_y_index_js ++
    \\],w=a[i+
++ rect_w_index_js ++
    \\],h=a[i+
++ rect_h_index_js ++
    \\],m=a[i+
++ rect_mode_index_js ++
    \\],sh=a[i+
++ rect_shadow_index_js ++
    \\];G.uniform4f(G.getUniformLocation(pr,`r`),m==1?x-sh:x,m==1?y-sh:y,m==1?w+sh*2:w,m==1?h+sh*2:h);G.uniform4f(G.getUniformLocation(pr,`s`),x,y,w,h);G.uniform1f(G.getUniformLocation(pr,`q`),a[i+
++ rect_radius_index_js ++
    \\]);G.uniform1f(G.getUniformLocation(pr,`m`),sh);G.uniform1i(G.getUniformLocation(pr,`o`),m);G.uniform4f(G.getUniformLocation(pr,`c`),a[i+
++ rect_color_r_index_js ++
    \\],a[i+
++ rect_color_g_index_js ++
    \\],a[i+
++ rect_color_b_index_js ++
    \\],a[i+
++ rect_color_a_index_js ++
    \\]);G.uniform4f(G.getUniformLocation(pr,`d`),a[i+
++ rect_color2_r_index_js ++
    \\],a[i+
++ rect_color2_g_index_js ++
    \\],a[i+
++ rect_color2_b_index_js ++
    \\],a[i+
++ rect_color2_a_index_js ++
    \\]);G.drawArrays(G.TRIANGLE_STRIP,0,4)}};let dt=(p,l,t,g)=>{if(!l)return;G.useProgram(g?pi:pt);G.uniform2f(G.getUniformLocation(g?pi:pt,`z`),W.er_ui_width(),W.er_ui_height());if(!g)G.uniform1i(G.getUniformLocation(pt,`i`),0);G.bindTexture(G.TEXTURE_2D,t);G.bindBuffer(G.ARRAY_BUFFER,tb);G.bufferData(G.ARRAY_BUFFER,new Float32Array(M,p,l),G.DYNAMIC_DRAW);G.vertexAttribPointer(0,2,G.FLOAT,0,
++ text_vertex_byte_stride_js ++
    \\,0);G.vertexAttribPointer(1,2,G.FLOAT,0,
++ text_vertex_byte_stride_js ++
    \\,
++ textured_u_byte_offset_js ++
    \\);G.vertexAttribPointer(2,4,G.FLOAT,0,
++ text_vertex_byte_stride_js ++
    \\,
++ textured_color_byte_offset_js ++
    \\);G.enableVertexAttribArray(0);G.enableVertexAttribArray(1);G.enableVertexAttribArray(2);G.drawArrays(G.TRIANGLES,0,l/
++ text_vertex_float_stride_js ++
    \\)},dl=(p,l)=>{if(!l)return;G.useProgram(pl);G.uniform2f(G.getUniformLocation(pl,`z`),W.er_ui_width(),W.er_ui_height());G.bindBuffer(G.ARRAY_BUFFER,lb);G.bufferData(G.ARRAY_BUFFER,new Float32Array(M,p,l),G.DYNAMIC_DRAW);G.vertexAttribPointer(0,2,G.FLOAT,0,
++ icon_line_vertex_byte_stride_js ++
    \\,0);G.vertexAttribPointer(1,4,G.FLOAT,0,
++ icon_line_vertex_byte_stride_js ++
    \\,
++ icon_line_color_byte_offset_js ++
    \\);G.enableVertexAttribArray(0);G.enableVertexAttribArray(1);G.drawArrays(G.TRIANGLES,0,l/
++ icon_line_vertex_float_stride_js ++
    \\)};
    \\F=t=>{let w=innerWidth|0,h=innerHeight|0,d=Math.min(devicePixelRatio||1,4,W.er_ui_max_width()/w,W.er_ui_max_height()/h);C.style.width=w+`px`;C.style.height=h+`px`;C.width=w*d;C.height=h*d;G.viewport(0,0,C.width,C.height);G.clearColor(10/255,14/255,20/255,1);G.clear(G.COLOR_BUFFER_BIT);G.enable(G.BLEND);G.blendFunc(G.ONE,G.ONE_MINUS_SRC_ALPHA);W.er_ui_set_device_scale(d);if(W.er_ui_build_frame(w,h,t))throw W.er_ui_last_error();if(fg!=W.er_ui_font_atlas_generation()){up(ft,W.er_ui_font_atlas_width(),W.er_ui_font_atlas_height(),G.LUMINANCE);fg=W.er_ui_font_atlas_generation()}if(!it.w){up(it,W.er_ui_post_image_width(),W.er_ui_post_image_height(),G.RGBA);it.w=1}dr(W.er_ui_packed_rect_buffer_ptr(),W.er_ui_packed_rect_buffer_len());dt(W.er_ui_packed_image_vertex_buffer_ptr(),W.er_ui_packed_image_vertex_buffer_len(),it,1);dt(W.er_ui_packed_text_vertex_buffer_ptr(),W.er_ui_packed_text_vertex_buffer_len(),ft,0);dl(W.er_ui_packed_icon_line_vertex_buffer_ptr(),W.er_ui_packed_icon_line_vertex_buffer_len());dr(W.er_ui_packed_overlay_rect_buffer_ptr(),W.er_ui_packed_overlay_rect_buffer_len());dt(W.er_ui_packed_overlay_text_vertex_buffer_ptr(),W.er_ui_packed_overlay_text_vertex_buffer_len(),ft,0);dl(W.er_ui_packed_overlay_icon_line_vertex_buffer_ptr(),W.er_ui_packed_overlay_icon_line_vertex_buffer_len());R(F)};W=(await WebAssembly.instantiate(await(await fetch`../bin/edgerun-app-runtime.wasm`).arrayBuffer())).instance.exports;M=W.memory.buffer;W.er_ui_boot();P();A({type:`hashchange`},8);F()
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
    try std.testing.expect(contains("er_ui_build_frame"));
    try std.testing.expect(contains("er_ui_set_device_scale"));
    try std.testing.expect(contains("er_ui_outbox_count"));
    try std.testing.expect(contains("new DataView"));
    try std.testing.expect(contains("setUint32(0,k,1)"));
    try std.testing.expect(contains("setFloat32(4"));
    try std.testing.expect(contains("setUint32(20+i*4"));
    try std.testing.expect(contains("createShader"));
    try std.testing.expect(contains("shaderSource"));
    try std.testing.expect(contains("bindAttribLocation(p,0,`a`)"));
    try std.testing.expect(contains("bindAttribLocation(p,1,`b`)"));
    try std.testing.expect(contains("bindAttribLocation(p,2,`c`)"));
    try std.testing.expect(contains(gl_contract.rect_vertex_shader));
    try std.testing.expect(contains(gl_contract.rect_fragment_shader));
    try std.testing.expect(contains(gl_contract.textured_vertex_shader));
    try std.testing.expect(contains(gl_contract.text_fragment_shader));
    try std.testing.expect(contains(gl_contract.image_fragment_shader));
    try std.testing.expect(contains(gl_contract.line_vertex_shader));
    try std.testing.expect(contains(gl_contract.line_fragment_shader));
    try std.testing.expect(contains("i+=" ++ rect_float_stride_js));
    try std.testing.expect(contains("m=a[i+" ++ rect_mode_index_js ++ "]"));
    try std.testing.expect(contains("sh=a[i+" ++ rect_shadow_index_js ++ "]"));
    try std.testing.expect(contains("G.vertexAttribPointer(0,2,G.FLOAT,0," ++ text_vertex_byte_stride_js ++ ",0)"));
    try std.testing.expect(contains("G.vertexAttribPointer(1,2,G.FLOAT,0," ++ text_vertex_byte_stride_js ++ "," ++ textured_u_byte_offset_js ++ ")"));
    try std.testing.expect(contains("G.vertexAttribPointer(2,4,G.FLOAT,0," ++ text_vertex_byte_stride_js ++ "," ++ textured_color_byte_offset_js ++ ")"));
    try std.testing.expect(contains("G.drawArrays(G.TRIANGLES,0,l/" ++ text_vertex_float_stride_js ++ ")"));
    try std.testing.expect(contains("G.vertexAttribPointer(0,2,G.FLOAT,0," ++ icon_line_vertex_byte_stride_js ++ ",0)"));
    try std.testing.expect(contains("G.vertexAttribPointer(1,4,G.FLOAT,0," ++ icon_line_vertex_byte_stride_js ++ "," ++ icon_line_color_byte_offset_js ++ ")"));
    try std.testing.expect(contains("G.drawArrays(G.TRIANGLES,0,l/" ++ icon_line_vertex_float_stride_js ++ ")"));
    try std.testing.expect(contains("er_ui_packed_rect_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_text_vertex_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_image_vertex_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_icon_line_vertex_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_overlay_rect_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_overlay_text_vertex_buffer_ptr"));
    try std.testing.expect(contains("er_ui_packed_overlay_icon_line_vertex_buffer_ptr"));
    try std.testing.expect(contains("er_ui_font_atlas_ptr"));
    try std.testing.expect(contains("er_ui_post_image_rgba_ptr"));
    try std.testing.expect(contains("TextDecoder"));
    try std.testing.expect(contains("TextEncoder"));
    try std.testing.expect(contains("download=B(t,z)"));
    try std.testing.expect(contains("location.hash=B(p,l)"));
    try std.testing.expect(contains("I=[I,WebAssembly.instantiate"));
    try std.testing.expect(contains("beforeinput"));
    try std.testing.expect(contains("dblclick"));
    try std.testing.expect(contains("R(F)"));
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
}
