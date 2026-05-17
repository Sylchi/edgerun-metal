#include "er_netlog.h"
#include "er_mem.h"

/*
 * Purpose: use UEFI UDP4 service binding as an optional best-effort log sink.
 * Intention: every failure disables netlog and leaves console/serial boot output intact.
 */

#define ER_NETLOG_PORT 9000u
#define ER_NETLOG_MAX_DATAGRAM 1200u
#define ER_NETLOG_BEST_EFFORT_POLLS 1u
#define ER_NETLOG_DEFAULT_TTL 64u
#define ER_NETLOG_TX_FRAGMENT_COUNT 1u
#define ER_NETLOG_TX_FRAGMENT_INDEX 0u

enum {
  ER_NETLOG_IPV4_A_INDEX = 0u,
  ER_NETLOG_IPV4_B_INDEX = 1u,
  ER_NETLOG_IPV4_C_INDEX = 2u,
  ER_NETLOG_IPV4_D_INDEX = 3u,
  ER_NETLOG_DEFAULT_IP_A = 10u,
  ER_NETLOG_DEFAULT_IP_B = 42u,
  ER_NETLOG_DEFAULT_IP_C = 0u,
  ER_NETLOG_DEFAULT_IP_D = 1u
};

static EFI_GUID g_udp4_service_binding_guid = {
  0x83f01464u, 0x99bdu, 0x45e5u, {0xb3u, 0x83u, 0xafu, 0x63u, 0x05u, 0xd8u, 0xe9u, 0xe6u} //@optimizer-ignore UEFI UDP4 service binding GUID
};

static EFI_GUID g_udp4_protocol_guid = {
  0x3ad9df29u, 0x4501u, 0x478du, {0xb1u, 0xf8u, 0x7fu, 0x7fu, 0xe7u, 0x0eu, 0x50u, 0xf3u} //@optimizer-ignore UEFI UDP4 protocol GUID
};

static EFI_BOOT_SERVICES* g_bs;
static EFI_SERVICE_BINDING_PROTOCOL* g_udp4_binding;
static EFI_HANDLE g_udp4_child;
static EFI_UDP4_PROTOCOL* g_udp4;
static EFI_EVENT g_tx_event;
static UINT8 g_ready;
static UINT8 g_tx_busy;
static UINT8 g_tx_buffer[ER_NETLOG_MAX_DATAGRAM];
static UINT8 g_text_buffer[ER_NETLOG_MAX_DATAGRAM];
static UINTN g_text_len;
static EFI_UDP4_SESSION_DATA g_tx_session;
static EFI_UDP4_TRANSMIT_DATA g_tx_data;
static EFI_UDP4_COMPLETION_TOKEN g_tx_token;

static void er_netlog_disable(void) {
  if (g_bs != 0 && g_tx_event != 0 && g_bs->CloseEvent != 0) {
    g_bs->CloseEvent(g_tx_event);
  }
  if (g_udp4_binding != 0 && g_udp4_child != 0 && g_udp4_binding->DestroyChild != 0) {
    g_udp4_binding->DestroyChild(g_udp4_binding, g_udp4_child);
  }

  g_ready = 0;
  g_tx_busy = 0;
  g_text_len = 0;
  g_tx_event = 0;
  g_udp4_child = 0;
  g_udp4_binding = 0;
  g_udp4 = 0;
}

static void EFIAPI er_netlog_tx_done(EFI_EVENT Event, void* Context) {
  (void)Event;
  (void)Context;
  g_tx_busy = 0;
}

static UINTN er_netlog_len(const char* s) {
  UINTN n = 0;

  if (s == 0) {
    return 0;
  }

  while (s[n] != 0) {
    ++n;
  }

  return n;
}

static void er_netlog_clear_text(void) {
  g_text_len = 0;
}

static UINT8 er_netlog_wait_idle(UINT32 poll_limit) {
  UINT32 i;

  if (g_tx_busy == 0u) {
    return 1;
  }
  if (g_udp4 == 0 || g_udp4->Poll == 0) {
    return 0;
  }

  for (i = 0; i < poll_limit && g_tx_busy != 0u; ++i) {
    g_udp4->Poll(g_udp4);
  }

  return (UINT8)(g_tx_busy == 0u);
}

