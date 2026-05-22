const vertexSource = `#version 300 es
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec4 a_rect;
layout(location = 2) in vec4 a_color;
layout(location = 3) in vec2 a_shape;
layout(location = 4) in float a_mode;
uniform vec2 u_screen;
out vec2 v_local;
out vec2 v_size;
out vec4 v_color;
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
  v_radius = a_shape.x;
  v_shadow = a_shape.y;
  v_mode = int(a_mode + 0.5);
}`;

const fragmentSource = `#version 300 es
precision highp float;
in vec2 v_local;
in vec2 v_size;
in vec4 v_color;
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
    out_color = vec4(v_color.rgb * v_color.a, v_color.a * alpha * 0.28);
  } else if (v_mode == 2) {
    float inner = rounded_box(p, v_size * 0.5 - vec2(1.25), max(v_radius - 1.25, 0.0));
    float border = (1.0 - smoothstep(0.0, aa, d)) * smoothstep(0.0, aa, inner);
    out_color = vec4(v_color.rgb, v_color.a * border);
  } else {
    out_color = vec4(v_color.rgb, v_color.a * alpha);
  }
}`;

const textVertexSource = `#version 300 es
layout(location = 0) in vec4 a_data;
uniform vec2 u_screen;
out vec2 v_uv;
void main() {
  vec2 px = a_data.xy;
  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
  gl_Position = vec4(ndc, 0.0, 1.0);
  v_uv = a_data.zw;
}`;

const textFragmentSource = `#version 300 es
precision highp float;
in vec2 v_uv;
out vec4 out_color;
uniform sampler2D u_tex;
void main() {
  vec4 sample_color = texture(u_tex, v_uv);
  out_color = sample_color;
}`;

const canvas = document.getElementById("surface");
const statusText = document.getElementById("status");
const renderButton = document.getElementById("render");

let wasm;
let gl;
let program;
let textProgram;
let vao;
let textVao;
let rectVbo;
let textVbo;
let screenUniform;
let textScreenUniform;
let textTextureUniform;
let textTexture;
let rectStride = 15;
let textStride = 11;
let scrollY = 0;
const decoder = new TextDecoder();
const atlas = {
  canvas: document.createElement("canvas"),
  ctx: null,
  width: 2048,
  height: 2048,
  x: 8,
  y: 8,
  rowH: 0,
  dirty: true,
  entries: new Map(),
};

function setStatus(value) {
  statusText.textContent = value;
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

function makeProgram(vertex, fragment) {
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

  program = makeProgram(vertexSource, fragmentSource);
  textProgram = makeProgram(textVertexSource, textFragmentSource);
  vao = gl.createVertexArray();
  gl.bindVertexArray(vao);

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
  const modeOffset = (rectStride - 1) * 4;
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
  gl.vertexAttribPointer(4, 1, gl.FLOAT, false, rectBytes, modeOffset);
  gl.vertexAttribDivisor(4, 1);
  screenUniform = gl.getUniformLocation(program, "u_screen");

  textVao = gl.createVertexArray();
  gl.bindVertexArray(textVao);
  textVbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, textVbo);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 16, 0);
  textScreenUniform = gl.getUniformLocation(textProgram, "u_screen");
  textTextureUniform = gl.getUniformLocation(textProgram, "u_tex");

  atlas.canvas.width = atlas.width;
  atlas.canvas.height = atlas.height;
  atlas.ctx = atlas.canvas.getContext("2d", { alpha: true });
  atlas.ctx.clearRect(0, 0, atlas.width, atlas.height);
  textTexture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, textTexture);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
}

function fitCanvas() {
  const rect = canvas.getBoundingClientRect();
  const dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));
  const maxWidth = wasm?.er_ui_max_width?.() ?? 1440;
  const maxHeight = wasm?.er_ui_max_height?.() ?? 900;
  canvas.width = Math.max(1, Math.min(maxWidth, Math.floor(rect.width * dpr)));
  canvas.height = Math.max(1, Math.min(maxHeight, Math.floor(rect.height * dpr)));
}

function paint() {
  if (!wasm || !gl) return;
  fitCanvas();

  const code = wasm.er_ui_build_shadcn_gpu_frame(canvas.width, canvas.height, scrollY);
  if (code !== 0) {
    setStatus(`error ${wasm.er_ui_last_error()}`);
    return;
  }

  const ptr = wasm.er_ui_gpu_rect_buffer_ptr();
  const len = wasm.er_ui_gpu_rect_buffer_len();
  const rects = new Float32Array(wasm.memory.buffer, ptr, len);

  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clearColor(0.035, 0.047, 0.071, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.useProgram(program);
  gl.bindVertexArray(vao);
  gl.uniform2f(screenUniform, canvas.width, canvas.height);
  gl.bindBuffer(gl.ARRAY_BUFFER, rectVbo);
  gl.bufferData(gl.ARRAY_BUFFER, rects, gl.DYNAMIC_DRAW);
  gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, len / rectStride);

  const textVertices = buildTextVertices();
  if (textVertices.length > 0) {
    if (atlas.dirty) {
      gl.bindTexture(gl.TEXTURE_2D, textTexture);
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, atlas.canvas);
      atlas.dirty = false;
    }
    gl.useProgram(textProgram);
    gl.bindVertexArray(textVao);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, textTexture);
    gl.uniform1i(textTextureUniform, 0);
    gl.uniform2f(textScreenUniform, canvas.width, canvas.height);
    gl.bindBuffer(gl.ARRAY_BUFFER, textVbo);
    gl.bufferData(gl.ARRAY_BUFFER, textVertices, gl.DYNAMIC_DRAW);
    gl.drawArrays(gl.TRIANGLES, 0, textVertices.length / 4);
  }

  setStatus(`${canvas.width}x${canvas.height} webgl2 · ${len / rectStride} rects · ${textVertices.length / 24} text · scroll ${Math.round(scrollY)}`);
}

