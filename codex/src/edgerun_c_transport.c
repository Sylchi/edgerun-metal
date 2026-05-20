#define ER_TRANSPORT_SCHEME_HTTPS "https"
#define ER_TRANSPORT_SCHEME_HTTP "http"
#define ER_TRANSPORT_DEFAULT_HTTP_PORT 80u
#define ER_TRANSPORT_DEFAULT_HTTPS_PORT 443u
#define ER_TRANSPORT_MAX_PORT 65535u
#define ER_TRANSPORT_MAX_PORT_DIGITS 5u
#define ER_TRANSPORT_DECIMAL_BASE 10u
#define ER_TRANSPORT_HEX_BASE 16u
#define ER_TRANSPORT_IO_CHUNK 4096u
#define ER_TRANSPORT_SELF_TEST_PORT 8080u
#define ER_TRANSPORT_HTTP_STATUS_OK_MIN 200u
#define ER_TRANSPORT_HTTP_STATUS_OK_MAX 299u
#define ER_TRANSPORT_HTTP_STATUS_DIGITS 3u
#define ER_TRANSPORT_HTTP_VERSION_PREFIX "HTTP/1."
#define ER_TRANSPORT_HEADER_TERMINATOR "\r\n\r\n"
#define ER_TRANSPORT_LINE_TERMINATOR "\r\n"
#define ER_TRANSPORT_TRANSFER_ENCODING "transfer-encoding"
#define ER_TRANSPORT_CHUNKED "chunked"

typedef struct {
    bool tls;
    char host[256];
    char path[2048];
    unsigned port;
} ErHttpUrl;

typedef struct {
    const char *name;
    const char *value;
} ErHttpHeader;

typedef void (*ErSseEventFn)(void *user, const char *event_json);

typedef struct {
    char *events[4];
    size_t count;
} ErTransportSelfTestEvents;

static int er_transport_hex_value(unsigned char c) {
    if (c >= '0' && c <= '9') return (int)(c - '0');
    if (c >= 'a' && c <= 'f') return (int)(c - 'a') + (int)ER_TRANSPORT_DECIMAL_BASE;
    if (c >= 'A' && c <= 'F') return (int)(c - 'A') + (int)ER_TRANSPORT_DECIMAL_BASE;
    return -1;
}

static unsigned char er_transport_ascii_lower(unsigned char c) {
    if (c >= 'A' && c <= 'Z') return (unsigned char)(c - 'A' + 'a');
    return c;
}

static bool er_transport_ascii_equal_n(const char *a, const char *b, size_t len) {
    for (size_t i = 0; i < len; i++) {
        if (er_transport_ascii_lower((unsigned char)a[i]) != er_transport_ascii_lower((unsigned char)b[i])) {
            return false;
        }
    }
    return true;
}

static bool er_transport_header_value_valid(const char *value) {
    if (!value) return false;
    for (const char *p = value; *p; p++) {
        if (*p == '\r' || *p == '\n') return false;
    }
    return true;
}

static bool er_transport_parse_http_status(const char *response, unsigned *status_out) {
    const char *p;
    unsigned status = 0;

    if (!response || !status_out) return false;
    if (!starts_with(response, ER_TRANSPORT_HTTP_VERSION_PREFIX)) return false;
    p = strchr(response, ' ');
    if (!p) return false;
    p++;
    for (size_t i = 0; i < ER_TRANSPORT_HTTP_STATUS_DIGITS; i++) {
        if (!isdigit((unsigned char)p[i])) return false;
        status = status * ER_TRANSPORT_DECIMAL_BASE + (unsigned)(p[i] - '0');
    }
    *status_out = status;
    return true;
}

static const char *er_transport_response_body_start(const char *response) {
    const char *body = strstr(response, ER_TRANSPORT_HEADER_TERMINATOR);
    if (!body) die("codex transport response missing header terminator");
    return body + strlen(ER_TRANSPORT_HEADER_TERMINATOR);
}

static bool er_transport_header_name_matches(const char *line, size_t len, const char *name) {
    size_t name_len = strlen(name);
    const char *separator = line + name_len;
    if (len <= name_len || *separator != ':') return false;
    return er_transport_ascii_equal_n(line, name, name_len);
}

static bool er_transport_header_value_has_token(const char *value, size_t len, const char *token) {
    size_t token_len = strlen(token);
    const char *p = value;
    const char *end = value + len;

    while (p < end) {
        while (p < end && (*p == ' ' || *p == '\t' || *p == ',')) p++;
        const char *token_start = p;
        while (p < end && *p != ',' && *p != ';' && *p != ' ' && *p != '\t' && *p != '\r') p++;
        if ((size_t)(p - token_start) == token_len &&
            er_transport_ascii_equal_n(token_start, token, token_len)) {
            return true;
        }
        while (p < end && *p != ',') p++;
    }
    return false;
}

