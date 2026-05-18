#ifndef EDGERUN_NETBOOT_TFTP_H
#define EDGERUN_NETBOOT_TFTP_H

/*
 * Purpose: isolate TFTP RRQ parsing and block transfer from netboot orchestration.
 * Intention: keep main.c focused on socket readiness and DHCP decisions.
 */

#include <arpa/inet.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

#include "protocol.h"

static void log_line(const char *fmt, ...);
static bool is_same_peer(const struct sockaddr_in *a, const struct sockaddr_in *b);
static int open_dgram_socket(uint16_t port, bool allow_bcast);

static bool send_tftp_error(int sock, const struct sockaddr_in *client, uint16_t code, const char *msg) {
    uint8_t pkt[TFTP_ERROR_PACKET_BYTES];
    size_t len = strlen(msg);
    uint16_t code_net = htons(code);
    size_t total;

    if (len > sizeof(pkt) - TFTP_ERROR_OVERHEAD_BYTES) {
        len = sizeof(pkt) - TFTP_ERROR_OVERHEAD_BYTES;
    }
    pkt[NETBOOT_BYTE0] = 0;
    pkt[NETBOOT_BYTE1] = TFTP_OP_ERR;
    memcpy(&pkt[TFTP_ERROR_CODE_OFFSET], &code_net, DHCP_OPTION_ARCH_PAYLOAD_LEN);
    memcpy(&pkt[TFTP_ERROR_MSG_OFFSET], msg, len);
    pkt[TFTP_ERROR_MSG_OFFSET + len] = 0;
    total = TFTP_ERROR_OVERHEAD_BYTES + len;
    return sendto(sock, pkt, total, 0, (const struct sockaddr *)client, (socklen_t)sizeof(*client)) == (ssize_t)total;
}

static bool wait_for_ack(int sock, const struct sockaddr_in *peer, uint16_t expected_block) {
    while (true) {
        fd_set fds;
        struct timeval tv = {(time_t)(TFTP_TIMEOUT_MS / 1000u), (suseconds_t)((TFTP_TIMEOUT_MS % 1000u) * 1000u)};
        struct sockaddr_in src;
        socklen_t src_len = (socklen_t)sizeof(src);
        uint8_t buf[TFTP_PACKET_BYTES];
        int rc;
        ssize_t n;

        FD_ZERO(&fds);
        FD_SET(sock, &fds);
        rc = select(sock + 1, &fds, NULL, NULL, &tv);
        if (rc <= 0) {
            return false;
        }
        n = recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&src, &src_len);
        if (n < TFTP_MIN_ACK_BYTES || !is_same_peer(&src, peer)) {
            continue;
        }
        if (buf[TFTP_OP_HIGH_OFFSET] != 0 || buf[TFTP_OP_LOW_OFFSET] != TFTP_OP_ACK) {
            continue;
        }
        if (((uint16_t)buf[TFTP_BLOCK_HIGH_OFFSET] << 8u |
             (uint16_t)buf[TFTP_BLOCK_LOW_OFFSET]) == expected_block) {
            return true;
        }
    }
}

static bool send_block_with_retries(int sock, const struct sockaddr_in *peer, const uint8_t *file_data,
                                    size_t file_size, size_t offset, uint16_t block) {
    size_t left;
    size_t chunk;
    uint8_t packet[TFTP_HEADER_BYTES + TFTP_BLOCK_SIZE];

    left = (offset < file_size) ? (file_size - offset) : 0u;
    if (left > TFTP_BLOCK_SIZE) {
        chunk = TFTP_BLOCK_SIZE;
    } else {
        chunk = left;
    }

    packet[TFTP_OP_HIGH_OFFSET] = 0;
    packet[TFTP_OP_LOW_OFFSET] = TFTP_OP_DATA;
    packet[TFTP_BLOCK_HIGH_OFFSET] = (uint8_t)(block >> 8u);
    packet[TFTP_BLOCK_LOW_OFFSET] = (uint8_t)block;
    if (chunk > 0u) {
        memcpy(&packet[TFTP_PAYLOAD_OFFSET], file_data + offset, chunk);
    }

    for (uint32_t attempt = 0u; attempt < TFTP_MAX_RETRIES; attempt++) {
        ssize_t sent = sendto(sock, packet, TFTP_HEADER_BYTES + chunk, 0,
                              (const struct sockaddr *)peer, (socklen_t)sizeof(*peer));
        if (sent < 0) {
            return false;
        }
        if (wait_for_ack(sock, peer, block)) {
            log_line("TFTP DATA block %u", block);
            return true;
        }
    }
    return false;
}

