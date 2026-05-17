#include "er_acpi.h"

/*
 * Purpose: parse the small ACPI discovery surface needed by the metal executor.
 * Intention: enumerate firmware table addresses while leaving interpretation to later layers.
 */

#define ER_ACPI_RSDP_V1_LEN 20u
#define ER_ACPI_RSDP_V2_MIN_LEN 36u
#define ER_ACPI_SDT_HEADER_LEN 36u
#define ER_ACPI_RSDP_SIG0 0x2052545020445352ull
#define ER_ACPI_MADT_HEADER_LEN 44u
#define ER_ACPI_MCFG_HEADER_LEN 44u
#define ER_ACPI_MCFG_ALLOC_LEN 16u
#define ER_ACPI_ECAM_BUS_STRIDE 0x100000ull
#define ER_ACPI_ECAM_DEVICE_STRIDE 0x8000ull
#define ER_ACPI_ECAM_FUNCTION_STRIDE 0x1000ull
#define ER_ACPI_HPET_LEN 56u
#define ER_ACPI_FADT_MIN_LEN 116u

static const EFI_GUID g_acpi_10_table_guid = {
  0xeb9d2d30u, 0x2d88u, 0x11d3u, {0x9au, 0x16u, 0x00u, 0x90u, 0x27u, 0x3fu, 0xc1u, 0x4du}
};

static const EFI_GUID g_acpi_20_table_guid = {
  0x8868e871u, 0xe4f1u, 0x11d3u, {0xbcu, 0x22u, 0x00u, 0x80u, 0xc7u, 0x3cu, 0x88u, 0x81u}
};

static void er_acpi_zero(UINT8* bytes, UINTN len) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0; i < len; ++i) {
    bytes[i] = 0;
  }
}

static UINT8 er_acpi_guid_equal(const EFI_GUID* a, const EFI_GUID* b) {
  UINTN i;

  if (a == 0 || b == 0 || a->Data1 != b->Data1 || a->Data2 != b->Data2 || a->Data3 != b->Data3) {
    return 0;
  }
  for (i = 0; i < 8u; ++i) {
    if (a->Data4[i] != b->Data4[i]) {
      return 0;
    }
  }
  return 1;
}

static UINT32 er_acpi_get_u32(const UINT8* bytes) {
  return (UINT32)((UINT32)bytes[0] | ((UINT32)bytes[1] << 8) |
                  ((UINT32)bytes[2] << 16) | ((UINT32)bytes[3] << 24));
}

static UINT16 er_acpi_get_u16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << 8));
}

static UINT64 er_acpi_get_u64(const UINT8* bytes) {
  return (UINT64)er_acpi_get_u32(bytes) | ((UINT64)er_acpi_get_u32(bytes + 4) << 32);
}

UINT32 er_acpi_signature(const char* s) {
  if (s == 0 || s[0] == 0 || s[1] == 0 || s[2] == 0 || s[3] == 0) {
    return 0;
  }
  return (UINT32)(UINT8)s[0] | ((UINT32)(UINT8)s[1] << 8) |
         ((UINT32)(UINT8)s[2] << 16) | ((UINT32)(UINT8)s[3] << 24);
}

UINT8 er_acpi_checksum_valid(const UINT8* bytes, UINTN len) {
  UINTN i;
  UINT8 sum = 0;

  if (bytes == 0 || len == 0u) {
    return 0;
  }
  for (i = 0; i < len; ++i) {
    sum = (UINT8)(sum + bytes[i]);
  }
  return (UINT8)(sum == 0u);
}

static UINT8 er_acpi_parse_rsdp(const UINT8* rsdp, ErAcpiRsdpInfo* out_info) {
  UINT32 length;

  if (rsdp == 0 || out_info == 0 || er_acpi_get_u64(rsdp) != ER_ACPI_RSDP_SIG0) {
    return 0;
  }

  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  out_info->found = 1;
  out_info->revision = rsdp[15];
  out_info->checksum_valid = er_acpi_checksum_valid(rsdp, ER_ACPI_RSDP_V1_LEN);
  out_info->rsdp_address = (UINT64)(UINTN)rsdp;
  out_info->rsdt_address = er_acpi_get_u32(rsdp + 16);

  if (out_info->revision >= 2u) {
    length = er_acpi_get_u32(rsdp + 20);
    if (length >= ER_ACPI_RSDP_V2_MIN_LEN) {
      out_info->xsdt_address = er_acpi_get_u64(rsdp + 24);
      out_info->xsdt_checksum_valid = er_acpi_checksum_valid(rsdp, (UINTN)length);
    }
  }
  return 1;
}

