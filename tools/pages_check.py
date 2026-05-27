#!/usr/bin/env python3
import argparse
import http.server
import pathlib
import posixpath
import re
import shutil
import subprocess
import threading
import time
import urllib.parse
import urllib.request

EXPECTED_FILES = (
    ".nojekyll",
    "404.html",
    "bin/edgerun-app-runtime.wasm",
    "index.html",
    "web/index.html",
)
WASM_MAGIC = b"\x00asm"
WASM_CONTENT_TYPE = "application/wasm"
LOCAL_HOST = "127.0.0.1"
PUBLIC_RETRY_SECONDS = 120
PUBLIC_RETRY_INTERVAL_SECONDS = 5
HTTP_OK = 200
MAX_PUBLIC_LOADER_JS_BYTES = 8360
BROWSER_NAMES = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable")
BROWSER_SMOKE_SCALE = 2


class SiteHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return


def fail(message):
    raise SystemExit(message)


def rel_files(site_dir):
    files = []
    for path in site_dir.rglob("*"):
        if path.is_file():
            files.append(path.relative_to(site_dir).as_posix())
    return tuple(sorted(files))


def require(condition, message):
    if not condition:
        fail(message)


def read_text(path):
    return path.read_text(encoding="utf-8")


def verify_local_files(site_dir):
    actual = rel_files(site_dir)
    require(actual == EXPECTED_FILES, "unexpected Pages files: " + repr(actual))

    wasm = site_dir / "bin" / "edgerun-app-runtime.wasm"
    require(wasm.read_bytes()[: len(WASM_MAGIC)] == WASM_MAGIC, "runtime wasm has bad magic")

    root = read_text(site_dir / "index.html")
    require('<html lang="en">' in root, "root index missing language")
    require('name="viewport"' in root, "root index missing viewport")
    require('href="web/"' in root, "root index missing visible app link")

    entry = read_text(site_dir / "web" / "index.html")
    scripts = re.findall(r"<script[^>]*>(.*?)</script>", entry, re.DOTALL)
    require(len(scripts) == 1, "web entry must have exactly one inline script")
    loader = scripts[0].strip()
    require(
        len(loader.encode("utf-8")) <= MAX_PUBLIC_LOADER_JS_BYTES,
        f"web entry loader exceeds {MAX_PUBLIC_LOADER_JS_BYTES} bytes",
    )
    require("../bin/edgerun-app-runtime.wasm" in entry, "web entry missing runtime path")
    require("WebAssembly.instantiate" in entry, "web entry missing wasm instantiate")
    require("arrayBuffer" in entry, "web entry missing deterministic wasm bytes load")
    require("instantiateStreaming" not in entry, "web entry depends on wasm MIME streaming instantiate")
    require("getContext`webgl`" in entry, "web entry missing WebGL bridge")
    require("bindAttribLocation" in entry, "web entry missing explicit WebGL attribute binding")
    require("er_ui_build_frame" in entry, "web entry missing packed frame build")
    require("er_ui_packed_rect_buffer_ptr" in entry, "web entry missing packed rect bridge")
    require("er_ui_packed_text_vertex_buffer_ptr" in entry, "web entry missing packed text bridge")
    require("er_ui_packed_image_vertex_buffer_ptr" in entry, "web entry missing packed image bridge")
    require("er_ui_packed_icon_line_vertex_buffer_ptr" in entry, "web entry missing packed icon bridge")
    require("putImageData" not in entry, "web entry regressed to CPU pixel upload")
    require("er_ui_render_frame_hd" not in entry, "web entry regressed to CPU frame render")
    require("globalThis.__edgerunWasm" not in entry, "web entry regressed to module global handoff")
    require("er_ui_bootstrap_js_ptr" not in entry, "web entry regressed to secondary bootstrap handoff")
    require("er_ui_bootstrap_js_len" not in entry, "web entry regressed to secondary bootstrap length")
    node_execute_loader(loader)


def request(url, method):
    request_obj = urllib.request.Request(url, method=method)
    request_obj.add_header("Cache-Control", "no-cache")
    return urllib.request.urlopen(request_obj, timeout=20)


def require_url(url, method="GET"):
    with request(url, method) as response:
        require(response.status == HTTP_OK, f"{url} returned {response.status}")
        return response.headers, response.read()


def require_wasm_header(url):
    headers, _ = require_url(url, "HEAD")
    content_type = headers.get("Content-Type", "").split(";", 1)[0].lower()
    require(content_type == WASM_CONTENT_TYPE, f"{url} returned content type {content_type!r}")


