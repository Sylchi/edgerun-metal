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
#include <string.h>
#include <strings.h>
#include <arpa/inet.h>
#include <unistd.h>

#include "protocol.h"

static void log_line(const char *fmt, ...);

typedef struct {
    const char *iface;
    const char *efi_path;
    const char *client_ip;
    const char *mgmt_ip;
    uint16_t http_port;
    bool explicit_http_port;
    uint8_t mode;
    bool setup_interface;
    uint8_t allow_mac[NETBOOT_MAC_BYTES];
    bool has_allow_mac;
    uint8_t mgmt_mac[NETBOOT_MAC_BYTES];
    bool has_mgmt_mac;
    bool mgmt_dhcp;
    bool force_http_for_pxe;
} NetbootConfig;

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

static bool parse_bool_value(const char *value) {
    if (value == NULL) {
        return true;
    }
    if (strcasecmp(value, "1") == 0) {
        return true;
    }
    if (strcasecmp(value, "true") == 0 || strcasecmp(value, "yes") == 0 || strcasecmp(value, "on") == 0) {
        return true;
    }
    return false;
}

static bool parse_mode_arg(const char *value, uint8_t *mode) {
    if (strcasecmp(value, "auto") == 0) {
        *mode = MODE_AUTO;
        return true;
    }
    if (strcasecmp(value, "http") == 0) {
        *mode = MODE_HTTP;
        return true;
    }
    if (strcasecmp(value, "tftp") == 0) {
        *mode = MODE_TFTP;
        return true;
    }
    return false;
}

static bool parse_mac(const char *s, uint8_t *out) {
    unsigned int b0, b1, b2, b3, b4, b5;
    int consumed = -1;

    if (s == NULL || *s == '\0') {
        return false;
    }
    if (sscanf(s, "%2x:%2x:%2x:%2x:%2x:%2x%n", &b0, &b1, &b2, &b3, &b4, &b5, &consumed) != NETBOOT_MAC_BYTES) {
        return false;
    }
    if (s[consumed] != '\0') {
        return false;
    }
    out[NETBOOT_BYTE0] = (uint8_t)b0;
    out[NETBOOT_BYTE1] = (uint8_t)b1;
    out[NETBOOT_BYTE2] = (uint8_t)b2;
    out[NETBOOT_BYTE3] = (uint8_t)b3;
    out[NETBOOT_BYTE4] = (uint8_t)b4;
    out[NETBOOT_BYTE5] = (uint8_t)b5;
    return true;
}

static bool parse_tcp_port_arg(const char *value, uint16_t *out_port) {
    char *end = NULL;
    long val;

    if (value == NULL || out_port == NULL) {
        return false;
    }
    val = strtol(value, &end, NETBOOT_STRTOL_BASE_DECIMAL);
    if (end == NULL || *end != '\0' || val <= 0 || val > NETBOOT_TCP_PORT_MAX) {
        return false;
    }
    *out_port = (uint16_t)val;
    return true;
}

static bool parse_ipv4_arg(const char *value) {
    struct in_addr tmp;

    return value != NULL && inet_pton(AF_INET, value, &tmp) == 1;
}

static bool parse_optional_mac_arg(const char *value, uint8_t *mac, bool *has_mac) {
    if (value == NULL || mac == NULL || has_mac == NULL) {
        return false;
    }
    if (*value == '\0') {
        *has_mac = false;
        return true;
    }
    if (!parse_mac(value, mac)) {
        return false;
    }
    *has_mac = true;
    return true;
}

static void netboot_config_init(NetbootConfig *config) {
    if (config == NULL) {
        return;
    }
    config->iface = NULL;
    config->efi_path = NULL;
    config->client_ip = CLIENT_IP_DEFAULT;
    config->mgmt_ip = MGMT_IP_DEFAULT;
    config->http_port = HTTP_PORT_DEFAULT;
    config->explicit_http_port = false;
    config->mode = MODE_AUTO;
    config->setup_interface = false;
    config->has_allow_mac = false;
    config->has_mgmt_mac = false;
    config->mgmt_dhcp = false;
    config->force_http_for_pxe = false;
}

static bool netboot_require_next_arg(int argc, int index, const char *name, const char *prog) {
    if (index + 1 < argc) {
        return true;
    }
    log_line("%s requires an argument", name);
    usage(prog);
    return false;
}