UINT8 er_acpi_find_rsdp(EFI_SYSTEM_TABLE* st, ErAcpiRsdpInfo* out_info) {
  UINTN i;
  UINT8 found_10 = 0;
  UINT8* rsdp_10 = 0;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));

  if (st == 0 || st->ConfigurationTable == 0 || st->NumberOfTableEntries == 0u) {
    return 0;
  }

  for (i = 0; i < st->NumberOfTableEntries; ++i) {
    EFI_CONFIGURATION_TABLE* entry = &st->ConfigurationTable[i];

    if (er_acpi_guid_equal(&entry->VendorGuid, &g_acpi_20_table_guid) != 0u) {
      return er_acpi_parse_rsdp((const UINT8*)entry->VendorTable, out_info);
    }
    if (er_acpi_guid_equal(&entry->VendorGuid, &g_acpi_10_table_guid) != 0u) {
      found_10 = 1;
      rsdp_10 = (UINT8*)entry->VendorTable;
    }
  }

  if (found_10 != 0u) {
    return er_acpi_parse_rsdp(rsdp_10, out_info);
  }
  return 0;
}

static UINT8 er_acpi_table_info(UINT64 address, ErAcpiTableInfo* out_info) {
  const UINT8* table = (const UINT8*)(UINTN)address;
  UINT32 length;

  if (table == 0 || out_info == 0) {
    return 0;
  }

  length = er_acpi_get_u32(table + 4);
  if (length < ER_ACPI_SDT_HEADER_LEN) {
    return 0;
  }

  out_info->signature = er_acpi_get_u32(table);
  out_info->length = length;
  out_info->revision = table[8];
  out_info->checksum_valid = er_acpi_checksum_valid(table, (UINTN)length);
  out_info->address = address;
  return 1;
}

UINT8 er_acpi_enumerate_tables(const ErAcpiRsdpInfo* rsdp, ErAcpiTableList* out_list) {
  const UINT8* root;
  UINT32 root_len;
  UINT32 entry_count;
  UINT32 i;
  UINT8 use_xsdt;

  if (out_list == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_list, (UINTN)sizeof(*out_list));

  if (rsdp == 0 || rsdp->found == 0u || rsdp->checksum_valid == 0u) {
    return 0;
  }

  use_xsdt = (UINT8)(rsdp->xsdt_address != 0u && rsdp->xsdt_checksum_valid != 0u);
  root = (const UINT8*)(UINTN)(use_xsdt != 0u ? rsdp->xsdt_address : (UINT64)rsdp->rsdt_address);
  if (root == 0) {
    return 0;
  }

  root_len = er_acpi_get_u32(root + 4);
  if (root_len < ER_ACPI_SDT_HEADER_LEN || er_acpi_checksum_valid(root, (UINTN)root_len) == 0u) {
    return 0;
  }

  out_list->found = 1;
  out_list->table_kind = use_xsdt != 0u ? ER_ACPI_TABLE_KIND_XSDT : ER_ACPI_TABLE_KIND_RSDT;
  if (use_xsdt != 0u) {
    entry_count = (root_len - ER_ACPI_SDT_HEADER_LEN) / 8u;
  } else {
    entry_count = (root_len - ER_ACPI_SDT_HEADER_LEN) / 4u;
  }
  if (entry_count > ER_ACPI_MAX_TABLES) {
    entry_count = ER_ACPI_MAX_TABLES;
  }

  for (i = 0; i < entry_count; ++i) {
    UINT64 address;

    if (use_xsdt != 0u) {
      address = er_acpi_get_u64(root + ER_ACPI_SDT_HEADER_LEN + (i * 8u));
    } else {
      address = (UINT64)er_acpi_get_u32(root + ER_ACPI_SDT_HEADER_LEN + (i * 4u));
    }
    if (er_acpi_table_info(address, &out_list->tables[out_list->table_count]) != 0u) {
      ++out_list->table_count;
    }
  }
  return 1;
}

UINT8 er_acpi_find_table(const ErAcpiTableList* list, UINT32 signature, ErAcpiTableInfo* out_info) {
  UINT32 i;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (list == 0 || list->found == 0u || signature == 0u) {
    return 0;
  }

  for (i = 0; i < list->table_count; ++i) {
    if (list->tables[i].signature == signature) {
      out_info->signature = list->tables[i].signature;
      out_info->length = list->tables[i].length;
      out_info->revision = list->tables[i].revision;
      out_info->checksum_valid = list->tables[i].checksum_valid;
      out_info->address = list->tables[i].address;
      return 1;
    }
  }
  return 0;
}

