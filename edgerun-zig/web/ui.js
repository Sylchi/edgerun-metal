const vertexSource = `#version 300 es
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec4 a_rect;
layout(location = 2) in vec4 a_color;
layout(location = 3) in vec2 a_shape;
layout(location = 4) in float a_mode;
layout(location = 5) in vec4 a_color2;
uniform vec2 u_screen;
out vec2 v_local;
out vec2 v_size;
out vec4 v_color;
out vec4 v_color2;
out float v_radius;
out float v_shadow;
flat out int v_mode;
void main() {
  vec2 px = a_rect.xy + a_pos * a_rect.zw;
  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
  gl_Position = vec4(ndc, 0.0, 1.0);
  v_local = a_pos * a_rect.zw;
  v_size = a_rect.zw;
  v_color = a_color;
  v_color2 = a_color2;
  v_radius = a_shape.x;
  v_shadow = a_shape.y;
  v_mode = int(a_mode + 0.5);
}`;

const fragmentSource = `#version 300 es
precision highp float;
in vec2 v_local;
in vec2 v_size;
in vec4 v_color;
in vec4 v_color2;
in float v_radius;
in float v_shadow;
flat in int v_mode;
out vec4 out_color;
float rounded_box(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
  vec2 p = v_local - v_size * 0.5;
  float d = rounded_box(p, v_size * 0.5, v_radius);
  float aa = max(fwidth(d), 0.75);
  float alpha = 1.0 - smoothstep(0.0, aa, d);
  if (v_mode == 1) {
    float sd = rounded_box(p - vec2(0.0, -v_shadow * 0.18), v_size * 0.5, v_radius + v_shadow * 0.35);
    float blur = max(v_shadow, 1.0);
    alpha = 1.0 - smoothstep(-blur, blur, sd);
    out_color = vec4(v_color.rgb, v_color.a * alpha * 0.28);
  } else if (v_mode == 2) {
    float inner = rounded_box(p, v_size * 0.5 - vec2(1.25), max(v_radius - 1.25, 0.0));
    float border = (1.0 - smoothstep(0.0, aa, d)) * smoothstep(0.0, aa, inner);
    out_color = vec4(v_color.rgb, v_color.a * border);
  } else {
    vec4 fill_color = v_mode == 3 ? mix(v_color, v_color2, clamp(v_local.y / max(v_size.y, 1.0), 0.0, 1.0)) : v_color;
    out_color = vec4(fill_color.rgb, fill_color.a * alpha);
  }
}`;

const texturedVertexSource = `#version 300 es
layout(location = 0) in vec4 a_data;
layout(location = 1) in vec4 a_color;
uniform vec2 u_screen;
out vec2 v_uv;
out vec4 v_color;
void main() {
  vec2 px = a_data.xy;
  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
  gl_Position = vec4(ndc, 0.0, 1.0);
  v_uv = a_data.zw;
  v_color = a_color;
}`;

const texturedFragmentSource = `#version 300 es
precision highp float;
in vec2 v_uv;
in vec4 v_color;
out vec4 out_color;
uniform sampler2D u_tex;
void main() {
  float a = texture(u_tex, v_uv).r;
  out_color = vec4(v_color.rgb, v_color.a * a);
}`;

const canvas = document.getElementById("edgerun");
const wasmBuildVersion = "webgl-atlas-1";
const hoverHitKindNone = 255;

let wasm;
let gl;
let shapeProgram;
let texturedProgram;
let shapeVao;
let texturedVao;
let rectVbo;
let texturedVbo;
let shapeScreen;
let texturedScreen;
let texturedTex;
let fontTexture;
let iconTexture;
let rectStride = 15;
let textStride = 8;
let iconStride = 8;
let scrollY = 0;
let hoverX = -1;
let hoverY = -1;
let layoutMode = 0;
let gridGap = 40;
let layoutMasonryId = 0;
let layoutGridId = 0;
let gapCompactId = 0;
let gapDefaultId = 0;
let gapWideId = 0;
let hoverHitKind = hoverHitKindNone;
let hoverHitId = 0;
let scheduled = false;
let cssWidth = 1;
let cssHeight = 1;
let deviceScale = 1;

function setStatus(value) {
  console.debug(value);
}

function shader(type, source) {
  const value = gl.createShader(type);
  gl.shaderSource(value, source);
  gl.compileShader(value);
  if (!gl.getShaderParameter(value, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(value) || "shader compile failed");
  }
  return value;
}

