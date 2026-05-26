const std = @import("std");

pub const source =
    \\document.body.innerHTML='<canvas id=c></canvas>';document.body.style.margin=0;let W=__edgerunWasm,C=c,X=C.getContext('2d'),T=new TextEncoder,D=new TextDecoder,I=[],U=(p,l)=>new Uint8Array(W.memory.buffer,p,l).slice(),B=(p,l)=>D.decode(new Uint8Array(W.memory.buffer,p,l)),Q=(p,l,t,z)=>{let a=document.createElement('a'),u=URL.createObjectURL(new Blob([U(p,l)],{type:'application/wasm'}));a.href=u;a.download=B(t,z)||'edgerun-app.wasm';a.click();URL.revokeObjectURL(u)},P=()=>{for(let i=0,n=W.er_ui_outbox_count();i<n;i++){let k=W.er_ui_outbox_kind(i),p=W.er_ui_outbox_payload_ptr(i),l=W.er_ui_outbox_payload_len(i),t=W.er_ui_outbox_target_ptr(i),z=W.er_ui_outbox_target_len(i);if(k==1)open(B(p,l),'_blank','noopener');else if(k==2)location.hash=B(p,l);else if(k==3)document.title=B(p,l);else if(k==4){let e=document.getElementById(B(t,z));if(e)e.innerHTML=B(p,l)}else if(k==5&&l)Q(p,l,t,z);else if(k==6&&l)WebAssembly.instantiate(U(p,l),{}).then(m=>I.push(m.instance))}W.er_ui_outbox_clear()},A=e=>{let s=e.type+'\n'+(e.clientX||0)+'\n'+(e.clientY||0)+'\n'+(e.deltaY||0)+'\n'+(e.ctrlKey|0)+'\n'+(e.metaKey|0)+'\n'+(e.altKey|0)+'\n'+(e.key||location.hash||''),m=new Uint8Array(W.memory.buffer,W.er_ui_input_ptr(),W.er_ui_input_capacity()),n=T.encodeInto(s,m).written,r=W.er_ui_event_bytes(n,innerWidth,innerHeight,performance.now());if(r&1)e.preventDefault();if(r&8)P()};'resize scroll wheel pointermove pointerdown pointerup pointercancel pointerleave keydown keyup input change click dblclick hashchange popstate visibilitychange focus blur contextmenu beforeinput compositionstart compositionupdate compositionend touchstart touchmove touchend touchcancel dragstart dragend drop'.split(' ').map(e=>addEventListener(e,A,{passive:0}));F=()=>{let w=innerWidth|0,h=innerHeight|0;C.width=w;C.height=h;if(W.er_ui_render_frame(w,h,performance.now()))throw Error(W.er_ui_last_error());X.putImageData(new ImageData(new Uint8ClampedArray(W.memory.buffer,W.er_ui_pixels_ptr(),w*h*4),w,h),0,0);requestAnimationFrame(F)};W.er_ui_boot();P();A({type:'hashchange'});F()
;

fn contains(needle: []const u8) bool {
    return std.mem.indexOf(u8, source, needle) != null;
}

test "browser runtime javascript stays below byte bridge budget" {
    try std.testing.expect(source.len < 2800);
    try std.testing.expect(contains("er_ui_event_bytes"));
    try std.testing.expect(contains("TextEncoder"));
    try std.testing.expect(contains("TextDecoder"));
    try std.testing.expect(contains("er_ui_render_frame"));
    try std.testing.expect(!contains("er_ui_compiler_wasm_ptr"));
    try std.testing.expect(!contains("er_ui_source_workspace_ptr"));
    try std.testing.expect(!contains("er_ui_release_artifact_commit"));
    try std.testing.expect(!contains("er_wasm_compiler_compile_wasm"));
    try std.testing.expect(!contains("er_wasm_compiler_init"));
    try std.testing.expect(contains("WebAssembly.instantiate"));
    try std.testing.expect(!contains("fetch("));
    try std.testing.expect(contains("putImageData"));
    try std.testing.expect(!contains("webgl"));
    try std.testing.expect(!contains("WebGL"));
    try std.testing.expect(!contains("shader"));
    try std.testing.expect(!contains("er_ui_icon_vector"));
}