UINT8 er_acpi_parse_madt(UINT64 madt_address, ErAcpiMadtInfo* out_info) {
  const UINT8* madt = (const UINT8*)(UINTN)madt_address;
  UINT32 length;
  UINT32 offset;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (madt == 0 || er_acpi_get_u32(madt) != er_acpi_signature("APIC")) {
    return 0;
  }

  length = er_acpi_get_u32(madt + 4);
  if (length < ER_ACPI_MADT_HEADER_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(madt, (UINTN)length);
  out_info->lapic_address = er_acpi_get_u32(madt + 36);
  out_info->flags = er_acpi_get_u32(madt + 40);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  offset = ER_ACPI_MADT_HEADER_LEN;
  while (offset + 2u <= length) {
    UINT8 entry_type = madt[offset];
    UINT8 entry_len = madt[offset + 1u];
    const UINT8* entry = madt + offset;

    if (entry_len < 2u || offset + entry_len > length) {
      return 1;
    }

    if (entry_type == ER_ACPI_MADT_ENTRY_LAPIC && entry_len >= 8u &&
        out_info->lapic_count < ER_ACPI_MAX_MADT_LAPICS) {
      ErAcpiMadtLapic* lapic = &out_info->lapics[out_info->lapic_count];

      lapic->acpi_processor_id = entry[2];
      lapic->apic_id = entry[3];
      lapic->flags = er_acpi_get_u32(entry + 4);
      ++out_info->lapic_count;
    } else if (entry_type == ER_ACPI_MADT_ENTRY_IOAPIC && entry_len >= 12u &&
               out_info->ioapic_count < ER_ACPI_MAX_MADT_IOAPICS) {
      ErAcpiMadtIoapic* ioapic = &out_info->ioapics[out_info->ioapic_count];

      ioapic->ioapic_id = entry[2];
      ioapic->address = er_acpi_get_u32(entry + 4);
      ioapic->global_system_interrupt_base = er_acpi_get_u32(entry + 8);
      ++out_info->ioapic_count;
    } else if (entry_type == ER_ACPI_MADT_ENTRY_INTERRUPT_SOURCE_OVERRIDE && entry_len >= 10u &&
               out_info->interrupt_source_override_count < ER_ACPI_MAX_MADT_ISO) {
      ErAcpiMadtInterruptSourceOverride* iso =
          &out_info->interrupt_source_overrides[out_info->interrupt_source_override_count];

      iso->bus = entry[2];
      iso->source = entry[3];
      iso->global_system_interrupt = er_acpi_get_u32(entry + 4);
      iso->flags = er_acpi_get_u16(entry + 8);
      ++out_info->interrupt_source_override_count;
    }

    offset += entry_len;
  }
  return 1;
}

UINT8 er_acpi_parse_mcfg(UINT64 mcfg_address, ErAcpiMcfgInfo* out_info) {
  const UINT8* mcfg = (const UINT8*)(UINTN)mcfg_address;
  UINT32 length;
  UINT32 offset;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (mcfg == 0 || er_acpi_get_u32(mcfg) != er_acpi_signature("MCFG")) {
    return 0;
  }

  length = er_acpi_get_u32(mcfg + 4);
  if (length < ER_ACPI_MCFG_HEADER_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(mcfg, (UINTN)length);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  offset = ER_ACPI_MCFG_HEADER_LEN;
  while (offset + ER_ACPI_MCFG_ALLOC_LEN <= length &&
         out_info->allocation_count < ER_ACPI_MAX_MCFG_ALLOCS) {
    ErAcpiMcfgAllocation* allocation = &out_info->allocations[out_info->allocation_count];

    allocation->base_address = er_acpi_get_u64(mcfg + offset);
    allocation->pci_segment_group = er_acpi_get_u16(mcfg + offset + 8u);
    allocation->start_bus = mcfg[offset + 10u];
    allocation->end_bus = mcfg[offset + 11u];
    if (allocation->base_address != 0u && allocation->start_bus <= allocation->end_bus) {
      ++out_info->allocation_count;
    }
    offset += ER_ACPI_MCFG_ALLOC_LEN;
  }
  return 1;
}

UINT8 er_acpi_mcfg_config_address(const ErAcpiMcfgInfo* mcfg, UINT16 segment, UINT8 bus, UINT8 dev,
                                  UINT8 func, UINT16 offset, UINT64* out_address) {
  UINT32 i;

  if (out_address == 0) {
    return 0;
  }
  *out_address = 0;
  if (mcfg == 0 || mcfg->found == 0u || mcfg->checksum_valid == 0u ||
      dev >= 32u || func >= 8u || offset >= 4096u) {
    return 0;
  }

  for (i = 0; i < mcfg->allocation_count; ++i) {
    const ErAcpiMcfgAllocation* allocation = &mcfg->allocations[i];

    if (allocation->pci_segment_group == segment && bus >= allocation->start_bus && bus <= allocation->end_bus) {
      UINT64 bus_delta = (UINT64)(bus - allocation->start_bus);

      *out_address = allocation->base_address +
                     (bus_delta * ER_ACPI_ECAM_BUS_STRIDE) +
                     ((UINT64)dev * ER_ACPI_ECAM_DEVICE_STRIDE) +
                     ((UINT64)func * ER_ACPI_ECAM_FUNCTION_STRIDE) +
                     (UINT64)offset;
      return 1;
    }
  }
  return 0;
}

UINT8 er_acpi_parse_hpet(UINT64 hpet_address, ErAcpiHpetInfo* out_info) {
  const UINT8* hpet = (const UINT8*)(UINTN)hpet_address;
  UINT32 length;
  UINT32 event_timer_block_id;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (hpet == 0 || er_acpi_get_u32(hpet) != er_acpi_signature("HPET")) {
    return 0;
  }

  length = er_acpi_get_u32(hpet + 4);
  if (length < ER_ACPI_HPET_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(hpet, (UINTN)length);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  event_timer_block_id = er_acpi_get_u32(hpet + 36);
  out_info->hardware_rev_id = (UINT8)(event_timer_block_id & 0xffu);
  out_info->comparator_count = (UINT8)(((event_timer_block_id >> 8) & 0x1fu) + 1u);
  out_info->counter_size_64 = (UINT8)((event_timer_block_id >> 13) & 0x1u);
  out_info->pci_vendor_id = (UINT16)((event_timer_block_id >> 16) & 0xffffu);
  out_info->address_space_id = hpet[40];
  out_info->register_bit_width = hpet[41];
  out_info->register_bit_offset = hpet[42];
  out_info->address_size = hpet[43];
  out_info->address = er_acpi_get_u64(hpet + 44);
  out_info->hpet_number = hpet[52];
  out_info->minimum_tick = er_acpi_get_u16(hpet + 53);
  out_info->page_protection = hpet[55];
  return 1;
}

static void er_acpi_parse_gas(const UINT8* bytes, ErAcpiGenericAddress* out_address) {
  if (bytes == 0 || out_address == 0) {
    return;
  }
  out_address->address_space_id = bytes[0];
  out_address->register_bit_width = bytes[1];
  out_address->register_bit_offset = bytes[2];
  out_address->access_size = bytes[3];
  out_address->address = er_acpi_get_u64(bytes + 4);
}

UINT8 er_acpi_parse_fadt(UINT64 fadt_address, ErAcpiFadtInfo* out_info) {
  const UINT8* fadt = (const UINT8*)(UINTN)fadt_address;
  UINT32 length;

  if (out_info == 0) {
    return 0;
  }
  er_acpi_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (fadt == 0 || er_acpi_get_u32(fadt) != er_acpi_signature("FACP")) {
    return 0;
  }

  length = er_acpi_get_u32(fadt + 4);
  if (length < ER_ACPI_FADT_MIN_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(fadt, (UINTN)length);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  out_info->sci_interrupt = er_acpi_get_u16(fadt + 46);
  out_info->smi_command_port = er_acpi_get_u32(fadt + 48);
  out_info->acpi_enable = fadt[52];
  out_info->acpi_disable = fadt[53];
  out_info->pm1a_event_block = er_acpi_get_u32(fadt + 56);
  out_info->pm1b_event_block = er_acpi_get_u32(fadt + 60);
  out_info->pm1a_control_block = er_acpi_get_u32(fadt + 64);
  out_info->pm1b_control_block = er_acpi_get_u32(fadt + 68);
  out_info->pm_timer_block = er_acpi_get_u32(fadt + 76);
  out_info->pm1_event_length = fadt[88];
  out_info->pm1_control_length = fadt[89];
  out_info->pm_timer_length = fadt[91];
  out_info->boot_architecture_flags = er_acpi_get_u16(fadt + 109);
  out_info->flags = er_acpi_get_u32(fadt + 112);
  if (length >= 129u) {
    er_acpi_parse_gas(fadt + 116, &out_info->reset_register);
    out_info->reset_value = fadt[128];
  }
  return 1;
}