function program(vertex, fragment) {
  const value = gl.createProgram();
  gl.attachShader(value, shader(gl.VERTEX_SHADER, vertex));
  gl.attachShader(value, shader(gl.FRAGMENT_SHADER, fragment));
  gl.linkProgram(value);
  if (!gl.getProgramParameter(value, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(value) || "program link failed");
  }
  return value;
}

function initGpu() {
  gl = canvas.getContext("webgl2", { antialias: true, alpha: false });
  if (!gl) throw new Error("WebGL2 is required");

  shapeProgram = program(vertexSource, fragmentSource);
  shapeVao = gl.createVertexArray();
  gl.bindVertexArray(shapeVao);

  const quadVbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quadVbo);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
    0, 0, 1, 0, 1, 1,
    0, 0, 1, 1, 0, 1,
  ]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0);

  rectVbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, rectVbo);
  const rectBytes = rectStride * 4;
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, rectBytes, 0);
  gl.vertexAttribDivisor(1, 1);
  gl.enableVertexAttribArray(2);
  gl.vertexAttribPointer(2, 4, gl.FLOAT, false, rectBytes, 24);
  gl.vertexAttribDivisor(2, 1);
  gl.enableVertexAttribArray(3);
  gl.vertexAttribPointer(3, 2, gl.FLOAT, false, rectBytes, 16);
  gl.vertexAttribDivisor(3, 1);
  gl.enableVertexAttribArray(4);
  gl.vertexAttribPointer(4, 1, gl.FLOAT, false, rectBytes, (rectStride - 1) * 4);
  gl.vertexAttribDivisor(4, 1);
  gl.enableVertexAttribArray(5);
  gl.vertexAttribPointer(5, 4, gl.FLOAT, false, rectBytes, 40);
  gl.vertexAttribDivisor(5, 1);
  shapeScreen = gl.getUniformLocation(shapeProgram, "u_screen");

  texturedProgram = program(texturedVertexSource, texturedFragmentSource);
  texturedVao = gl.createVertexArray();
  gl.bindVertexArray(texturedVao);
  texturedVbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, texturedVbo);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 32, 0);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 32, 16);
  texturedScreen = gl.getUniformLocation(texturedProgram, "u_screen");
  texturedTex = gl.getUniformLocation(texturedProgram, "u_tex");
}

function alphaTexture(width, height, ptr) {
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  const bytes = new Uint8Array(wasm.memory.buffer, ptr, width * height);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bytes);
  return texture;
}

function initAtlases() {
  if (fontTexture) gl.deleteTexture(fontTexture);
  fontTexture = alphaTexture(
    wasm.er_ui_font_atlas_width(),
    wasm.er_ui_font_atlas_height(),
    wasm.er_ui_font_atlas_ptr(),
  );
  if (!iconTexture) {
    iconTexture = alphaTexture(
      wasm.er_ui_icon_atlas_width(),
      wasm.er_ui_icon_atlas_height(),
      wasm.er_ui_icon_atlas_ptr(),
    );
  }
}

function fitCanvas() {
  const rect = canvas.getBoundingClientRect();
  const dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));
  const maxWidth = wasm?.er_ui_max_width?.() ?? 1440;
  const maxHeight = wasm?.er_ui_max_height?.() ?? 900;
  cssWidth = Math.max(1, Math.min(maxWidth, Math.floor(rect.width)));
  cssHeight = Math.max(1, Math.min(maxHeight, Math.floor(rect.height)));
  const nextDeviceScale = dpr;
  const nextWidth = Math.max(1, Math.min(maxWidth, Math.floor(cssWidth * nextDeviceScale)));
  const nextHeight = Math.max(1, Math.min(maxHeight, Math.floor(cssHeight * nextDeviceScale)));
  canvas.width = nextWidth;
  canvas.height = nextHeight;
  if (wasm && Math.abs(nextDeviceScale - deviceScale) > 0.001) {
    deviceScale = nextDeviceScale;
    wasm.er_ui_set_device_scale(deviceScale);
    initAtlases();
  }
}

function schedule() {
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    paint();
  });
}

