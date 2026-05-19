#ifndef EDGERUN_NETBOOT_HTTP_H
#define EDGERUN_NETBOOT_HTTP_H

/*
 * Purpose: keep HTTP boot serving details out of the netboot event loop.
 * Intention: leave main.c responsible for orchestration, not response framing.
 */

#include <arpa/inet.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <unistd.h>

#include "protocol.h"

static void log_line(const char *fmt, ...);

static bool send_all(int sock, const uint8_t *buf, size_t len) {
    while (len > 0u) {
        ssize_t sent = send(sock, buf, len, 0);
        if (sent <= 0) {
            return false;
        }
        buf += (size_t)sent;
        len -= (size_t)sent;
    }
    return true;
}

static int open_http_listener(const char *bind_ip, uint16_t port) {
    int fd;
    int one = 1;
    struct sockaddr_in addr;
    fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) {
        perror("socket");
        return -1;
    }

    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0) {
        perror("SO_REUSEADDR");
        close(fd);
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(bind_ip);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }

    if (listen(fd, HTTP_LISTEN_BACKLOG) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }

    return fd;
}

static int open_http_listener_with_fallback(uint16_t *port, bool port_explicit) {
    const uint16_t fallback_port = HTTP_PORT_FALLBACK;
    int fd;

    if (port == NULL) {
        return -1;
    }
    if (*port == 0u) {
        *port = HTTP_PORT_DEFAULT;
    }
    fd = open_http_listener(SERVER_IP, *port);
    if (fd >= 0 || port_explicit) {
        return fd;
    }
    if (*port == HTTP_PORT_DEFAULT && fallback_port != 0u) {
        fd = open_http_listener(SERVER_IP, fallback_port);
        if (fd >= 0) {
            *port = fallback_port;
            return fd;
        }
    }
    return -1;
}

static bool serve_http_file(int sock, const char *efi_path) {
    FILE *fp = fopen(efi_path, "rb");
    uint8_t buf[NETBOOT_FILE_BUFFER_SIZE];
    size_t nread;
    bool ok;

    if (fp == NULL) {
        return false;
    }

    while ((nread = fread(buf, 1, sizeof(buf), fp)) > 0u) {
        if (!send_all(sock, buf, nread)) {
            fclose(fp);
            return false;
        }
    }
    ok = !ferror(fp);
    fclose(fp);
    return ok;
}

static bool handle_http_client(int sock, const char *req_host, uint16_t port,
                               const char *efi_path, size_t efi_size) {
    char request[NETBOOT_HTTP_REQUEST_BUFFER_SIZE];
    char method[16];
    char target[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    char version[16];
    char expect_abs[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    char expect_path[NETBOOT_HTTP_PATH_BUFFER_SIZE];
    char expect_base[NETBOOT_HTTP_PATH_BUFFER_SIZE];
    char expect_base_abs[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    const char *body;
    char resp_header[NETBOOT_HTTP_HEADER_BUFFER_SIZE];
    ssize_t n;

    memset(request, 0, sizeof(request));
    n = recv(sock, request, sizeof(request) - 1u, 0);
    if (n <= 0) {
        return false;
    }
    request[sizeof(request) - 1u] = '\0';

    if (sscanf(request, "%15s %511s %15s", method, target, version) != NETBOOT_HTTP_REQUEST_FIELD_COUNT) {
        return false;
    }
    log_line("HTTP request: %s %s %s", method, target, version);
    snprintf(expect_path, sizeof(expect_path), "/%s", BOOT_FILE);
    snprintf(expect_abs, sizeof(expect_abs), "http://%s:%u%s", req_host, (unsigned)port, expect_path);
    snprintf(expect_base, sizeof(expect_base), "/%s", BOOT_FILE_BASENAME);
    snprintf(expect_base_abs, sizeof(expect_base_abs), "http://%s:%u%s", req_host, (unsigned)port, expect_base);

    if ((strcasecmp(method, "GET") != 0) || (strcmp(version, "HTTP/1.0") != 0 && strcmp(version, "HTTP/1.1") != 0) ||
        ((strcmp(target, expect_path) != 0) && (strcmp(target, expect_abs) != 0) &&
         (strcmp(target, expect_base) != 0) && (strcmp(target, expect_base_abs) != 0))) {
        const char *not_found =
            "HTTP/1.1 404 Not Found\r\n"
            "Content-Length: 0\r\n"
            "Connection: close\r\n"
            "\r\n";
        (void)send_all(sock, (const uint8_t *)not_found, strlen(not_found));
        return false;
    }

    body = BOOT_FILE;
    snprintf(resp_header, sizeof(resp_header),
             "HTTP/1.1 200 OK\r\n"
             "Content-Type: application/octet-stream\r\n"
             "Content-Length: %zu\r\n"
             "Connection: close\r\n"
             "\r\n",
             efi_size);
    log_line("HTTP 200 %s %zu", body, efi_size);
    if (!send_all(sock, (const uint8_t *)resp_header, strlen(resp_header))) {
        return false;
    }
    if (!serve_http_file(sock, efi_path)) {
        return false;
    }

    return true;
}

#endif
