const std = @import("std");

pub const source =
    \\document.body.innerHTML='<canvas id=c></canvas>';document.body.style.margin=0;let W=__edgerunWasm,C=c,X=C.getContext('2d'),T=new TextEncoder,A=e=>{let s=e.type+'\n'+(e.clientX||0)+'\n'+(e.clientY||0)+'\n'+(e.deltaY||0)+'\n'+(e.ctrlKey|0)+'\n'+(e.metaKey|0)+'\n'+(e.altKey|0)+'\n'+(e.key||location.hash||''),m=new Uint8Array(W.memory.buffer,W.er_ui_input_ptr(),W.er_ui_input_capacity()),n=T.encodeInto(s,m).written,r=W.er_ui_browser_event_bytes(n,innerWidth,innerHeight,performance.now());if(r&1)e.preventDefault()};'resize scroll wheel pointermove pointerdown pointerup pointercancel pointerleave keydown keyup input change click dblclick hashchange popstate visibilitychange focus blur contextmenu beforeinput compositionstart compositionupdate compositionend touchstart touchmove touchend touchcancel dragstart drag dragend drop'.split(' ').map(e=>addEventListener(e,A,{passive:0}));F=()=>{let w=innerWidth|0,h=innerHeight|0;C.width=w;C.height=h;if(W.er_ui_render_browser_frame(w,h,performance.now()))throw Error(W.er_ui_last_error());X.putImageData(new ImageData(new Uint8ClampedArray(W.memory.buffer,W.er_ui_pixels_ptr(),w*h*4),w,h),0,0);requestAnimationFrame(F)};W.er_ui_browser_boot();A({type:'hashchange'});F()
;

fn contains(needle: []const u8) bool {
    return std.mem.indexOf(u8, source, needle) != null;
}

test "browser runtime javascript stays below byte bridge budget" {
    try std.testing.expect(source.len < 1400);
    try std.testing.expect(contains("er_ui_browser_event_bytes"));
    try std.testing.expect(contains("TextEncoder"));
    try std.testing.expect(contains("er_ui_render_browser_frame"));
    try std.testing.expect(contains("putImageData"));
    try std.testing.expect(!contains("webgl"));
    try std.testing.expect(!contains("WebGL"));
    try std.testing.expect(!contains("shader"));
    try std.testing.expect(!contains("er_ui_icon_vector"));
}