static int netboot_parse_path_arg(int argc, char **argv, int *index, const char *prog, NetbootConfig *config) {
    if (strcmp(argv[*index], "--iface") == 0) {
        if (!netboot_require_next_arg(argc, *index, "--iface", prog)) {
            return -1;
        }
        *index += 1;
        config->iface = argv[*index];
        return 1;
    }
    if (strcmp(argv[*index], "--efi") == 0) {
        if (!netboot_require_next_arg(argc, *index, "--efi", prog)) {
            return -1;
        }
        *index += 1;
        config->efi_path = argv[*index];
        return 1;
    }
    if (strcmp(argv[*index], "--http-port") == 0) {
        if (!netboot_require_next_arg(argc, *index, "--http-port", prog)) {
            return -1;
        }
        *index += 1;
        if (!parse_tcp_port_arg(argv[*index], &config->http_port)) {
            log_line("invalid --http-port value");
            usage(prog);
            return -1;
        }
        config->explicit_http_port = true;
        return 1;
    }
    return 0;
}

static int netboot_parse_mode_arg(int argc, char **argv, int *index, const char *prog, NetbootConfig *config) {
    uint8_t parsed;

    if (strcmp(argv[*index], "--http") == 0) {
        config->mode = MODE_HTTP;
        return 1;
    }
    if (strcmp(argv[*index], "--tftp") == 0) {
        config->mode = MODE_TFTP;
        return 1;
    }
    if (strcmp(argv[*index], "--auto") == 0) {
        config->mode = MODE_AUTO;
        return 1;
    }
    if (strcmp(argv[*index], "--mode") != 0) {
        return 0;
    }
    if (!netboot_require_next_arg(argc, *index, "--mode", prog)) {
        return -1;
    }
    *index += 1;
    if (!parse_mode_arg(argv[*index], &parsed)) {
        log_line("--mode expects auto|http|tftp");
        usage(prog);
        return -1;
    }
    config->mode = parsed;
    return 1;
}

static int netboot_parse_filter_arg(int argc, char **argv, int *index, const char *prog, NetbootConfig *config) {
    if (strcmp(argv[*index], "--allow-mac") == 0) {
        if (!netboot_require_next_arg(argc, *index, "--allow-mac", prog)) {
            return -1;
        }
        *index += 1;
        if (!parse_optional_mac_arg(argv[*index], config->allow_mac, &config->has_allow_mac)) {
            log_line("invalid --allow-mac value");
            usage(prog);
            return -1;
        }
        return 1;
    }
    if (strcmp(argv[*index], "--mgmt-mac") == 0) {
        if (!netboot_require_next_arg(argc, *index, "--mgmt-mac", prog)) {
            return -1;
        }
        *index += 1;
        if (!parse_optional_mac_arg(argv[*index], config->mgmt_mac, &config->has_mgmt_mac)) {
            log_line("invalid --mgmt-mac value");
            usage(prog);
            return -1;
        }
        return 1;
    }
    return 0;
}

static int netboot_parse_ip_arg(int argc, char **argv, int *index, const char *prog, NetbootConfig *config) {
    const bool is_client_ip = strcmp(argv[*index], "--client-ip") == 0;
    const bool is_mgmt_ip = strcmp(argv[*index], "--mgmt-ip") == 0;
    const char *error_text;
    const char **target;

    if (!is_client_ip && !is_mgmt_ip) {
        return 0;
    }
    if (!netboot_require_next_arg(argc, *index, argv[*index], prog)) {
        return -1;
    }
    error_text = is_client_ip ? "invalid --client-ip value" : "invalid --mgmt-ip value";
    target = is_client_ip ? &config->client_ip : &config->mgmt_ip;
    *index += 1;
    *target = argv[*index];
    if (!parse_ipv4_arg(*target)) {
        log_line("%s", error_text);
        usage(prog);
        return -1;
    }
    return 1;
}

static bool netboot_parse_flag_arg(char **argv, int index, NetbootConfig *config) {
    if (strcmp(argv[index], "--setup-iface") == 0) {
        config->setup_interface = true;
        return true;
    }
    if (strcmp(argv[index], "--mgmt-dhcp") == 0) {
        config->mgmt_dhcp = true;
        return true;
    }
    if (strcmp(argv[index], "--force-http-for-pxe") == 0) {
        config->force_http_for_pxe = true;
        return true;
    }
    return false;
}

static bool netboot_parse_bool_eq_arg(const char *arg, NetbootConfig *config) {
    if (strncmp(arg, NETBOOT_OPT_MGMT_DHCP_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_DHCP_EQ)) == 0) {
        config->mgmt_dhcp = parse_bool_value(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_DHCP_EQ));
        return true;
    }
    if (strncmp(arg, NETBOOT_OPT_FORCE_HTTP_FOR_PXE_EQ,
                NETBOOT_LITERAL_LEN(NETBOOT_OPT_FORCE_HTTP_FOR_PXE_EQ)) == 0) {
        config->force_http_for_pxe = parse_bool_value(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_FORCE_HTTP_FOR_PXE_EQ));
        return true;
    }
    return false;
}