static bool er_transport_response_is_chunked(const char *response) {
    const char *headers_end = strstr(response, ER_TRANSPORT_HEADER_TERMINATOR);
    const char *line;

    if (!headers_end) die("codex transport response missing header terminator");
    line = strstr(response, ER_TRANSPORT_LINE_TERMINATOR);
    if (!line || line >= headers_end) return false;
    line += strlen(ER_TRANSPORT_LINE_TERMINATOR);
    while (line < headers_end) {
        const char *next = strstr(line, ER_TRANSPORT_LINE_TERMINATOR);
        size_t len;
        if (!next || next > headers_end) next = headers_end;
        len = (size_t)(next - line);
        if (er_transport_header_name_matches(line, len, ER_TRANSPORT_TRANSFER_ENCODING)) {
            const char *value = line + strlen(ER_TRANSPORT_TRANSFER_ENCODING) + strlen(":");
            size_t value_len = len - strlen(ER_TRANSPORT_TRANSFER_ENCODING) - strlen(":");
            return er_transport_header_value_has_token(value, value_len, ER_TRANSPORT_CHUNKED);
        }
        line = next + strlen(ER_TRANSPORT_LINE_TERMINATOR);
    }
    return false;
}

static char *er_transport_chunked_body_new(const char *body) {
    Buffer out;
    const char *p = body;

    buffer_init(&out);
    for (;;) {
        size_t chunk_size = 0;
        bool saw_digit = false;

        while (*p) {
            int value = er_transport_hex_value((unsigned char)*p);
            if (value < 0) break;
            saw_digit = true;
            chunk_size = chunk_size * ER_TRANSPORT_HEX_BASE + (size_t)value;
            p++;
        }
        if (!saw_digit) die("codex transport invalid chunk size");
        while (*p && *p != '\r' && *p != '\n') p++;
        if (!starts_with(p, ER_TRANSPORT_LINE_TERMINATOR)) die("codex transport invalid chunk header terminator");
        p += strlen(ER_TRANSPORT_LINE_TERMINATOR);
        if (chunk_size == 0) break;
        if (strlen(p) < chunk_size) die("codex transport truncated chunk body");
        buffer_append(&out, p, chunk_size);
        p += chunk_size;
        if (!starts_with(p, ER_TRANSPORT_LINE_TERMINATOR)) die("codex transport invalid chunk body terminator");
        p += strlen(ER_TRANSPORT_LINE_TERMINATOR);
    }
    return out.data ? out.data : xstrdup("");
}

static char *er_transport_sse_body_new(const char *response) {
    unsigned status;
    const char *body;

    if (!er_transport_parse_http_status(response, &status)) die("codex transport invalid HTTP status line");
    if (status < ER_TRANSPORT_HTTP_STATUS_OK_MIN || status > ER_TRANSPORT_HTTP_STATUS_OK_MAX) {
        die("codex transport HTTP request failed with status %u", status);
    }
    body = er_transport_response_body_start(response);
    if (er_transport_response_is_chunked(response)) {
        return er_transport_chunked_body_new(body);
    }
    return xstrdup(body);
}

static bool er_transport_parse_decimal_port(const char *text, size_t len, unsigned *out) {
    unsigned port = 0;
    if (len == 0 || len > ER_TRANSPORT_MAX_PORT_DIGITS) return false;
    for (size_t i = 0; i < len; i++) {
        //@optimizer-ignore bounded port parser must inspect each caller-provided digit
        if (!isdigit((unsigned char)text[i])) return false;
        //@optimizer-ignore bounded port parser converts each digit in place
        port = port * ER_TRANSPORT_DECIMAL_BASE + (unsigned)(text[i] - '0');
        if (port > ER_TRANSPORT_MAX_PORT) return false;
    }
    if (port == 0) return false;
    *out = port;
    return true;
}

