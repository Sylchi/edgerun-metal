const std = @import("std");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);

pub const output_name = "index.html";
pub const wasm_path = "a.wasm";
pub const immutable_marker = "GENERATED FILE. IMMUTABLE.";
pub const viewport_css = "html,body{margin:0;width:100%;height:100%;overflow:hidden;cursor:none}canvas{display:block}";
pub const max_total_js_bytes: usize = 2500;
pub const loader_js =
    \\let W,M,R=requestAnimationFrame,C=c,X=C.getContext`2d`,T=new TextEncoder,D=new TextDecoder,U=(p,l)=>new Uint8Array(M,p,l).slice(),B=(p,l)=>D.decode(new Uint8Array(M,p,l)),Q=(p,l,t,z)=>{let a=document.createElement`a`,u=URL.createObjectURL(new Blob([U(p,l)]));a.href=u;a.download=B(t,z)||`edgerun-app.wasm`;a.click();URL.revokeObjectURL(u)},P=()=>{for(let i=0,n=W.er_ui_outbox_count();i<n;i++){let k=W.er_ui_outbox_kind(i),p=W.er_ui_outbox_payload_ptr(i),l=W.er_ui_outbox_payload_len(i),t=W.er_ui_outbox_target_ptr(i),z=W.er_ui_outbox_target_len(i);if(k==1)open(B(p,l),`_blank`,`noopener`);else if(k==2)location.hash=B(p,l);else if(k==3)document.title=B(p,l);else if(k==4){let e=document.getElementById(B(t,z));if(e)e.innerHTML=B(p,l)}else if(k==5&&l)Q(p,l,t,z);else if(k==6&&l)WebAssembly.instantiate(U(p,l),{})}W.er_ui_outbox_clear()},A=(e,k)=>{let p=W.er_ui_input_ptr(),m=new Uint8Array(M,p,W.er_ui_input_capacity()),v=new DataView(M,p),o=36,a=[e.key||``,e.code||``,e.inputType||``,e.data||location.hash||``],l=[];for(let i=0;i<4;i++){l[i]=T.encodeInto(a[i],m.subarray(o)).written;o+=l[i]}v.setUint32(0,k,1);v.setFloat32(4,e.clientX||0,1);v.setFloat32(8,e.clientY||0,1);v.setFloat32(12,e.deltaY||0,1);v.setUint32(16,(e.ctrlKey|0)+2*(e.metaKey|0)+4*(e.altKey|0)+8*(e.shiftKey|0)+16*(e.repeat|0),1);for(let i=0;i<4;i++)v.setUint32(20+i*4,l[i],1);let r=W.er_ui_event_bytes(o,innerWidth,innerHeight,performance.now());if(r&1)e.preventDefault();if(r&8)P()};` resize wheel pointermove pointerleave pointerdown pointerup popstate hashchange keydown contextmenu keyup input change click dblclick visibilitychange focus blur beforeinput compositionstart compositionupdate compositionend touchstart touchmove touchend touchcancel dragstart dragend drop`.split` `.map((n,k)=>n&&addEventListener(n,e=>A(e,k),{passive:0}));addEventListener(`scroll`,e=>A(e,2));addEventListener(`pointercancel`,e=>A(e,4));F=()=>{let w=innerWidth|0,h=innerHeight|0,d=Math.min(devicePixelRatio||1,4,W.er_ui_max_width()/w,W.er_ui_max_height()/h);C.style.width=w+`px`;C.style.height=h+`px`;if(W.er_ui_render_frame_hd(w,h,d,performance.now()))throw W.er_ui_last_error();let p=W.er_ui_width(),q=W.er_ui_height();if(C.width!=p)C.width=p;if(C.height!=q)C.height=q;X.putImageData(new ImageData(new Uint8ClampedArray(M,W.er_ui_pixels_ptr(),W.er_ui_pixels_len()),p,q),0,0);R(F)};W=(await WebAssembly.instantiateStreaming(fetch`a.wasm`)).instance.exports;M=W.memory.buffer;W.er_ui_boot();P();A({type:`hashchange`},8);F()
;
pub const total_js_bytes: usize = loader_js.len + @import("web_host_js.zig").source.len;

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
    try std.testing.expect(contains("WebAssembly.instantiateStreaming"));
    try std.testing.expect(contains("fetch`a.wasm`"));
    try std.testing.expect(contains("er_ui_event_bytes"));
    try std.testing.expect(contains("er_ui_render_frame_hd"));
    try std.testing.expect(contains("er_ui_outbox_count"));
    try std.testing.expect(contains("putImageData"));
    try std.testing.expect(contains("TextDecoder"));
    try std.testing.expect(contains("TextEncoder"));
    try std.testing.expect(contains("download=B(t,z)"));
    try std.testing.expect(contains("location.hash=B(p,l)"));
    try std.testing.expect(contains("beforeinput"));
    try std.testing.expect(contains("dblclick"));
    try std.testing.expect(contains("requestAnimationFrame(F)"));
    try std.testing.expect(!contains("er_ui_bootstrap_js_ptr"));
    try std.testing.expect(!contains("er_ui_bootstrap_js_len"));
    try std.testing.expect(!contains("eval"));
    try std.testing.expect(!contains("globalThis"));
    try std.testing.expect(!contains("ui.css"));
    try std.testing.expect(!contains("ui.js"));
    try std.testing.expect(!contains("<link rel=\"stylesheet\""));
    try std.testing.expect(!contains("<script type=\"module\" src="));
    try std.testing.expect(!contains("vertexSource"));
    try std.testing.expect(!contains("hostCommandHandlers"));
    try std.testing.expect(!contains("addEventListener(\"keydown\""));
    try std.testing.expect(!contains("shader"));
    try std.testing.expect(!contains("webgl"));
}
