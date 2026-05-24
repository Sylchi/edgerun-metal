const std = @import("std");

pub const source =
    \\const vertexSource = `#version 300 es
    \\layout(location = 0) in vec2 a_pos;
    \\layout(location = 1) in vec4 a_rect;
    \\layout(location = 2) in vec4 a_color;
    \\layout(location = 3) in vec2 a_shape;
    \\layout(location = 4) in float a_mode;
    \\layout(location = 5) in vec4 a_color2;
    \\uniform vec2 u_screen;
    \\out vec2 v_local;
    \\out vec2 v_size;
    \\out vec4 v_color;
    \\out vec4 v_color2;
    \\out float v_radius;
    \\out float v_shadow;
    \\flat out int v_mode;
    \\void main() {
    \\  vec2 px = a_rect.xy + a_pos * a_rect.zw;
    \\  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_local = a_pos * a_rect.zw;
    \\  v_size = a_rect.zw;
    \\  v_color = a_color;
    \\  v_color2 = a_color2;
    \\  v_radius = a_shape.x;
    \\  v_shadow = a_shape.y;
    \\  v_mode = int(a_mode + 0.5);
    \\}`;
    \\
    \\const fragmentSource = `#version 300 es
    \\precision highp float;
    \\in vec2 v_local;
    \\in vec2 v_size;
    \\in vec4 v_color;
    \\in vec4 v_color2;
    \\in float v_radius;
    \\in float v_shadow;
    \\flat in int v_mode;
    \\out vec4 out_color;
    \\float rounded_box(vec2 p, vec2 b, float r) {
    \\  vec2 q = abs(p) - b + vec2(r);
    \\  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    \\}
    \\void main() {
    \\  vec2 p = v_local - v_size * 0.5;
    \\  float d = rounded_box(p, v_size * 0.5, v_radius);
    \\  float aa = max(fwidth(d), 0.75);
    \\  float alpha = 1.0 - smoothstep(0.0, aa, d);
    \\  if (v_mode == 4) {
    \\    float outer = min(v_size.x, v_size.y) * 0.5;
    \\    float distance = length(p);
    \\    float edge_aa = max(fwidth(distance), 0.75);
    \\    float circle = 1.0 - smoothstep(outer - edge_aa, outer + edge_aa, distance);
    \\    float turn = atan(p.y, p.x) / 6.28318530718 + 0.25;
    \\    if (turn < 0.0) turn += 1.0;
    \\    if (turn > 1.0) turn -= 1.0;
    \\    float in_slice = step(v_color2.r, turn) * step(turn, v_color2.g);
    \\    out_color = vec4(v_color.rgb, v_color.a * circle * in_slice);
    \\  } else if (v_mode == 1) {
    \\    float sd = rounded_box(p - vec2(0.0, -v_shadow * 0.18), v_size * 0.5, v_radius + v_shadow * 0.35);
    \\    float blur = max(v_shadow, 1.0);
    \\    alpha = 1.0 - smoothstep(-blur, blur, sd);
    \\    out_color = vec4(v_color.rgb, v_color.a * alpha * 0.28);
    \\  } else if (v_mode == 2) {
    \\    float inner = rounded_box(p, v_size * 0.5 - vec2(1.25), max(v_radius - 1.25, 0.0));
    \\    float border = (1.0 - smoothstep(0.0, aa, d)) * smoothstep(0.0, aa, inner);
    \\    out_color = vec4(v_color.rgb, v_color.a * border);
    \\  } else {
    \\    vec4 fill_color = v_mode == 3 ? mix(v_color, v_color2, clamp(v_local.y / max(v_size.y, 1.0), 0.0, 1.0)) : v_color;
    \\    out_color = vec4(fill_color.rgb, fill_color.a * alpha);
    \\  }
    \\}`;
    \\
    \\const texturedVertexSource = `#version 300 es
    \\layout(location = 0) in vec4 a_data;
    \\layout(location = 1) in vec4 a_color;
    \\uniform vec2 u_screen;
    \\out vec2 v_uv;
    \\out vec4 v_color;
    \\void main() {
    \\  vec2 px = a_data.xy;
    \\  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_uv = a_data.zw;
    \\  v_color = a_color;
    \\}`;
    \\
    \\const texturedFragmentSource = `#version 300 es
    \\precision highp float;
    \\in vec2 v_uv;
    \\in vec4 v_color;
    \\out vec4 out_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  float a = texture(u_tex, v_uv).r;
    \\  out_color = vec4(v_color.rgb, v_color.a * a);
    \\}`;
    \\
    \\const imageFragmentSource = `#version 300 es
    \\precision highp float;
    \\in vec2 v_uv;
    \\in vec4 v_color;
    \\out vec4 out_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  vec4 texel = texture(u_tex, v_uv);
    \\  out_color = vec4(texel.rgb * v_color.rgb, texel.a * v_color.a);
    \\}`;
    \\
    \\const lineVertexSource = `#version 300 es
    \\layout(location = 0) in vec2 a_pos;
    \\layout(location = 1) in vec4 a_color;
    \\uniform vec2 u_screen;
    \\out vec4 v_color;
    \\void main() {
    \\  vec2 ndc = vec2(a_pos.x / u_screen.x * 2.0 - 1.0, 1.0 - a_pos.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_color = a_color;
    \\}`;
    \\
    \\const lineFragmentSource = `#version 300 es
    \\precision mediump float;
    \\in vec4 v_color;
    \\out vec4 out_color;
    \\void main() {
    \\  out_color = v_color;
    \\}`;
    \\
    \\document.head.insertAdjacentHTML("beforeend", `<style>html,body{width:100%;height:100%;margin:0;background:#09090b;overflow:hidden}canvas{display:block;width:100vw;height:100vh;background:#09090b;outline:none;cursor:none}#edgerun-dom{position:fixed;inset:0;z-index:2}#edgerun-dom[hidden]{display:none}<\/style>`);
    \\document.body.innerHTML = `<main id="edgerun-dom" hidden><\/main><canvas id="edgerun" tabindex="0" aria-label="EdgeRun native UI surface"><\/canvas>`;
    \\const canvas = document.getElementById("edgerun");
    \\const wasmBuildVersion = "index-1";
    \\const browserEventResize = 1;
    \\const browserEventWheel = 2;
    \\const browserEventPointerMove = 3;
    \\const browserEventPointerLeave = 4;
    \\const browserEventPointerDown = 5;
    \\const browserEventPointerUp = 6;
    \\const browserEventPopState = 7;
    \\const browserEventHashChange = 8;
    \\const browserEventKeyDown = 9;
    \\const browserEventPreventDefault = 1 << 0;
    \\const browserEventScheduleFrame = 1 << 1;
    \\const browserEventHostCommand = 1 << 3;
    \\const browserEventCapturePointer = 1 << 4;
    \\const browserEventReleasePointer = 1 << 5;
    \\const browserEventError = 1 << 8;
    \\const hostCommandOpenUrl = 1;
    \\const hostCommandPushRouteHash = 2;
    \\const hostCommandSetTitle = 3;
    \\const hostCommandSetElementHtml = 4;
    \\const iconVectorOpPolyline = 1;
    \\const iconVectorOpCircle = 2;
    \\const iconVectorOpEllipse = 3;
    \\const iconVectorOpRoundRect = 4;
    \\const iconVectorOpFilledCircle = 5;
    \\const iconVectorPointFloatCount = 2;
    \\const iconCircleSegments = 12;
    \\const iconLineVertexFloatCount = 6;
    \\const iconLineVertexByteStride = iconLineVertexFloatCount * Float32Array.BYTES_PER_ELEMENT;
    \\const iconLineColorByteOffset = 2 * Float32Array.BYTES_PER_ELEMENT;
    \\const hostCommandHandlers = {
    \\  [hostCommandOpenUrl]: (payload) => window.open(payload, "_blank", "noopener,noreferrer"),
    \\  [hostCommandPushRouteHash]: pushNativeRouteHash,
    \\  [hostCommandSetTitle]: (payload) => { document.title = payload; },
    \\  [hostCommandSetElementHtml]: setElementHtml,
    \\};
    \\
    \\let wasm;
    \\let gl;
    \\let shapeProgram;
    \\let texturedProgram;
    \\let imageProgram;
    \\let lineProgram;
    \\let shapeVao;
    \\let texturedVao;
    \\let rectVbo;
    \\let texturedVbo;
    \\let lineVbo;
    \\let shapeScreen;
    \\let texturedScreen;
    \\let texturedTex;
    \\let imageScreen;
    \\let imageTex;
    \\let lineScreen;
    \\let fontTexture;
    \\let postImageTexture;
    \\let fontAtlasGeneration = 0;
    \\let rectStride = 15;
    \\let textStride = 8;
    \\let iconStride = 9;
    \\let imageStride = 8;
    \\let scheduled = false;
    \\let cssWidth = 1;
    \\let cssHeight = 1;
    \\let deviceScale = 1;
    \\
    \\function shader(type, source) {
    \\  const value = gl.createShader(type);
    \\  gl.shaderSource(value, source);
    \\  gl.compileShader(value);
    \\  if (!gl.getShaderParameter(value, gl.COMPILE_STATUS)) {
    \\    throw new Error(gl.getShaderInfoLog(value) || "shader compile failed");
    \\  }
    \\  return value;
    \\}
    \\
    \\function program(vertex, fragment) {
    \\  const value = gl.createProgram();
    \\  gl.attachShader(value, shader(gl.VERTEX_SHADER, vertex));
    \\  gl.attachShader(value, shader(gl.FRAGMENT_SHADER, fragment));
    \\  gl.linkProgram(value);
    \\  if (!gl.getProgramParameter(value, gl.LINK_STATUS)) {
    \\    throw new Error(gl.getProgramInfoLog(value) || "program link failed");
    \\  }
    \\  return value;
    \\}
    \\
    \\function initGpu() {
    \\  gl = canvas.getContext("webgl2", { antialias: true, alpha: false });
    \\  if (!gl) throw new Error("WebGL2 is required");
    \\
    \\  shapeProgram = program(vertexSource, fragmentSource);
    \\  shapeVao = gl.createVertexArray();
    \\  gl.bindVertexArray(shapeVao);
    \\
    \\  const quadVbo = gl.createBuffer();
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, quadVbo);
    \\  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1]), gl.STATIC_DRAW);
    \\  gl.enableVertexAttribArray(0);
    \\  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0);
    \\
    \\  rectVbo = gl.createBuffer();
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, rectVbo);
    \\  const rectBytes = rectStride * 4;
    \\  gl.enableVertexAttribArray(1);
    \\  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, rectBytes, 0);
    \\  gl.vertexAttribDivisor(1, 1);
    \\  gl.enableVertexAttribArray(2);
    \\  gl.vertexAttribPointer(2, 4, gl.FLOAT, false, rectBytes, 24);
    \\  gl.vertexAttribDivisor(2, 1);
    \\  gl.enableVertexAttribArray(3);
    \\  gl.vertexAttribPointer(3, 2, gl.FLOAT, false, rectBytes, 16);
    \\  gl.vertexAttribDivisor(3, 1);
    \\  gl.enableVertexAttribArray(4);
    \\  gl.vertexAttribPointer(4, 1, gl.FLOAT, false, rectBytes, (rectStride - 1) * 4);
    \\  gl.vertexAttribDivisor(4, 1);
    \\  gl.enableVertexAttribArray(5);
    \\  gl.vertexAttribPointer(5, 4, gl.FLOAT, false, rectBytes, 40);
    \\  gl.vertexAttribDivisor(5, 1);
    \\  shapeScreen = gl.getUniformLocation(shapeProgram, "u_screen");
    \\
    \\  texturedProgram = program(texturedVertexSource, texturedFragmentSource);
    \\  texturedVao = gl.createVertexArray();
    \\  gl.bindVertexArray(texturedVao);
    \\  texturedVbo = gl.createBuffer();
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, texturedVbo);
    \\  gl.enableVertexAttribArray(0);
    \\  gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 32, 0);
    \\  gl.enableVertexAttribArray(1);
    \\  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 32, 16);
    \\  texturedScreen = gl.getUniformLocation(texturedProgram, "u_screen");
    \\  texturedTex = gl.getUniformLocation(texturedProgram, "u_tex");
    \\
    \\  imageProgram = program(texturedVertexSource, imageFragmentSource);
    \\  imageScreen = gl.getUniformLocation(imageProgram, "u_screen");
    \\  imageTex = gl.getUniformLocation(imageProgram, "u_tex");
    \\
    \\  lineProgram = program(lineVertexSource, lineFragmentSource);
    \\  lineVbo = gl.createBuffer();
    \\  lineScreen = gl.getUniformLocation(lineProgram, "u_screen");
    \\}
    \\
    \\function alphaTexture(width, height, ptr) {
    \\  const texture = gl.createTexture();
    \\  gl.bindTexture(gl.TEXTURE_2D, texture);
    \\  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    \\  const bytes = new Uint8Array(wasm.memory.buffer, ptr, width * height);
    \\  gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bytes);
    \\  return texture;
    \\}
    \\
    \\function rgbaTexture(width, height, ptr, len) {
    \\  if (len !== width * height * 4) throw new Error("invalid rgba image length");
    \\  const texture = gl.createTexture();
    \\  gl.bindTexture(gl.TEXTURE_2D, texture);
    \\  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    \\  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    \\  const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
    \\  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, bytes);
    \\  return texture;
    \\}
    \\
    \\function initAtlases() {
    \\  if (fontTexture) gl.deleteTexture(fontTexture);
    \\  fontTexture = alphaTexture(wasm.er_ui_font_atlas_width(), wasm.er_ui_font_atlas_height(), wasm.er_ui_font_atlas_ptr());
    \\  fontAtlasGeneration = wasm.er_ui_font_atlas_generation();
    \\}
    \\
    \\function initPostImage() {
    \\  if (postImageTexture) gl.deleteTexture(postImageTexture);
    \\  postImageTexture = rgbaTexture(wasm.er_ui_post_image_width(), wasm.er_ui_post_image_height(), wasm.er_ui_post_image_rgba_ptr(), wasm.er_ui_post_image_rgba_len());
    \\}
    \\
    \\function refreshFontAtlas() {
    \\  const nextGeneration = wasm.er_ui_font_atlas_generation();
    \\  if (fontTexture && nextGeneration === fontAtlasGeneration) return;
    \\  if (fontTexture) gl.deleteTexture(fontTexture);
    \\  fontTexture = alphaTexture(wasm.er_ui_font_atlas_width(), wasm.er_ui_font_atlas_height(), wasm.er_ui_font_atlas_ptr());
    \\  fontAtlasGeneration = nextGeneration;
    \\}
    \\
    \\function fitCanvas() {
    \\  const rect = canvas.getBoundingClientRect();
    \\  const dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));
    \\  const maxWidth = wasm?.er_ui_max_width?.() ?? 1440;
    \\  const maxHeight = wasm?.er_ui_max_height?.() ?? 900;
    \\  cssWidth = Math.max(1, Math.min(maxWidth, Math.floor(rect.width)));
    \\  cssHeight = Math.max(1, Math.min(maxHeight, Math.floor(rect.height)));
    \\  const nextDeviceScale = dpr;
    \\  const nextWidth = Math.max(1, Math.min(maxWidth, Math.floor(cssWidth * nextDeviceScale)));
    \\  const nextHeight = Math.max(1, Math.min(maxHeight, Math.floor(cssHeight * nextDeviceScale)));
    \\  canvas.width = nextWidth;
    \\  canvas.height = nextHeight;
    \\  if (wasm && Math.abs(nextDeviceScale - deviceScale) > 0.001) {
    \\    deviceScale = nextDeviceScale;
    \\    wasm.er_ui_set_device_scale(deviceScale);
    \\    initAtlases();
    \\  }
    \\}
    \\
    \\function schedule() {
    \\  if (scheduled) return;
    \\  scheduled = true;
    \\  requestAnimationFrame(() => {
    \\    scheduled = false;
    \\    paint();
    \\  });
    \\}
    \\
    \\function paint() {
    \\  if (!wasm || !gl) return;
    \\  fitCanvas();
    \\  const code = wasm.er_ui_build_browser_frame(cssWidth, cssHeight, performance.now());
    \\  if (code !== 0) {
    \\    throw new Error(`render error ${wasm.er_ui_last_error()}`);
    \\  }
    \\  schedule();
    \\
    \\  refreshFontAtlas();
    \\
    \\  gl.viewport(0, 0, canvas.width, canvas.height);
    \\  gl.clearColor(0.035, 0.035, 0.043, 1.0);
    \\  gl.clear(gl.COLOR_BUFFER_BIT);
    \\  gl.enable(gl.BLEND);
    \\  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    \\
    \\  drawRects(wasm.er_ui_gpu_rect_buffer_ptr, wasm.er_ui_gpu_rect_buffer_len);
    \\  drawImageTexture(postImageTexture, wasm.er_ui_gpu_image_vertex_buffer_ptr, wasm.er_ui_gpu_image_vertex_buffer_len, imageStride);
    \\  drawTextured(fontTexture, wasm.er_ui_gpu_text_vertex_buffer_ptr, wasm.er_ui_gpu_text_vertex_buffer_len, textStride);
    \\  drawIcons(wasm.er_ui_gpu_icon_vertex_buffer_ptr, wasm.er_ui_gpu_icon_vertex_buffer_len);
    \\  drawRects(wasm.er_ui_gpu_overlay_rect_buffer_ptr, wasm.er_ui_gpu_overlay_rect_buffer_len);
    \\  drawTextured(fontTexture, wasm.er_ui_gpu_overlay_text_vertex_buffer_ptr, wasm.er_ui_gpu_overlay_text_vertex_buffer_len, textStride);
    \\  drawIcons(wasm.er_ui_gpu_overlay_icon_vertex_buffer_ptr, wasm.er_ui_gpu_overlay_icon_vertex_buffer_len);
    \\}
    \\
    \\function drawRects(ptrFn, lenFn) {
    \\  const len = lenFn();
    \\  if (len === 0) return;
    \\  const rects = new Float32Array(wasm.memory.buffer, ptrFn(), len);
    \\  gl.useProgram(shapeProgram);
    \\  gl.bindVertexArray(shapeVao);
    \\  gl.uniform2f(shapeScreen, cssWidth, cssHeight);
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, rectVbo);
    \\  gl.bufferData(gl.ARRAY_BUFFER, rects, gl.DYNAMIC_DRAW);
    \\  gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, len / rectStride);
    \\}
    \\
    \\function drawTextured(texture, ptrFn, lenFn, stride) {
    \\  const len = lenFn();
    \\  if (len === 0) return;
    \\  const values = new Float32Array(wasm.memory.buffer, ptrFn(), len);
    \\  gl.useProgram(texturedProgram);
    \\  gl.bindVertexArray(texturedVao);
    \\  gl.activeTexture(gl.TEXTURE0);
    \\  gl.bindTexture(gl.TEXTURE_2D, texture);
    \\  gl.uniform1i(texturedTex, 0);
    \\  gl.uniform2f(texturedScreen, cssWidth, cssHeight);
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, texturedVbo);
    \\  gl.bufferData(gl.ARRAY_BUFFER, values, gl.DYNAMIC_DRAW);
    \\  gl.drawArrays(gl.TRIANGLES, 0, len / stride);
    \\}
    \\
    \\function drawIcons(ptrFn, lenFn) {
    \\  const len = lenFn();
    \\  if (len === 0) return;
    \\  if (len % iconStride !== 0) throw new Error("invalid icon instance buffer");
    \\  const instances = new Float32Array(wasm.memory.buffer, ptrFn(), len);
    \\  const out = [];
    \\  for (let offset = 0; offset < len; offset += iconStride) {
    \\    const x = instances[offset + 0];
    \\    const y = instances[offset + 1];
    \\    const w = instances[offset + 2];
    \\    const h = instances[offset + 3];
    \\    const color = [instances[offset + 4], instances[offset + 5], instances[offset + 6], instances[offset + 7]];
    \\    const id = Math.round(instances[offset + 8]);
    \\    pushIconLines(out, x, y, w, h, color, id);
    \\  }
    \\  if (out.length === 0) return;
    \\  const values = new Float32Array(out);
    \\  gl.useProgram(lineProgram);
    \\  gl.uniform2f(lineScreen, cssWidth, cssHeight);
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, lineVbo);
    \\  gl.bufferData(gl.ARRAY_BUFFER, values, gl.DYNAMIC_DRAW);
    \\  gl.enableVertexAttribArray(0);
    \\  gl.enableVertexAttribArray(1);
    \\  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, iconLineVertexByteStride, 0);
    \\  gl.vertexAttribPointer(1, 4, gl.FLOAT, false, iconLineVertexByteStride, iconLineColorByteOffset);
    \\  gl.drawArrays(gl.TRIANGLES, 0, values.length / iconLineVertexFloatCount);
    \\}
    \\
    \\function pushIconLines(out, x, y, w, h, color, id) {
    \\  const line = (x0, y0, x1, y1) => pushLine(out, x + w * x0, y + h * y0, x + w * x1, y + h * y1, Math.max(1.5, Math.min(w, h) * 0.085), color);
    \\  const vectorLen = wasm.er_ui_icon_vector_len(id);
    \\  if (vectorLen === 0) return;
    \\  const vectorPtr = wasm.er_ui_icon_vector_ptr(id);
    \\  if (vectorPtr === 0) return;
    \\  const vector = new Float32Array(wasm.memory.buffer, vectorPtr, vectorLen);
    \\  let offset = 0;
    \\  while (offset < vectorLen) {
    \\    const op = vector[offset++];
    \\    if (op === iconVectorOpPolyline) {
    \\      const count = Math.round(vector[offset++]);
    \\      const start = offset;
    \\      offset += count * iconVectorPointFloatCount;
    \\      for (let i = start + iconVectorPointFloatCount; i < offset; i += iconVectorPointFloatCount) line(vector[i - 2], vector[i - 1], vector[i], vector[i + 1]);
    \\    } else if (op === iconVectorOpCircle) {
    \\      circleLines(line, vector[offset], vector[offset + 1], vector[offset + 2]);
    \\      offset += 3;
    \\    } else if (op === iconVectorOpEllipse) {
    \\      ellipseLines(line, vector[offset], vector[offset + 1], vector[offset + 2], vector[offset + 3], vector[offset + 4] !== 0);
    \\      offset += 5;
    \\    } else if (op === iconVectorOpRoundRect) {
    \\      boxLines(line, vector[offset], vector[offset + 1], vector[offset + 2], vector[offset + 3]);
    \\      offset += 5;
    \\    } else if (op === iconVectorOpFilledCircle) {
    \\      pushFilledCircle(out, x + w * vector[offset], y + h * vector[offset + 1], Math.min(w, h) * vector[offset + 2], color);
    \\      offset += 3;
    \\    } else {
    \\      throw new Error("invalid icon vector op");
    \\    }
    \\  }
    \\}
    \\
    \\function circleLines(line, cx, cy, r) {
    \\  ellipseLines(line, cx, cy, r, r, true);
    \\}
    \\
    \\function ellipseLines(line, cx, cy, rx, ry, full) {
    \\  const segments = iconCircleSegments;
    \\  const start = full ? 0 : 0.5;
    \\  const span = 1 - start;
    \\  let px = cx + Math.cos(start * Math.PI * 2) * rx;
    \\  let py = cy + Math.sin(start * Math.PI * 2) * ry;
    \\  for (let i = 1; i <= segments; i++) {
    \\    const turn = start + i * span / segments;
    \\    const a = turn * Math.PI * 2;
    \\    const nx = cx + Math.cos(a) * rx;
    \\    const ny = cy + Math.sin(a) * ry;
    \\    line(px, py, nx, ny);
    \\    px = nx;
    \\    py = ny;
    \\  }
    \\}
    \\
    \\function pushFilledCircle(out, cx, cy, r, color) {
    \\  for (let i = 0; i < iconCircleSegments; i++) {
    \\    const a0 = i * Math.PI * 2 / iconCircleSegments;
    \\    const a1 = (i + 1) * Math.PI * 2 / iconCircleSegments;
    \\    pushVertex(out, cx, cy, color);
    \\    pushVertex(out, cx + Math.cos(a0) * r, cy + Math.sin(a0) * r, color);
    \\    pushVertex(out, cx + Math.cos(a1) * r, cy + Math.sin(a1) * r, color);
    \\  }
    \\}
    \\
    \\function boxLines(line, x, y, w, h) {
    \\  line(x, y, x + w, y);
    \\  line(x + w, y, x + w, y + h);
    \\  line(x + w, y + h, x, y + h);
    \\  line(x, y + h, x, y);
    \\}
    \\
    \\function pushLine(out, x0, y0, x1, y1, width, color) {
    \\  const dx = x1 - x0;
    \\  const dy = y1 - y0;
    \\  const len = Math.hypot(dx, dy);
    \\  if (len <= 0.001) return;
    \\  const nx = -dy / len * width * 0.5;
    \\  const ny = dx / len * width * 0.5;
    \\  pushVertex(out, x0 + nx, y0 + ny, color);
    \\  pushVertex(out, x1 + nx, y1 + ny, color);
    \\  pushVertex(out, x1 - nx, y1 - ny, color);
    \\  pushVertex(out, x0 + nx, y0 + ny, color);
    \\  pushVertex(out, x1 - nx, y1 - ny, color);
    \\  pushVertex(out, x0 - nx, y0 - ny, color);
    \\}
    \\
    \\function pushVertex(out, x, y, color) {
    \\  out.push(x, y, color[0], color[1], color[2], color[3]);
    \\}
    \\
    \\function drawImageTexture(texture, ptrFn, lenFn, stride) {
    \\  const len = lenFn();
    \\  if (len === 0) return;
    \\  if (!texture) throw new Error("post image texture missing");
    \\  const values = new Float32Array(wasm.memory.buffer, ptrFn(), len);
    \\  gl.useProgram(imageProgram);
    \\  gl.bindVertexArray(texturedVao);
    \\  gl.activeTexture(gl.TEXTURE0);
    \\  gl.bindTexture(gl.TEXTURE_2D, texture);
    \\  gl.uniform1i(imageTex, 0);
    \\  gl.uniform2f(imageScreen, cssWidth, cssHeight);
    \\  gl.bindBuffer(gl.ARRAY_BUFFER, texturedVbo);
    \\  gl.bufferData(gl.ARRAY_BUFFER, values, gl.DYNAMIC_DRAW);
    \\  gl.drawArrays(gl.TRIANGLES, 0, len / stride);
    \\}
    \\
    \\async function main() {
    \\  wasm = globalThis.__edgerunWasm;
    \\  initGpu();
    \\  fitCanvas();
    \\  wasm.er_ui_set_device_scale(deviceScale);
    \\  syncHostAppearance();
    \\  rectStride = wasm.er_ui_gpu_rect_float_stride();
    \\  textStride = wasm.er_ui_gpu_text_vertex_float_stride();
    \\  iconStride = wasm.er_ui_gpu_icon_vertex_float_stride();
    \\  imageStride = wasm.er_ui_gpu_image_vertex_float_stride();
    \\  initAtlases();
    \\  initPostImage();
    \\  applyHostResult(wasm.er_ui_browser_boot(), null);
    \\  syncNativeRouteFromBrowser();
    \\  paint();
    \\}
    \\
    \\function wasmPath() {
    \\  return "../bin/edgerun-ui-browser.wasm";
    \\}
    \\
    \\function writeInputBytes(value) {
    \\  const encoded = new TextEncoder().encode(value);
    \\  if (encoded.length > wasm.er_ui_input_capacity()) throw new Error("input bridge buffer exceeded");
    \\  new Uint8Array(wasm.memory.buffer, wasm.er_ui_input_ptr(), encoded.length).set(encoded);
    \\  return encoded.length;
    \\}
    \\
    \\function readNativeString(ptr, len) {
    \\  const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
    \\  return new TextDecoder().decode(bytes);
    \\}
    \\
    \\function syncNativeRouteFromBrowser() {
    \\  if (!wasm) return;
    \\  const len = writeInputBytes(location.hash);
    \\  dispatchBrowserEvent(browserEventHashChange, 0, 0, 0, len, null);
    \\}
    \\
    \\function hostAppearanceValue() {
    \\  if (!window.matchMedia) return 0;
    \\  if (window.matchMedia("(prefers-color-scheme: dark)").matches) return 2;
    \\  if (window.matchMedia("(prefers-color-scheme: light)").matches) return 1;
    \\  return 0;
    \\}
    \\
    \\function syncHostAppearance() {
    \\  if (!wasm || !wasm.er_ui_set_host_appearance) return;
    \\  wasm.er_ui_set_host_appearance(hostAppearanceValue());
    \\}
    \\
    \\function dispatchBrowserEvent(kind, x, y, deltaY, textLen, event) {
    \\  if (!wasm) return 0;
    \\  const result = wasm.er_ui_browser_event(
    \\    kind,
    \\    x,
    \\    y,
    \\    deltaY,
    \\    event && event.ctrlKey ? 1 : 0,
    \\    event && event.metaKey ? 1 : 0,
    \\    event && event.altKey ? 1 : 0,
    \\    textLen,
    \\    cssWidth,
    \\    cssHeight,
    \\  );
    \\  applyHostResult(result, event);
    \\  return result;
    \\}
    \\
    \\function applyHostResult(result, event) {
    \\  if ((result & browserEventError) !== 0) throw new Error(`event error ${wasm.er_ui_last_error()}`);
    \\  if (event && (result & browserEventPreventDefault) !== 0) event.preventDefault();
    \\  if ((result & browserEventHostCommand) !== 0) pumpHostCommands();
    \\  if ((result & browserEventScheduleFrame) !== 0) schedule();
    \\}
    \\
    \\function canvasPoint(event) {
    \\  const rect = canvas.getBoundingClientRect();
    \\  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
    \\}
    \\
    \\window.addEventListener("resize", () => {
    \\  dispatchBrowserEvent(browserEventResize, 0, 0, 0, 0, null);
    \\});
    \\
    \\if (window.matchMedia) {
    \\  const darkPreference = window.matchMedia("(prefers-color-scheme: dark)");
    \\  darkPreference.addEventListener("change", () => {
    \\    syncHostAppearance();
    \\    schedule();
    \\  });
    \\}
    \\
    \\canvas.addEventListener("wheel", (event) => {
    \\  dispatchBrowserEvent(browserEventWheel, 0, 0, event.deltaY, 0, event);
    \\}, { passive: false });
    \\
    \\canvas.addEventListener("pointermove", (event) => {
    \\  const point = canvasPoint(event);
    \\  dispatchBrowserEvent(browserEventPointerMove, point.x, point.y, 0, 0, event);
    \\});
    \\
    \\canvas.addEventListener("pointerleave", () => {
    \\  dispatchBrowserEvent(browserEventPointerLeave, 0, 0, 0, 0, null);
    \\});
    \\
    \\canvas.addEventListener("pointerdown", (event) => {
    \\  const point = canvasPoint(event);
    \\  const result = dispatchBrowserEvent(browserEventPointerDown, point.x, point.y, 0, 0, event);
    \\  if ((result & browserEventCapturePointer) !== 0 && !canvas.hasPointerCapture(event.pointerId)) canvas.setPointerCapture(event.pointerId);
    \\});
    \\
    \\canvas.addEventListener("pointerup", (event) => {
    \\  const point = canvasPoint(event);
    \\  const result = dispatchBrowserEvent(browserEventPointerUp, point.x, point.y, 0, 0, event);
    \\  if ((result & browserEventReleasePointer) !== 0 && canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    \\});
    \\
    \\function pumpHostCommands() {
    \\  const count = wasm.er_ui_host_command_count();
    \\  for (let index = 0; index < count; index += 1) {
    \\    const kind = wasm.er_ui_host_command_kind(index);
    \\    const id = wasm.er_ui_host_command_id(index);
    \\    const target = readNativeString(wasm.er_ui_host_command_target_ptr(index), wasm.er_ui_host_command_target_len(index));
    \\    const payload = readNativeString(wasm.er_ui_host_command_payload_ptr(index), wasm.er_ui_host_command_payload_len(index));
    \\    const handler = hostCommandHandlers[kind];
    \\    if (handler) handler(payload, target, id);
    \\    else throw new Error(`unknown host command ${kind}:${id}`);
    \\  }
    \\  if (count > 0) wasm.er_ui_host_command_clear();
    \\}
    \\
    \\function pushNativeRouteHash(routeHash) {
    \\  const url = `${location.pathname}${location.search}${routeHash}`;
    \\  if (`${location.pathname}${location.search}${location.hash}` !== url) history.pushState(null, "", url);
    \\}
    \\
    \\function setElementHtml(payload, target) {
    \\  const element = document.getElementById(target);
    \\  if (!element) {
    \\    throw new Error(`missing host command target ${target}`);
    \\  }
    \\  element.innerHTML = payload;
    \\  element.hidden = payload.length === 0;
    \\}
    \\
    \\window.addEventListener("popstate", () => {
    \\  const len = writeInputBytes(location.hash);
    \\  dispatchBrowserEvent(browserEventPopState, 0, 0, 0, len, null);
    \\});
    \\
    \\window.addEventListener("hashchange", () => {
    \\  const len = writeInputBytes(location.hash);
    \\  dispatchBrowserEvent(browserEventHashChange, 0, 0, 0, len, null);
    \\});
    \\
    \\window.addEventListener("keydown", (event) => {
    \\  if (!wasm) return;
    \\  const keyLen = writeInputBytes(event.key);
    \\  dispatchBrowserEvent(browserEventKeyDown, 0, 0, 0, keyLen, event);
    \\});
    \\
    \\main().catch((err) => { throw err; });
;

fn contains(needle: []const u8) bool {
    return std.mem.indexOf(u8, source, needle) != null;
}

test "browser runtime javascript owns dom and browser policy after wasm eval" {
    try std.testing.expect(contains("document.body.innerHTML"));
    try std.testing.expect(contains("<canvas id=\"edgerun\""));
    try std.testing.expect(contains("wasm = globalThis.__edgerunWasm"));
    try std.testing.expect(contains("dispatchBrowserEvent(browserEventWheel"));
    try std.testing.expect(contains("prefers-color-scheme: dark"));
    try std.testing.expect(contains("wasm.er_ui_set_host_appearance(hostAppearanceValue())"));
    try std.testing.expect(contains("window.addEventListener(\"keydown\""));
    try std.testing.expect(contains("wasm.er_ui_build_browser_frame(cssWidth, cssHeight, performance.now())"));
    try std.testing.expect(contains("cursor:none"));
    try std.testing.expect(!contains("style.cursor"));
    try std.testing.expect(!contains("er_ui_cursor_css"));
    try std.testing.expect(!contains("WebAssembly.instantiateStreaming"));
    try std.testing.expect(!contains("console.debug"));
    try std.testing.expect(!contains("webgl atlas"));
}