static bool er_transport_parse_url(const char *url, ErHttpUrl *out) {
    const char *after_scheme;
    const char *host_start;
    const char *host_end;
    const char *path_start;
    const char *colon;
    size_t host_len;
    size_t path_len;
    unsigned port;
    bool tls;

    if (!url || !out) return false;
    if (starts_with(url, ER_TRANSPORT_SCHEME_HTTPS "://")) {
        tls = true;
        port = ER_TRANSPORT_DEFAULT_HTTPS_PORT;
        after_scheme = url + strlen(ER_TRANSPORT_SCHEME_HTTPS "://");
    } else if (starts_with(url, ER_TRANSPORT_SCHEME_HTTP "://")) {
        tls = false;
        port = ER_TRANSPORT_DEFAULT_HTTP_PORT;
        after_scheme = url + strlen(ER_TRANSPORT_SCHEME_HTTP "://");
    } else {
        return false;
    }

    host_start = after_scheme;
    path_start = strchr(host_start, '/');
    if (!path_start) path_start = url + strlen(url);
    host_end = path_start;
    colon = memchr(host_start, ':', (size_t)(host_end - host_start));
    if (colon) {
        if (!er_transport_parse_decimal_port(colon + 1, (size_t)(host_end - colon - 1), &port)) {
            return false;
        }
        host_end = colon;
    }
    host_len = (size_t)(host_end - host_start);
    if (host_len == 0 || host_len >= sizeof(out->host)) return false;
    for (size_t i = 0; i < host_len; i++) {
        unsigned char c = (unsigned char)host_start[i];
        if (!(isalnum(c) || c == '.' || c == '-')) return false;
    }

    path_len = *path_start ? strlen(path_start) : strlen("/");
    if (path_len >= sizeof(out->path)) return false;
    memset(out, 0, sizeof(*out));
    memcpy(out->host, host_start, host_len);
    out->host[host_len] = 0;
    if (*path_start) {
        memcpy(out->path, path_start, path_len + 1u);
    } else {
        memcpy(out->path, "/", sizeof("/"));
    }
    out->port = port;
    out->tls = tls;
    return true;
}

//@optimizer-ignore-function HTTP request builder must iterate caller-owned headers bounded by header_count
static char *er_transport_request_text_new(const ErHttpUrl *url,
                                           const ErHttpHeader *headers,
                                           size_t header_count,
                                           const char *body) {
    Buffer req;
    size_t body_len;

    if (!url || !headers || !body) return NULL;
    body_len = strlen(body);
    buffer_init(&req);
    buffer_appendf(&req, "POST %s HTTP/1.1\r\n", url->path);
    buffer_appendf(&req, "Host: %s\r\n", url->host);
    buffer_append(&req, "Connection: close\r\n", strlen("Connection: close\r\n"));
    buffer_appendf(&req, "Content-Length: %zu\r\n", body_len);
    for (size_t i = 0; i < header_count; i++) {
        //@optimizer-ignore HTTP header table is caller-owned and bounded by explicit header_count
        if (!headers[i].name || !headers[i].value ||
            !er_transport_header_value_valid(headers[i].name) ||
            !er_transport_header_value_valid(headers[i].value)) {
            free(req.data);
            return NULL;
        }
        //@optimizer-ignore HTTP header table is caller-owned and bounded by explicit header_count
        buffer_appendf(&req, "%s: %s\r\n", headers[i].name, headers[i].value);
    }
    buffer_append(&req, "\r\n", strlen("\r\n"));
    buffer_append(&req, body, body_len);
    return req.data;
}

static int er_transport_connect_plain(const ErHttpUrl *url) {
    struct addrinfo hints;
    struct addrinfo *result = NULL;
    struct addrinfo *rp;
    char port_text[16];
    int fd = -1;
    int rc;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(port_text, sizeof(port_text), "%u", url->port);
    rc = getaddrinfo(url->host, port_text, &hints, &result);
    if (rc != 0) die("codex transport DNS failed for %s: %s", url->host, gai_strerror(rc));
    for (rp = result; rp; rp = rp->ai_next) {
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd < 0) continue;
        if (connect(fd, rp->ai_addr, rp->ai_addrlen) == 0) break;
        close(fd);
        fd = -1;
    }
    freeaddrinfo(result);
    if (fd < 0) die("codex transport connect failed for %s:%u", url->host, url->port);
    return fd;
}

static void er_transport_write_all(int fd, const char *data, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t written = write(fd, data + off, len - off);
        if (written <= 0) die("codex transport write failed: %s", strerror(errno));
        off += (size_t)written;
    }
}

static char *er_transport_read_response_new(int fd) {
    Buffer out;
    char chunk[ER_TRANSPORT_IO_CHUNK];
    buffer_init(&out);
    for (;;) {
        ssize_t got = read(fd, chunk, sizeof(chunk));
        if (got < 0) die("codex transport read failed: %s", strerror(errno));
        if (got == 0) break;
        buffer_append(&out, chunk, (size_t)got);
    }
    return out.data ? out.data : xstrdup("");
}