function paint() {
  if (!wasm || !gl) return;
  fitCanvas();
  const code = wasm.er_ui_build_component_gallery_gpu_frame_layout_gap_hover(
    cssWidth,
    cssHeight,
    scrollY,
    layoutMode,
    gridGap,
    hoverX,
    hoverY,
  );
  if (code !== 0) {
    setStatus(`error ${wasm.er_ui_last_error()}`);
    return;
  }

  hoverHitKind = wasm.er_ui_hover_hit_kind();
  hoverHitId = wasm.er_ui_hover_hit_id();
  updateCursor();

  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clearColor(0.035, 0.035, 0.043, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  const rectLen = wasm.er_ui_gpu_rect_buffer_len();
  if (rectLen > 0) {
    const rects = new Float32Array(wasm.memory.buffer, wasm.er_ui_gpu_rect_buffer_ptr(), rectLen);
    gl.useProgram(shapeProgram);
    gl.bindVertexArray(shapeVao);
    gl.uniform2f(shapeScreen, cssWidth, cssHeight);
    gl.bindBuffer(gl.ARRAY_BUFFER, rectVbo);
    gl.bufferData(gl.ARRAY_BUFFER, rects, gl.DYNAMIC_DRAW);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, rectLen / rectStride);
  }

  drawTextured(iconTexture, wasm.er_ui_gpu_icon_vertex_buffer_ptr, wasm.er_ui_gpu_icon_vertex_buffer_len, iconStride);
  drawTextured(fontTexture, wasm.er_ui_gpu_text_vertex_buffer_ptr, wasm.er_ui_gpu_text_vertex_buffer_len, textStride);
  setStatus(`${cssWidth}x${cssHeight}@${deviceScale} webgl atlas · ${rectLen / rectStride} rects`);
}

function drawTextured(texture, ptrFn, lenFn, stride) {
  const len = lenFn();
  if (len === 0) return;
  const values = new Float32Array(wasm.memory.buffer, ptrFn(), len);
  gl.useProgram(texturedProgram);
  gl.bindVertexArray(texturedVao);
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.uniform1i(texturedTex, 0);
  gl.uniform2f(texturedScreen, cssWidth, cssHeight);
  gl.bindBuffer(gl.ARRAY_BUFFER, texturedVbo);
  gl.bufferData(gl.ARRAY_BUFFER, values, gl.DYNAMIC_DRAW);
  gl.drawArrays(gl.TRIANGLES, 0, len / stride);
}

async function main() {
  initGpu();
  const response = await fetch(`../zig-out/bin/edgerun-ui-browser.wasm?v=${wasmBuildVersion}`, { cache: "no-store" });
  const module = await WebAssembly.instantiateStreaming(response, {});
  wasm = module.instance.exports;
  fitCanvas();
  wasm.er_ui_set_device_scale(deviceScale);
  rectStride = wasm.er_ui_gpu_rect_float_stride();
  textStride = wasm.er_ui_gpu_text_vertex_float_stride();
  iconStride = wasm.er_ui_gpu_icon_vertex_float_stride();
  layoutMasonryId = wasm.er_ui_component_gallery_layout_masonry_id();
  layoutGridId = wasm.er_ui_component_gallery_layout_grid_id();
  gapCompactId = wasm.er_ui_component_gallery_gap_compact_id();
  gapDefaultId = wasm.er_ui_component_gallery_gap_default_id();
  gapWideId = wasm.er_ui_component_gallery_gap_wide_id();
  initAtlases();
  paint();
}

function updateCursor() {
  switch (hoverHitKind) {
    case 0:
    case 2:
      canvas.style.cursor = "pointer";
      return;
    case 1:
      canvas.style.cursor = "text";
      return;
    default:
      canvas.style.cursor = "default";
  }
}

window.addEventListener("resize", schedule);

canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  scrollY = Math.max(0, Math.min(2600, scrollY + event.deltaY));
  schedule();
}, { passive: false });

canvas.addEventListener("pointermove", (event) => {
  updateHoverFromEvent(event);
  schedule();
});

canvas.addEventListener("pointerleave", () => {
  hoverX = -1;
  hoverY = -1;
  schedule();
});

canvas.addEventListener("pointerup", (event) => {
  updateHoverFromEvent(event);
  paint();
  switch (hoverHitId) {
    case layoutMasonryId:
      layoutMode = 0;
      scrollY = 0;
      schedule();
      return;
    case layoutGridId:
      layoutMode = 1;
      scrollY = 0;
      schedule();
      return;
    case gapCompactId:
      gridGap = 28;
      scrollY = 0;
      schedule();
      return;
    case gapDefaultId:
      gridGap = 40;
      scrollY = 0;
      schedule();
      return;
    case gapWideId:
      gridGap = 56;
      scrollY = 0;
      schedule();
      return;
    default:
      return;
  }
});

function updateHoverFromEvent(event) {
  const rect = canvas.getBoundingClientRect();
  hoverX = event.clientX - rect.left;
  hoverY = event.clientY - rect.top;
}

main().catch((err) => {
  setStatus(err instanceof Error ? err.message : String(err));
});