static bool transfer_boot_file(const char *path, int tfd, const struct sockaddr_in *peer) {
    FILE *fp = NULL;
    uint8_t *file_data = NULL;
    long size_long;
    size_t file_size = 0u;
    size_t offset = 0u;
    uint16_t block = 1u;
    bool ok = false;
    bool sent_zero = false;
    bool done = false;

    fp = fopen(path, "rb");
    if (fp == NULL) {
        log_line("unable to open %s", path);
        return false;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return false;
    }
    size_long = ftell(fp);
    if (size_long < 0 || size_long > (long)NETBOOT_FILE_SIZE_MAX) {
        fclose(fp);
        return false;
    }
    file_size = (size_t)size_long;
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return false;
    }

    if (file_size != 0u) {
        file_data = (uint8_t *)malloc(file_size);
        if (file_data == NULL) {
            fclose(fp);
            return false;
        }
        if (fread(file_data, 1, file_size, fp) != file_size) {
            free(file_data);
            fclose(fp);
            return false;
        }
    }
    fclose(fp);

    while (!done) {
        size_t left = (offset < file_size) ? (file_size - offset) : 0u;
        size_t chunk = (left > TFTP_BLOCK_SIZE) ? TFTP_BLOCK_SIZE : left;

        if (offset >= file_size) {
            if (sent_zero || (file_size % TFTP_BLOCK_SIZE) != 0u) {
                ok = true;
                break;
            }
            sent_zero = true;
            if (!send_block_with_retries(tfd, peer, file_data, file_size, offset, block)) {
                ok = false;
                break;
            }
            ok = true;
            block++;
            break;
        }
        if (!send_block_with_retries(tfd, peer, file_data, file_size, offset, block)) {
            ok = false;
            break;
        }
        offset += chunk;
        block++;
    }

    free(file_data);
    return ok;
}