def node_instantiate(url):
    script = """
const url = process.argv[1];
const response = await fetch(url);
if (!response.ok) throw new Error(`bad response ${response.status}`);
if (response.headers.get("content-type") !== "application/wasm") throw new Error(`bad content type ${response.headers.get("content-type")}`);
const instance = (await WebAssembly.instantiateStreaming(response, {})).instance;
for (const name of ["memory", "er_ui_boot", "er_ui_build_frame", "er_ui_event_bytes", "er_ui_packed_rect_buffer_ptr", "er_ui_last_error"]) {
  if (!(name in instance.exports)) throw new Error(`missing export ${name}`);
}
"""
    subprocess.run(("node", "--input-type=module", "-e", script, url), check=True)


def find_browser():
    for name in BROWSER_NAMES:
        path = shutil.which(name)
        if path is not None:
            return path
    fail("expected chromium-compatible browser for Pages runtime smoke")


def browser_smoke(url):
    browser = find_browser()
    result = subprocess.run(
        (
            browser,
            "--headless",
            "--no-sandbox",
            "--disable-gpu-sandbox",
            "--enable-webgl",
            "--enable-unsafe-swiftshader",
            f"--force-device-scale-factor={BROWSER_SMOKE_SCALE}",
            "--virtual-time-budget=5000",
            "--dump-dom",
            url,
        ),
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    require('<canvas id="c"' in result.stdout, "browser smoke did not reach app canvas")
    require("EdgeRun failed:" not in result.stdout, "browser smoke reached failure page")


def node_execute_loader(loader):
    script = """
const loader = process.argv[1];
const memory = new WebAssembly.Memory({ initial: 1 });
let booted = false;
let built = false;
let scaled = false;
const gl = {
  VERTEX_SHADER: 1, FRAGMENT_SHADER: 2, COMPILE_STATUS: 3, LINK_STATUS: 4,
  TEXTURE_2D: 5, TEXTURE_MIN_FILTER: 6, TEXTURE_MAG_FILTER: 7, LINEAR: 8,
  TEXTURE_WRAP_S: 9, TEXTURE_WRAP_T: 10, CLAMP_TO_EDGE: 11, RGBA: 12,
  LUMINANCE: 13, UNSIGNED_BYTE: 14, ARRAY_BUFFER: 15, STATIC_DRAW: 16,
  DYNAMIC_DRAW: 17, FLOAT: 18, TRIANGLE_STRIP: 19, TRIANGLES: 20,
  COLOR_BUFFER_BIT: 21, BLEND: 22, ONE: 23, ONE_MINUS_SRC_ALPHA: 24,
  createShader: () => ({}), shaderSource: () => {}, compileShader: () => {},
  getShaderParameter: () => true, getShaderInfoLog: () => "",
  createProgram: () => ({}), attachShader: () => {}, bindAttribLocation: () => {}, linkProgram: () => {},
  getProgramParameter: () => true, getProgramInfoLog: () => "",
  createBuffer: () => ({}), createTexture: () => ({}), bindTexture: () => {},
  texParameteri: () => {}, texImage2D: () => {}, bindBuffer: () => {},
  bufferData: () => {}, vertexAttribPointer: () => {}, enableVertexAttribArray: () => {},
  useProgram: () => {}, getUniformLocation: () => ({}), uniform2f: () => {},
  uniform1f: () => {}, uniform1i: () => {}, uniform4f: () => {},
  viewport: () => {}, clearColor: () => {}, clear: () => {}, enable: () => {}, disable: () => {},
  blendFunc: () => {}, blendFuncSeparate: () => {}, drawArrays: () => {},
};
globalThis.c = { width: 0, height: 0, style: {}, getContext: name => `${name}` === "webgl" ? gl : null };
globalThis.document = {
  body: { textContent: "", innerHTML: "" },
  createElement: () => ({ click: () => {} }),
  getElementById: () => null,
};
globalThis.URL = { createObjectURL: () => "blob:edgerun", revokeObjectURL: () => {} };
globalThis.Blob = class {};
globalThis.open = () => {};
globalThis.location = { hash: "" };
globalThis.innerWidth = 320;
globalThis.innerHeight = 200;
globalThis.devicePixelRatio = 2;
globalThis.performance = { now: () => 16 };
globalThis.addEventListener = () => {};
const rafCallbacks = [];
globalThis.requestAnimationFrame = callback => {
  rafCallbacks.push(callback);
  return rafCallbacks.length;
};
const exports = {
  memory,
  er_ui_boot: () => { booted = true; },
  er_ui_max_width: () => 4096,
  er_ui_max_height: () => 4096,
  er_ui_width: () => 640,
  er_ui_height: () => 400,
  er_ui_set_device_scale: value => { if (value === 2) scaled = true; },
  er_ui_build_frame: () => { built = true; return 0; },
  er_ui_last_error: () => 0,
  er_ui_font_atlas_generation: () => 1,
  er_ui_font_atlas_width: () => 1,
  er_ui_font_atlas_height: () => 1,
  er_ui_font_atlas_ptr: () => 1024,
  er_ui_post_image_width: () => 1,
  er_ui_post_image_height: () => 1,
  er_ui_post_image_rgba_ptr: () => 2048,
  er_ui_post_image_rgba_len: () => 4,
  er_ui_packed_rect_buffer_ptr: () => 0,
  er_ui_packed_rect_buffer_len: () => 0,
  er_ui_packed_image_vertex_buffer_ptr: () => 0,
  er_ui_packed_image_vertex_buffer_len: () => 0,
  er_ui_packed_text_vertex_buffer_ptr: () => 0,
  er_ui_packed_text_vertex_buffer_len: () => 0,
  er_ui_packed_icon_line_vertex_buffer_ptr: () => 0,
  er_ui_packed_icon_line_vertex_buffer_len: () => 0,
  er_ui_packed_overlay_rect_buffer_ptr: () => 0,
  er_ui_packed_overlay_rect_buffer_len: () => 0,
  er_ui_packed_overlay_text_vertex_buffer_ptr: () => 0,
  er_ui_packed_overlay_text_vertex_buffer_len: () => 0,
  er_ui_packed_overlay_icon_line_vertex_buffer_ptr: () => 0,
  er_ui_packed_overlay_icon_line_vertex_buffer_len: () => 0,
  er_ui_outbox_count: () => 0,
  er_ui_outbox_clear: () => {},
  er_ui_input_ptr: () => 4096,
  er_ui_input_capacity: () => 1024,
  er_ui_event_bytes: () => 0,
};
globalThis.fetch = async () => ({ arrayBuffer: async () => new ArrayBuffer(8) });
WebAssembly.instantiate = async () => ({ instance: { exports } });
await import(`data:text/javascript,${encodeURIComponent(loader)}`);
if (rafCallbacks.length !== 1) throw new Error(`loader scheduled ${rafCallbacks.length} initial frames`);
rafCallbacks.shift()(16);
if (rafCallbacks.length !== 0) throw new Error("loader rescheduled frame while idle");
if (!booted) throw new Error("loader did not boot wasm");
if (!built) throw new Error("loader did not build wasm frame");
if (!scaled) throw new Error("loader did not apply device scale");
if (c.width !== 640 || c.height !== 400) throw new Error("loader did not size high-dpi canvas");
"""
    subprocess.run(("node", "--input-type=module", "-e", script, loader), check=True)


def serve_local(site_dir):
    handler = lambda *args, **kwargs: SiteHandler(*args, directory=str(site_dir), **kwargs)
    server = http.server.ThreadingHTTPServer((LOCAL_HOST, 0), handler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server


def append_cache_buster(url):
    parsed = urllib.parse.urlsplit(url)
    query = parsed.query
    suffix = f"pages-check={int(time.time())}"
    query = f"{query}&{suffix}" if query else suffix
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, query, parsed.fragment))


