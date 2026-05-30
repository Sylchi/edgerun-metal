pub const attr_pos_location: u32 = 0;
pub const attr_uv_location: u32 = 1;
pub const attr_color_location: u32 = 2;

pub const attr_pos: [:0]const u8 = "a";
pub const attr_uv: [:0]const u8 = "b";
pub const attr_color: [:0]const u8 = "c";

pub const uniform_screen: [:0]const u8 = "z";
pub const uniform_rect: [:0]const u8 = "r";
pub const uniform_source_rect: [:0]const u8 = "s";
pub const uniform_color: [:0]const u8 = "c";
pub const uniform_color2: [:0]const u8 = "d";
pub const uniform_radius: [:0]const u8 = "q";
pub const uniform_shadow: [:0]const u8 = "m";
pub const uniform_pixel_scale: [:0]const u8 = "u";
pub const uniform_mode: [:0]const u8 = "o";
pub const uniform_texture: [:0]const u8 = "t";
pub const uniform_texture_kind: [:0]const u8 = "i";
pub const texture_kind_red: i32 = 0;
pub const texture_kind_alpha: i32 = 1;
pub const clear_color_r_u8: u8 = 10;
pub const clear_color_g_u8: u8 = 14;
pub const clear_color_b_u8: u8 = 20;
pub const clear_color_a_u8: u8 = 255;
pub const clear_color_denominator: f32 = 255.0;
pub const clear_color_r: f32 = @as(f32, @floatFromInt(clear_color_r_u8)) / clear_color_denominator;
pub const clear_color_g: f32 = @as(f32, @floatFromInt(clear_color_g_u8)) / clear_color_denominator;
pub const clear_color_b: f32 = @as(f32, @floatFromInt(clear_color_b_u8)) / clear_color_denominator;
pub const clear_color_a: f32 = @as(f32, @floatFromInt(clear_color_a_u8)) / clear_color_denominator;

pub const rect_vertex_shader: [:0]const u8 = "attribute vec2 a;uniform vec2 z;uniform vec4 r;void main(){vec2 p=r.xy+a*r.zw;gl_Position=vec4(p.x/z.x*2.-1.,1.-p.y/z.y*2.,0,1);}";
pub const rect_fragment_shader: [:0]const u8 = "precision highp float;uniform vec2 z;uniform vec4 r,s,c,d;uniform float q,m,u;uniform int o;float b(vec2 p,vec2 z,float r){vec2 q=abs(p)-z+vec2(r);return length(max(q,0.))+min(max(q.x,q.y),0.)-r;}vec4 p(vec4 c,float a){float x=c.a*a;return vec4(c.rgb*x,x);}void main(){float a=1./max(u,1.);vec2 x=vec2(gl_FragCoord.x/max(u,1.),z.y-gl_FragCoord.y/max(u,1.)),y=x-r.xy-r.zw*.5;float e=b(y,r.zw*.5,q),n=clamp(-e/a,0.,1.);if(q<=0.)n=1.;n=floor(n*255.+.5)/255.;if(o==1){vec2 v=x-s.xy-s.zw*.5;float i=b(v,s.zw*.5,q);if(i<=0.||i>=m)discard;float t=1.-i/max(m,.001);gl_FragColor=p(c,t*t*.34);}else if(o==2){float i=b(y,r.zw*.5-vec2(1),max(q-1.,0.));gl_FragColor=p(c,clamp(-e/a,0.,1.)*clamp(i/a,0.,1.));}else if(o==3){float t=clamp((x.y-r.y)/max(r.w,1.),0.,1.);gl_FragColor=p(mix(c,d,t),n);}else if(o==4){float f=min(r.z,r.w)*.5;float l=length(y);if(l>f)discard;float v=atan(y.y,y.x)/6.2831853+.25;if(v<0.)v+=1.;if(v<d.r||v>d.g)discard;float k=clamp((f+1.-l)/2.,0.,1.);k=floor(k*255.+.5)/255.;gl_FragColor=p(c,k);}else gl_FragColor=p(c,n);}";
pub const textured_vertex_shader: [:0]const u8 = "attribute vec2 a,b;attribute vec4 c;uniform vec2 z;varying vec2 v;varying vec4 k;void main(){gl_Position=vec4(a.x/z.x*2.-1.,1.-a.y/z.y*2.,0,1);v=b;k=c;}";
pub const text_fragment_shader: [:0]const u8 = "precision highp float;varying vec2 v;varying vec4 k;uniform sampler2D t;uniform int i;void main(){vec4 x=texture2D(t,v);float a=(i==1?x.a:x.r)*k.a;gl_FragColor=vec4(k.rgb*a,a);}";
pub const image_fragment_shader: [:0]const u8 = "precision highp float;varying vec2 v;varying vec4 k;uniform sampler2D t;void main(){vec4 x=texture2D(t,v);float a=x.a*k.a;gl_FragColor=vec4(x.rgb*k.rgb*a,a);}";
pub const line_vertex_shader: [:0]const u8 = "attribute vec2 a;attribute vec4 c;uniform vec2 z;varying vec4 k;void main(){gl_Position=vec4(a.x/z.x*2.-1.,1.-a.y/z.y*2.,0,1);k=c;}";
pub const line_fragment_shader: [:0]const u8 = "precision mediump float;varying vec4 k;void main(){gl_FragColor=vec4(k.rgb*k.a,k.a);}";

test "GL contract pins browser and GLES attribute layout" {
    try @import("std").testing.expectEqual(@as(u32, 0), attr_pos_location);
    try @import("std").testing.expectEqual(@as(u32, 1), attr_uv_location);
    try @import("std").testing.expectEqual(@as(u32, 2), attr_color_location);
    try @import("std").testing.expectEqual(@as(i32, 0), texture_kind_red);
    try @import("std").testing.expectEqual(@as(i32, 1), texture_kind_alpha);
    try @import("std").testing.expectEqual(@as(u8, 10), clear_color_r_u8);
    try @import("std").testing.expectEqual(@as(u8, 14), clear_color_g_u8);
    try @import("std").testing.expectEqual(@as(u8, 20), clear_color_b_u8);
    try @import("std").testing.expectEqual(@as(u8, 255), clear_color_a_u8);
}