static bool is_boot_filename(const char *filename) {
    if (filename == NULL) {
        return false;
    }
    if (strcmp(filename, BOOT_FILE) == 0) {
        return true;
    }
    if (strcmp(filename, BOOT_FILE_BASENAME) == 0) {
        return true;
    }
    if (strcmp(filename, "/BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcmp(filename, "/EFI/BOOT/BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcmp(filename, "\\EFI\\BOOT\\BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcasecmp(filename, "efi/boot/bootx64.efi") == 0) {
        return true;
    }
    if (strcasecmp(filename, "bootx64.efi") == 0) {
        return true;
    }
    return false;
}

static size_t tftp_add_oack_option(uint8_t *out, size_t out_cap, size_t off, const char *key, const char *value) {
    size_t key_len = strlen(key) + 1u;
    size_t value_len = strlen(value) + 1u;

    if (off + key_len + value_len > out_cap) {
        return 0u;
    }
    memcpy(out + off, key, key_len);
    off += key_len;
    memcpy(out + off, value, value_len);
    return off + value_len;
}

static size_t tftp_make_oack(uint8_t *out, size_t out_cap, bool want_tsize,
                             bool want_blksize, bool want_windowsize, size_t file_size) {
    size_t off = 0u;
    uint16_t op = htons(TFTP_OP_OACK);

    if (out_cap < TFTP_HEADER_BYTES) {
        return 0u;
    }
    memcpy(out + off, &op, TFTP_HEADER_BYTES);
    off += TFTP_HEADER_BYTES;

    if (want_tsize) {
        char n[32];
        snprintf(n, sizeof(n), "%lu", (unsigned long)file_size);
        off = tftp_add_oack_option(out, out_cap, off, "tsize", n);
        if (off == 0u) {
            return 0u;
        }
    }
    if (want_blksize) {
        off = tftp_add_oack_option(out, out_cap, off, "blksize", "512");
        if (off == 0u) {
            return 0u;
        }
    }
    if (want_windowsize) {
        off = tftp_add_oack_option(out, out_cap, off, "windowsize", "1");
        if (off == 0u) {
            return 0u;
        }
    }
    return off;
}

static bool tftp_rrq_has_option(const char *opt_start, const uint8_t *end, const char *name) {
    const char *p = opt_start;
    while ((const uint8_t *)p < end && *p != '\0') {
        const char *key = p;
        size_t key_len = strlen(key);
        const char *value;
        size_t value_len;

        p += key_len + 1u;
        if ((const uint8_t *)p >= end) {
            break;
        }
        value = p;
        value_len = strlen(value);
        p += value_len + 1u;
        if (strcasecmp(key, name) == 0) {
            return true;
        }
    }
    return false;
}

static void handle_tftp(int sock, const uint8_t *pkt, size_t len, const struct sockaddr_in *src,
                        const char *efi_path) {
    uint16_t opcode;
    const uint8_t *cursor;
    const uint8_t *end;
    const uint8_t *name_end;
    const uint8_t *mode_end;
    char filename[TFTP_FILENAME_BUFFER_SIZE];
    char mode[16];
    size_t name_len;
    size_t mode_len;
    struct stat st;
    size_t file_size;
    int tfd = -1;
    uint8_t oack[TFTP_OACK_BUFFER_SIZE];
    bool has_options;
    bool want_tsize;
    bool want_blksize;
    bool want_windowsize;
    size_t oack_len;
    const uint8_t *opt_start;
    if (len < TFTP_HEADER_BYTES) {
        return;
    }

    opcode = (uint16_t)((uint16_t)pkt[TFTP_OP_HIGH_OFFSET] << 8u |
                        (uint16_t)pkt[TFTP_OP_LOW_OFFSET]);
    if (opcode != TFTP_OP_RRQ) {
        return;
    }

    cursor = &pkt[TFTP_ERROR_CODE_OFFSET];
    end = pkt + len;
    name_end = memchr(cursor, 0, (size_t)(end - cursor));
    if (name_end == NULL) {
        return;
    }
    name_len = (size_t)(name_end - cursor);
    if (name_len >= sizeof(filename)) {
        return;
    }
    memcpy(filename, cursor, name_len);
    filename[name_len] = '\0';

    cursor = name_end + 1u;
    if (cursor >= end) {
        return;
    }
    mode_end = memchr(cursor, 0, (size_t)(end - cursor));
    if (mode_end == NULL) {
        return;
    }
    mode_len = (size_t)(mode_end - cursor);
    if (mode_len >= sizeof(mode)) {
        return;
    }
    memcpy(mode, cursor, mode_len);
    mode[mode_len] = '\0';

    if (strcasecmp(mode, "octet") != 0) {
        send_tftp_error(sock, src, 0u, "Unsupported mode");
        return;
    }
    if (!is_boot_filename(filename)) {
        send_tftp_error(sock, src, 1u, "File not found");
        return;
    }
    if (stat(efi_path, &st) != 0) {
        log_line("unable to stat %s", efi_path);
        return;
    }
    if (st.st_size < 0 || st.st_size > (long)NETBOOT_FILE_SIZE_MAX) {
        log_line("invalid EFI size");
        return;
    }
    file_size = (size_t)st.st_size;

    has_options = (mode_end + 1u) < end;
    want_tsize = false;
    want_blksize = false;
    want_windowsize = false;
    if (has_options) {
        opt_start = mode_end + 1u;
        want_tsize = tftp_rrq_has_option((const char *)opt_start, end, "tsize");
        want_blksize = tftp_rrq_has_option((const char *)opt_start, end, "blksize");
        want_windowsize = tftp_rrq_has_option((const char *)opt_start, end, "windowsize");
    }
    tfd = open_dgram_socket(0u, false);
    if (tfd < 0) {
        log_line("unable to allocate TFTP transfer socket");
        return;
    }
    if (has_options) {
        oack_len = tftp_make_oack(oack, sizeof(oack), want_tsize, want_blksize, want_windowsize, file_size);
        if (oack_len == 0u ||
            sendto(tfd, oack, oack_len, 0, (const struct sockaddr *)src, (socklen_t)sizeof(*src)) !=
                (ssize_t)oack_len) {
            close(tfd);
            return;
        }
        if (!wait_for_ack(tfd, src, 0u)) {
            close(tfd);
            return;
        }
    }

    log_line("TFTP RRQ %s", filename);
    if (transfer_boot_file(efi_path, tfd, src)) {
        log_line("TFTP complete");
    } else {
        log_line("TFTP failed");
    }
    close(tfd);
}

#endif