static void er_netlog_zero_config(EFI_UDP4_CONFIG_DATA* config) {
  config->AcceptBroadcast = 0;
  config->AcceptPromiscuous = 0;
  config->AcceptAnyPort = 1;
  config->AllowDuplicatePort = 1;
  config->TypeOfService = 0;
  config->TimeToLive = ER_NETLOG_DEFAULT_TTL;
  config->DoNotFragment = 0;
  config->ReceiveTimeout = 0;
  config->TransmitTimeout = 0;
  config->UseDefaultAddress = 1;
  config->StationAddress.Addr[ER_NETLOG_IPV4_A_INDEX] = 0;
  config->StationAddress.Addr[ER_NETLOG_IPV4_B_INDEX] = 0;
  config->StationAddress.Addr[ER_NETLOG_IPV4_C_INDEX] = 0;
  config->StationAddress.Addr[ER_NETLOG_IPV4_D_INDEX] = 0;
  config->SubnetMask.Addr[ER_NETLOG_IPV4_A_INDEX] = 0;
  config->SubnetMask.Addr[ER_NETLOG_IPV4_B_INDEX] = 0;
  config->SubnetMask.Addr[ER_NETLOG_IPV4_C_INDEX] = 0;
  config->SubnetMask.Addr[ER_NETLOG_IPV4_D_INDEX] = 0;
  config->StationPort = 0;
  config->RemoteAddress.Addr[ER_NETLOG_IPV4_A_INDEX] = ER_NETLOG_DEFAULT_IP_A;
  config->RemoteAddress.Addr[ER_NETLOG_IPV4_B_INDEX] = ER_NETLOG_DEFAULT_IP_B;
  config->RemoteAddress.Addr[ER_NETLOG_IPV4_C_INDEX] = ER_NETLOG_DEFAULT_IP_C;
  config->RemoteAddress.Addr[ER_NETLOG_IPV4_D_INDEX] = ER_NETLOG_DEFAULT_IP_D;
  config->RemotePort = ER_NETLOG_PORT;
}

void er_netlog_init(EFI_SYSTEM_TABLE* st) {
  EFI_HANDLE* handles = 0;
  UINTN handle_count = 0;
  UINTN i;
  EFI_HANDLE child = 0;
  EFI_UDP4_CONFIG_DATA config;

  g_ready = 0;
  g_tx_busy = 0;
  er_netlog_clear_text();
  g_udp4 = 0;
  g_udp4_binding = 0;
  g_udp4_child = 0;
  g_tx_event = 0;
  g_bs = 0;

  if (st == 0 || st->BootServices == 0) {
    return;
  }

  g_bs = st->BootServices;
  if (g_bs->LocateHandleBuffer == 0 || g_bs->HandleProtocol == 0 || g_bs->FreePool == 0 ||
      g_bs->CreateEvent == 0 || g_bs->CloseEvent == 0) {
    return;
  }

  if (g_bs->LocateHandleBuffer(ByProtocol, &g_udp4_service_binding_guid, 0, &handle_count, &handles) != EFI_SUCCESS) {
    return;
  }

  for (i = 0; i < handle_count && g_udp4 == 0; ++i) {
    EFI_SERVICE_BINDING_PROTOCOL* binding = 0;

    if (g_bs->HandleProtocol(handles[i], &g_udp4_service_binding_guid, (void**)&binding) != EFI_SUCCESS || binding == 0 ||
        binding->CreateChild == 0 || binding->DestroyChild == 0) {
      continue;
    }

    child = 0;
    if (binding->CreateChild(binding, &child) != EFI_SUCCESS || child == 0) {
      continue;
    }

    if (g_bs->HandleProtocol(child, &g_udp4_protocol_guid, (void**)&g_udp4) != EFI_SUCCESS || g_udp4 == 0) {
      g_udp4 = 0;
      binding->DestroyChild(binding, child);
      continue;
    }

    g_udp4_binding = binding;
    g_udp4_child = child;
  }

  g_bs->FreePool(handles);
  if (g_udp4 == 0 || g_udp4->Configure == 0 || g_udp4->Transmit == 0) {
    er_netlog_disable();
    return;
  }

  er_netlog_zero_config(&config);
  if (g_udp4->Configure(g_udp4, &config) != EFI_SUCCESS) {
    er_netlog_disable();
    return;
  }

  if (g_bs->CreateEvent(EVT_NOTIFY_SIGNAL, TPL_CALLBACK, (void*)er_netlog_tx_done, 0, &g_tx_event) != EFI_SUCCESS ||
      g_tx_event == 0) {
    er_netlog_disable();
    return;
  }

  g_tx_session.SourceAddress.Addr[ER_NETLOG_IPV4_A_INDEX] = 0;
  g_tx_session.SourceAddress.Addr[ER_NETLOG_IPV4_B_INDEX] = 0;
  g_tx_session.SourceAddress.Addr[ER_NETLOG_IPV4_C_INDEX] = 0;
  g_tx_session.SourceAddress.Addr[ER_NETLOG_IPV4_D_INDEX] = 0;
  g_tx_session.SourcePort = 0;
  g_tx_session.DestinationAddress.Addr[ER_NETLOG_IPV4_A_INDEX] = ER_NETLOG_DEFAULT_IP_A;
  g_tx_session.DestinationAddress.Addr[ER_NETLOG_IPV4_B_INDEX] = ER_NETLOG_DEFAULT_IP_B;
  g_tx_session.DestinationAddress.Addr[ER_NETLOG_IPV4_C_INDEX] = ER_NETLOG_DEFAULT_IP_C;
  g_tx_session.DestinationAddress.Addr[ER_NETLOG_IPV4_D_INDEX] = ER_NETLOG_DEFAULT_IP_D;
  g_tx_session.DestinationPort = ER_NETLOG_PORT;

  g_tx_data.UdpSessionData = &g_tx_session;
  g_tx_data.GatewayAddress = 0;
  g_tx_data.FragmentCount = ER_NETLOG_TX_FRAGMENT_COUNT;
  g_tx_data.FragmentTable[ER_NETLOG_TX_FRAGMENT_INDEX].FragmentBuffer = g_tx_buffer;
  g_tx_token.Event = g_tx_event;
  g_tx_token.Status = EFI_NOT_READY;
  g_tx_token.Packet.TxData = &g_tx_data;
  g_ready = 1;
}