static int netboot_parse_path_eq_arg(const char *arg, const char *prog, NetbootConfig *config) {
    if (strncmp(arg, NETBOOT_OPT_IFACE_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_IFACE_EQ)) == 0) {
        config->iface = arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_IFACE_EQ);
        return 1;
    }
    if (strncmp(arg, NETBOOT_OPT_EFI_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_EFI_EQ)) == 0) {
        config->efi_path = arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_EFI_EQ);
        return 1;
    }
    if (strncmp(arg, NETBOOT_OPT_HTTP_PORT_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_HTTP_PORT_EQ)) == 0) {
        if (!parse_tcp_port_arg(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_HTTP_PORT_EQ), &config->http_port)) {
            log_line("invalid --http-port value");
            usage(prog);
            return -1;
        }
        config->explicit_http_port = true;
        return 1;
    }
    return 0;
}

static int netboot_parse_filter_eq_arg(const char *arg, const char *prog, NetbootConfig *config) {
    if (strncmp(arg, NETBOOT_OPT_ALLOW_MAC_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_ALLOW_MAC_EQ)) == 0) {
        if (!parse_optional_mac_arg(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_ALLOW_MAC_EQ),
                                    config->allow_mac, &config->has_allow_mac)) {
            log_line("invalid --allow-mac value");
            usage(prog);
            return -1;
        }
        return 1;
    }
    if (strncmp(arg, NETBOOT_OPT_MGMT_MAC_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_MAC_EQ)) == 0) {
        if (!parse_optional_mac_arg(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_MAC_EQ),
                                    config->mgmt_mac, &config->has_mgmt_mac)) {
            log_line("invalid --mgmt-mac value");
            usage(prog);
            return -1;
        }
        return 1;
    }
    return 0;
}

static int netboot_parse_ip_eq_arg(const char *arg, const char *prog, NetbootConfig *config) {
    const char *error_text;
    const char **target;
    const char *value;

    if (strncmp(arg, NETBOOT_OPT_CLIENT_IP_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_CLIENT_IP_EQ)) == 0) {
        value = arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_CLIENT_IP_EQ);
        target = &config->client_ip;
        error_text = "invalid --client-ip value";
    } else if (strncmp(arg, NETBOOT_OPT_MGMT_IP_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_IP_EQ)) == 0) {
        value = arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_MGMT_IP_EQ);
        target = &config->mgmt_ip;
        error_text = "invalid --mgmt-ip value";
    } else {
        return 0;
    }
    *target = value;
    if (!parse_ipv4_arg(value)) {
        log_line("%s", error_text);
        usage(prog);
        return -1;
    }
    return 1;
}

static int netboot_parse_mode_eq_arg(const char *arg, const char *prog, NetbootConfig *config) {
    uint8_t parsed;

    if (strncmp(arg, NETBOOT_OPT_MODE_EQ, NETBOOT_LITERAL_LEN(NETBOOT_OPT_MODE_EQ)) != 0) {
        return 0;
    }
    if (!parse_mode_arg(arg + NETBOOT_LITERAL_LEN(NETBOOT_OPT_MODE_EQ), &parsed)) {
        log_line("--mode expects auto|http|tftp");
        usage(prog);
        return -1;
    }
    config->mode = parsed;
    return 1;
}

static int netboot_validate_config(const NetbootConfig *config, const char *prog) {
    if (config->iface == NULL) {
        log_line("missing --iface");
        usage(prog);
        return 1;
    }
    if (config->efi_path == NULL) {
        log_line("missing --efi");
        usage(prog);
        return 1;
    }
    return 0;
}

static int netboot_parse_args(int argc, char **argv, const char *prog, NetbootConfig *config) {
    int parse_result;
    int i;

    if (config == NULL) {
        return 1;
    }
    netboot_config_init(config);
    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            usage(prog);
            return 2;
        }
        parse_result = netboot_parse_path_arg(argc, argv, &i, prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_mode_arg(argc, argv, &i, prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_filter_arg(argc, argv, &i, prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_ip_arg(argc, argv, &i, prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        if (netboot_parse_flag_arg(argv, i, config) || netboot_parse_bool_eq_arg(argv[i], config)) {
            continue;
        }
        parse_result = netboot_parse_path_eq_arg(argv[i], prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_filter_eq_arg(argv[i], prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_ip_eq_arg(argv[i], prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        parse_result = netboot_parse_mode_eq_arg(argv[i], prog, config);
        if (parse_result < 0) {
            return 1;
        }
        if (parse_result > 0) {
            continue;
        }
        log_line("unknown option: %s", argv[i]);
        usage(prog);
        return 1;
    }
    return netboot_validate_config(config, prog);
}

#endif