def join_url(base, path):
    parsed = urllib.parse.urlsplit(base)
    base_path = parsed.path if parsed.path.endswith("/") else parsed.path + "/"
    joined_path = posixpath.normpath(posixpath.join(base_path, path))
    if path.endswith("/"):
        joined_path += "/"
    if not joined_path.startswith("/"):
        joined_path = "/" + joined_path
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, joined_path, "", ""))


def check_urls(base_url):
    root_url = append_cache_buster(join_url(base_url, ""))
    web_url = append_cache_buster(join_url(base_url, "web/index.html"))
    wasm_url = append_cache_buster(join_url(base_url, "bin/edgerun-app-runtime.wasm"))
    require_url(root_url)
    require_url(web_url)
    require_wasm_header(wasm_url)
    node_instantiate(wasm_url)
    browser_smoke(web_url)


def retry_public(base_url):
    deadline = time.monotonic() + PUBLIC_RETRY_SECONDS
    last_error = None
    while time.monotonic() <= deadline:
        try:
            check_urls(base_url)
            return
        except Exception as err:
            last_error = err
            time.sleep(PUBLIC_RETRY_INTERVAL_SECONDS)
    fail(f"public Pages check failed: {last_error}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--site-dir", type=pathlib.Path)
    parser.add_argument("--public-url")
    args = parser.parse_args()

    if args.site_dir is not None:
        site_dir = args.site_dir.resolve()
        verify_local_files(site_dir)
        server = serve_local(site_dir)
        try:
            port = server.server_address[1]
            check_urls(f"http://{LOCAL_HOST}:{port}/")
        finally:
            server.shutdown()
            server.server_close()

    if args.public_url is not None:
        retry_public(args.public_url)

    if args.site_dir is None and args.public_url is None:
        fail("expected --site-dir or --public-url")


if __name__ == "__main__":
    main()