UINT8 er_netlog_ready(void) {
  return g_ready;
}

void er_netlog_write(const char* s) {
  er_netlog_write_bytes((const UINT8*)s, er_netlog_len(s));
}

void er_netlog_flush_text(void) {
  if (g_text_len == 0u) {
    return;
  }

  (void)er_netlog_write_bytes_wait(g_text_buffer, g_text_len, ER_NETLOG_BEST_EFFORT_POLLS);
  er_netlog_clear_text();
}

void er_netlog_write_text(const char* s) {
  UINTN i;

  if (s == 0) {
    return;
  }

  for (i = 0; s[i] != 0; ++i) {
    if (g_text_len >= ER_NETLOG_MAX_DATAGRAM) {
      er_netlog_flush_text();
    }
    g_text_buffer[g_text_len] = (UINT8)s[i];
    ++g_text_len;
    if (s[i] == '\n') {
      er_netlog_flush_text();
    }
  }
}

void er_netlog_write_bytes(const UINT8* data, UINTN len) {
  (void)er_netlog_write_bytes_wait(data, len, ER_NETLOG_BEST_EFFORT_POLLS);
}

UINT8 er_netlog_write_bytes_wait(const UINT8* data, UINTN len, UINT32 poll_limit) {
  UINTN remaining = len;
  UINTN offset = 0;

  if (g_ready == 0 || g_udp4 == 0 || data == 0) {
    return 0;
  }
  if (len == 0u) {
    return 1;
  }

  while (remaining > 0) {
    UINTN chunk = remaining;

    if (er_netlog_wait_idle(poll_limit) == 0u) {
      return 0;
    }

    if (chunk > ER_NETLOG_MAX_DATAGRAM) {
      chunk = ER_NETLOG_MAX_DATAGRAM;
    }

    er_mem_copy(g_tx_buffer, data + offset, chunk);
    g_tx_data.DataLength = (UINT32)chunk;
    g_tx_data.FragmentTable[0].FragmentLength = (UINT32)chunk;
    g_tx_token.Status = EFI_NOT_READY;

    if (g_udp4->Transmit(g_udp4, &g_tx_token) != EFI_SUCCESS) {
      er_netlog_disable();
      return 0;
    }

    g_tx_busy = 1;
    offset += chunk;
    remaining -= chunk;
  }

  return er_netlog_wait_idle(poll_limit);
}
