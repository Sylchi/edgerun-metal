#ifndef EDGERUN_NETBOOT_HOST_UTIL_H
#define EDGERUN_NETBOOT_HOST_UTIL_H

/*
 * Purpose: keep host-side command and path helpers out of the netboot server flow.
 * Intention: leave main.c focused on DHCP/TFTP/HTTP orchestration.
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "protocol.h"

static void log_line(const char *fmt, ...);

static void usage(const char *prog) {
    log_line("Usage:");
    log_line("  %s --iface <name> --efi <path-to-BOOTX64.EFI> [--setup-iface] [--http] [--tftp] [--auto] [--mode <auto|http|tftp>]", prog);
    log_line("  [--http-port <port>] [--allow-mac <aa:bb:cc:dd:ee:ff>] [--client-ip <10.42.0.2>] [--force-http-for-pxe]");
    log_line("  [--mgmt-dhcp] [--mgmt-mac <aa:bb:cc:dd:ee:ff>] [--mgmt-ip <10.42.0.10>]");
    log_line("  --help");
}

static bool make_absolute_path(const char *input, char *output, size_t output_size) {
    char cwd[NETBOOT_PATH_BUFFER_SIZE];
    if (input == NULL || output == NULL || output_size == 0u) {
        return false;
    }
    if (input[0] == '/') {
        (void)snprintf(output, output_size, "%s", input);
        return true;
    }
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        return false;
    }
    (void)snprintf(output, output_size, "%s/%s", cwd, input);
    return true;
}

static bool run_cmd(const char *fmt, const char *iface) {
    char cmd[NETBOOT_COMMAND_BUFFER_SIZE];
    int rc;

    (void)snprintf(cmd, sizeof(cmd), fmt, iface);
    rc = system(cmd);
    if (rc != 0) {
        log_line("command failed: %s", cmd);
        return false;
    }
    return true;
}

static bool setup_iface(const char *iface) {
    if (!run_cmd("ip link set %s down", iface)) {
        return false;
    }
    if (!run_cmd("ip addr flush dev %s", iface)) {
        return false;
    }
    if (!run_cmd("ip addr add 10.42.0.1/24 dev %s", iface)) {
        return false;
    }
    if (!run_cmd("ip link set %s up", iface)) {
        return false;
    }
    return true;
}

#endif
