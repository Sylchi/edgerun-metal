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
MAX_PUBLIC_LOADER_JS_BYTES = 500
BROWSER_NAMES = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable")


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
    require(len(loader.encode("utf-8")) <= MAX_PUBLIC_LOADER_JS_BYTES, "web entry loader exceeds 500 bytes")
    require("../bin/edgerun-app-runtime.wasm" in entry, "web entry missing runtime path")
    require("WebAssembly.instantiateStreaming" in entry, "web entry missing streaming instantiate")
    require("!r.ok" in entry, "web entry missing HTTP status check")
    require("globalThis.__edgerunWasm" in entry, "web entry missing module global handoff")
    require("er_ui_bootstrap_js_ptr" in entry, "web entry missing app-owned bootstrap handoff")
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
for (const name of ["memory", "er_ui_boot", "er_ui_render_frame", "er_ui_event_bytes", "er_ui_pixels_ptr", "er_ui_last_error"]) {
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
            "--disable-gpu",
            "--no-sandbox",
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
const bridge = "if(!globalThis.__edgerunWasm)throw Error('missing global wasm');document.body.innerHTML='<canvas id=c></canvas>'";
const encodedBridge = new TextEncoder().encode(bridge);
const memory = new WebAssembly.Memory({ initial: 1 });
new Uint8Array(memory.buffer, 0, encodedBridge.length).set(encodedBridge);
globalThis.document = { body: { textContent: "", innerHTML: "" } };
globalThis.fetch = async () => ({ ok: true });
WebAssembly.instantiateStreaming = async () => ({
  instance: {
    exports: {
      memory,
      er_ui_bootstrap_js_ptr: () => 0,
      er_ui_bootstrap_js_len: () => encodedBridge.length,
    },
  },
});
await import(`data:text/javascript,${encodeURIComponent(loader)}`);
if (document.body.innerHTML !== "<canvas id=c></canvas>") throw new Error("loader did not execute wasm-owned bridge");
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