static void er_transport_stream_sse_text(const char *text, ErSseEventFn on_event, void *user) {
    Buffer event;
    const char *line = text;
    buffer_init(&event);
    while (*line) {
        const char *end = strchr(line, '\n');
        size_t len = end ? (size_t)(end - line) : strlen(line);
        if (len > 0 && line[len - 1u] == '\r') len--;
        if (len == 0) {
            if (event.len > 0) {
                on_event(user, event.data);
                event.len = 0;
                if (event.data) event.data[0] = 0;
            }
        } else if (len >= strlen("data: ") && memcmp(line, "data: ", strlen("data: ")) == 0) {
            if (event.len) buffer_append_c(&event, '\n');
            buffer_append(&event, line + strlen("data: "), len - strlen("data: "));
        } else if (getenv("EDGERUN_C_DEBUG")) {
            fprintf(stderr, "[debug] non-sse: %.*s\n", (int)len, line);
        }
        if (!end) break;
        line = end + 1;
    }
    if (event.len > 0) on_event(user, event.data);
    free(event.data);
}

static void er_transport_post_sse(const char *url_text,
                                  const ErHttpHeader *headers,
                                  size_t header_count,
                                  const char *body,
                                  ErSseEventFn on_event,
                                  void *user) {
    ErHttpUrl url;
    int fd;
    char *request;
    char *response;
    char *sse_body;

    if (!er_transport_parse_url(url_text, &url)) die("codex transport invalid URL: %s", url_text);
    request = er_transport_request_text_new(&url, headers, header_count, body);
    if (!request) die("codex transport failed to build request");
    fd = er_transport_connect_plain(&url);
    if (url.tls) {
        ErTlsConnection tls = er_tls_connection_open(url.host, fd);
        er_tls_write_all(&tls, request, strlen(request));
        response = er_tls_read_response_new(&tls);
        er_tls_connection_close(&tls);
    } else {
        er_transport_write_all(fd, request, strlen(request));
        response = er_transport_read_response_new(fd);
        close(fd);
    }
    sse_body = er_transport_sse_body_new(response);
    er_transport_stream_sse_text(sse_body, on_event, user);
    free(sse_body);
    free(response);
    free(request);
}

static void er_transport_self_test_event(void *user, const char *event_json) {
    ErTransportSelfTestEvents *events = (ErTransportSelfTestEvents *)user;
    if (events->count >= sizeof(events->events) / sizeof(events->events[0])) die("too many transport self-test events");
    events->events[events->count++] = xstrdup(event_json);
}

static int er_transport_self_test(void) {
    ErHttpUrl url;
    ErHttpHeader headers[] = {
        {"accept", "text/event-stream"},
        {"content-type", "application/json"},
    };
    ErTransportSelfTestEvents events = {0};
    char *sse_body;
    char *request;

    if (!er_transport_parse_url("https://chatgpt.com/backend-api/codex/responses", &url)) return 1;
    if (!url.tls || strcmp(url.host, "chatgpt.com") != 0 ||
        strcmp(url.path, "/backend-api/codex/responses") != 0 ||
        url.port != ER_TRANSPORT_DEFAULT_HTTPS_PORT) {
        return 1;
    }
    if (!er_transport_parse_url("http://example.com:8080/sse", &url)) return 1;
    if (url.tls || strcmp(url.host, "example.com") != 0 ||
        strcmp(url.path, "/sse") != 0 || url.port != ER_TRANSPORT_SELF_TEST_PORT) {
        return 1;
    }
    request = er_transport_request_text_new(&url, headers, sizeof(headers) / sizeof(headers[0]), "{}");
    if (!request) return 2;
    if (!strstr(request, "POST /sse HTTP/1.1\r\n") ||
        !strstr(request, "Host: example.com\r\n") ||
        !strstr(request, "Content-Length: 2\r\n") ||
        !strstr(request, "\r\n\r\n{}")) {
        free(request);
        return 2;
    }
    free(request);
    sse_body = er_transport_sse_body_new(
        "HTTP/1.1 200 OK\r\n"
        "Transfer-Encoding: chunked\r\n"
        "\r\n"
        "16\r\n"
        "data: {\"type\":\"one\"}\n\n\r\n"
        "16\r\n"
        "data: {\"type\":\"two\"}\n\n\r\n"
        "0\r\n"
        "\r\n");
    er_transport_stream_sse_text(sse_body, er_transport_self_test_event, &events);
    if (events.count != 2 ||
        strcmp(events.events[0], "{\"type\":\"one\"}") != 0 ||
        strcmp(events.events[1], "{\"type\":\"two\"}") != 0) {
        free(sse_body);
        for (size_t i = 0; i < events.count; i++) free(events.events[i]);
        return 2;
    }
    for (size_t i = 0; i < events.count; i++) free(events.events[i]);
    free(sse_body);
    return 0;
}