function buildTextVertices() {
  const ptr = wasm.er_ui_gpu_text_buffer_ptr();
  const len = wasm.er_ui_gpu_text_buffer_len();
  if (len === 0) return new Float32Array();

  const textRows = new Float32Array(wasm.memory.buffer, ptr, len);
  const bytePtr = wasm.er_ui_gpu_text_bytes_ptr();
  const byteLen = wasm.er_ui_gpu_text_bytes_len();
  const textBytes = new Uint8Array(wasm.memory.buffer, bytePtr, byteLen);
  const vertices = [];

  for (let i = 0; i < len; i += textStride) {
    const x = textRows[i + 0];
    const y = textRows[i + 1];
    const maxW = textRows[i + 2];
    const maxH = textRows[i + 3];
    const color = [
      Math.round(textRows[i + 4] * 255),
      Math.round(textRows[i + 5] * 255),
      Math.round(textRows[i + 6] * 255),
      textRows[i + 7],
    ];
    const offset = textRows[i + 8] | 0;
    const count = textRows[i + 9] | 0;
    const size = Math.max(11, Math.min(22, textRows[i + 10]));
    const value = decoder.decode(textBytes.subarray(offset, offset + count));
    const entry = atlasEntry(value, size, color);
    const w = Math.min(maxW, entry.w);
    const h = Math.min(maxH + 4, entry.h);
    const x0 = x;
    const y0 = y + Math.max(0, (maxH - h) * 0.5);
    const x1 = x0 + w;
    const y1 = y0 + h;
    const u0 = entry.u0;
    const v0 = entry.v0;
    const u1 = entry.u0 + (entry.u1 - entry.u0) * (w / entry.w);
    const v1 = entry.v0 + (entry.v1 - entry.v0) * (h / entry.h);
    vertices.push(
      x0, y0, u0, v0,
      x1, y0, u1, v0,
      x1, y1, u1, v1,
      x0, y0, u0, v0,
      x1, y1, u1, v1,
      x0, y1, u0, v1,
    );
  }

  return new Float32Array(vertices);
}

function atlasEntry(value, size, color) {
  const key = `${size}|${color.join(",")}|${value}`;
  const cached = atlas.entries.get(key);
  if (cached) return cached;

  const ctx = atlas.ctx;
  const font = `600 ${Math.round(size)}px Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
  ctx.font = font;
  ctx.textBaseline = "alphabetic";
  const metrics = ctx.measureText(value);
  const pad = 4;
  const width = Math.ceil(metrics.width) + pad * 2;
  const height = Math.ceil(size * 1.45) + pad * 2;

  if (atlas.x + width >= atlas.width) {
    atlas.x = 8;
    atlas.y += atlas.rowH + 8;
    atlas.rowH = 0;
  }
  if (atlas.y + height >= atlas.height) {
    atlas.entries.clear();
    ctx.clearRect(0, 0, atlas.width, atlas.height);
    atlas.x = 8;
    atlas.y = 8;
    atlas.rowH = 0;
  }

  const x = atlas.x;
  const y = atlas.y;
  ctx.font = font;
  ctx.fillStyle = `rgba(${color[0]}, ${color[1]}, ${color[2]}, ${color[3]})`;
  ctx.clearRect(x, y, width, height);
  ctx.fillText(value, x + pad, y + pad + size);

  const entry = {
    w: width,
    h: height,
    u0: x / atlas.width,
    v0: y / atlas.height,
    u1: (x + width) / atlas.width,
    v1: (y + height) / atlas.height,
  };
  atlas.entries.set(key, entry);
  atlas.x += width + 8;
  atlas.rowH = Math.max(atlas.rowH, height);
  atlas.dirty = true;
  return entry;
}

async function main() {
  initGpu();
  const response = await fetch("../zig-out/bin/edgerun-ui-browser.wasm");
  const module = await WebAssembly.instantiateStreaming(response, {});
  wasm = module.instance.exports;
  rectStride = wasm.er_ui_gpu_rect_float_stride();
  textStride = wasm.er_ui_gpu_text_float_stride();
  paint();
}

renderButton.addEventListener("click", paint);
window.addEventListener("resize", paint);
canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  scrollY = Math.max(0, Math.min(2600, scrollY + event.deltaY));
  paint();
}, { passive: false });

main().catch((err) => {
  setStatus(err instanceof Error ? err.message : String(err));
});
