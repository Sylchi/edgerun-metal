#include "er_acpi.h"
#include "er_mem.h"

/*
 * Purpose: parse the small ACPI discovery surface needed by the metal executor.
 * Intention: enumerate firmware table addresses while leaving interpretation to later layers.
 */

#define ER_ACPI_RSDP_V1_LEN 20u
#define ER_ACPI_RSDP_V2_MIN_LEN 36u
#define ER_ACPI_SDT_HEADER_LEN 36u
#define ER_ACPI_RSDP_SIG0 0x2052545020445352ull
#define ER_ACPI_GUID_DATA4_LEN 8u
#define ER_ACPI_U16_BYTE1_SHIFT 8u
#define ER_ACPI_U32_BYTE2_SHIFT 16u
#define ER_ACPI_U32_BYTE3_SHIFT 24u
#define ER_ACPI_U64_HIGH32_SHIFT 32u
#define ER_ACPI_U32_BYTE2_INDEX 2u
#define ER_ACPI_U32_BYTE3_INDEX 3u
#define ER_ACPI_U64_HIGH32_OFFSET 4u
#define ER_ACPI_SDT_SIGNATURE_OFFSET 0u
#define ER_ACPI_SDT_LENGTH_OFFSET 4u
#define ER_ACPI_SDT_REVISION_OFFSET 8u
#define ER_ACPI_RSDP_REVISION_OFFSET 15u
#define ER_ACPI_RSDP_RSDT_OFFSET 16u
#define ER_ACPI_RSDP_LENGTH_OFFSET 20u
#define ER_ACPI_RSDP_XSDT_OFFSET 24u
#define ER_ACPI_RSDT_ENTRY_BYTES 4u
#define ER_ACPI_XSDT_ENTRY_BYTES 8u
#define ER_ACPI_MADT_HEADER_LEN 44u
#define ER_ACPI_MADT_LAPIC_ADDRESS_OFFSET 36u
#define ER_ACPI_MADT_FLAGS_OFFSET 40u
#define ER_ACPI_MADT_ENTRY_HEADER_LEN 2u
#define ER_ACPI_MADT_ENTRY_TYPE_OFFSET 0u
#define ER_ACPI_MADT_ENTRY_LEN_OFFSET 1u
#define ER_ACPI_MADT_LAPIC_ENTRY_LEN 8u
#define ER_ACPI_MADT_LAPIC_PROCESSOR_ID_OFFSET 2u
#define ER_ACPI_MADT_LAPIC_APIC_ID_OFFSET 3u
#define ER_ACPI_MADT_LAPIC_FLAGS_OFFSET 4u
#define ER_ACPI_MADT_IOAPIC_ENTRY_LEN 12u
#define ER_ACPI_MADT_IOAPIC_ID_OFFSET 2u
#define ER_ACPI_MADT_IOAPIC_ADDRESS_OFFSET 4u
#define ER_ACPI_MADT_IOAPIC_GSI_BASE_OFFSET 8u
#define ER_ACPI_MADT_ISO_ENTRY_LEN 10u
#define ER_ACPI_MADT_ISO_BUS_OFFSET 2u
#define ER_ACPI_MADT_ISO_SOURCE_OFFSET 3u
#define ER_ACPI_MADT_ISO_GSI_OFFSET 4u
#define ER_ACPI_MADT_ISO_FLAGS_OFFSET 8u
#define ER_ACPI_MCFG_HEADER_LEN 44u
#define ER_ACPI_MCFG_ALLOC_LEN 16u
#define ER_ACPI_MCFG_ALLOC_BASE_OFFSET 0u
#define ER_ACPI_MCFG_ALLOC_SEGMENT_OFFSET 8u
#define ER_ACPI_MCFG_ALLOC_START_BUS_OFFSET 10u
#define ER_ACPI_MCFG_ALLOC_END_BUS_OFFSET 11u
#define ER_ACPI_ECAM_BUS_STRIDE 0x100000ull
#define ER_ACPI_ECAM_DEVICE_STRIDE 0x8000ull
#define ER_ACPI_ECAM_FUNCTION_STRIDE 0x1000ull
#define ER_ACPI_ECAM_DEVICE_COUNT 32u
#define ER_ACPI_ECAM_FUNCTION_COUNT 8u
#define ER_ACPI_ECAM_CONFIG_SPACE_BYTES 4096u
#define ER_ACPI_HPET_LEN 56u
#define ER_ACPI_HPET_EVENT_TIMER_BLOCK_ID_OFFSET 36u
#define ER_ACPI_HPET_HARDWARE_REV_MASK 0xffu
#define ER_ACPI_HPET_COMPARATOR_COUNT_SHIFT 8u
#define ER_ACPI_HPET_COMPARATOR_COUNT_MASK 0x1fu
#define ER_ACPI_HPET_COUNTER_SIZE_SHIFT 13u
#define ER_ACPI_HPET_COUNTER_SIZE_MASK 0x1u
#define ER_ACPI_HPET_VENDOR_ID_SHIFT 16u
#define ER_ACPI_HPET_VENDOR_ID_MASK 0xffffu
#define ER_ACPI_HPET_ADDRESS_SPACE_ID_OFFSET 40u
#define ER_ACPI_HPET_REGISTER_BIT_WIDTH_OFFSET 41u
#define ER_ACPI_HPET_REGISTER_BIT_OFFSET_OFFSET 42u
#define ER_ACPI_HPET_ADDRESS_SIZE_OFFSET 43u
#define ER_ACPI_HPET_ADDRESS_OFFSET 44u
#define ER_ACPI_HPET_NUMBER_OFFSET 52u
#define ER_ACPI_HPET_MINIMUM_TICK_OFFSET 53u
#define ER_ACPI_HPET_PAGE_PROTECTION_OFFSET 55u
#define ER_ACPI_FADT_MIN_LEN 116u
#define ER_ACPI_GAS_ADDRESS_SPACE_ID_OFFSET 0u
#define ER_ACPI_GAS_REGISTER_BIT_WIDTH_OFFSET 1u
#define ER_ACPI_GAS_REGISTER_BIT_OFFSET_OFFSET 2u
#define ER_ACPI_GAS_ACCESS_SIZE_OFFSET 3u
#define ER_ACPI_GAS_ADDRESS_OFFSET 4u
#define ER_ACPI_FADT_SCI_INTERRUPT_OFFSET 46u
#define ER_ACPI_FADT_SMI_COMMAND_PORT_OFFSET 48u
#define ER_ACPI_FADT_ACPI_ENABLE_OFFSET 52u
#define ER_ACPI_FADT_ACPI_DISABLE_OFFSET 53u
#define ER_ACPI_FADT_PM1A_EVENT_BLOCK_OFFSET 56u
#define ER_ACPI_FADT_PM1B_EVENT_BLOCK_OFFSET 60u
#define ER_ACPI_FADT_PM1A_CONTROL_BLOCK_OFFSET 64u
#define ER_ACPI_FADT_PM1B_CONTROL_BLOCK_OFFSET 68u
#define ER_ACPI_FADT_PM_TIMER_BLOCK_OFFSET 76u
#define ER_ACPI_FADT_PM1_EVENT_LENGTH_OFFSET 88u
#define ER_ACPI_FADT_PM1_CONTROL_LENGTH_OFFSET 89u
#define ER_ACPI_FADT_PM_TIMER_LENGTH_OFFSET 91u
#define ER_ACPI_FADT_BOOT_ARCH_FLAGS_OFFSET 109u
#define ER_ACPI_FADT_FLAGS_OFFSET 112u
#define ER_ACPI_FADT_RESET_REGISTER_OFFSET 116u
#define ER_ACPI_FADT_RESET_VALUE_OFFSET 128u
#define ER_ACPI_FADT_RESET_VALUE_MIN_LEN 129u

#define ER_ACPI_10_GUID_DATA1 0xeb9d2d30u
#define ER_ACPI_10_GUID_DATA2 0x2d88u
#define ER_ACPI_10_GUID_DATA3 0x11d3u
#define ER_ACPI_20_GUID_DATA1 0x8868e871u
#define ER_ACPI_20_GUID_DATA2 0xe4f1u
#define ER_ACPI_20_GUID_DATA3 0x11d3u
#define ER_ACPI_GUID_BYTE0 0x00u
#define ER_ACPI_10_GUID_BYTE0 0x9au
#define ER_ACPI_10_GUID_BYTE1 0x16u
#define ER_ACPI_10_GUID_BYTE3 0x90u
#define ER_ACPI_10_GUID_BYTE4 0x27u
#define ER_ACPI_10_GUID_BYTE5 0x3fu
#define ER_ACPI_10_GUID_BYTE6 0xc1u
#define ER_ACPI_10_GUID_BYTE7 0x4du
#define ER_ACPI_20_GUID_BYTE0 0xbcu
#define ER_ACPI_20_GUID_BYTE1 0x22u
#define ER_ACPI_20_GUID_BYTE3 0x80u
#define ER_ACPI_20_GUID_BYTE4 0xc7u
#define ER_ACPI_20_GUID_BYTE5 0x3cu
#define ER_ACPI_20_GUID_BYTE6 0x88u
#define ER_ACPI_20_GUID_BYTE7 0x81u

static const EFI_GUID g_acpi_10_table_guid = {
  ER_ACPI_10_GUID_DATA1, ER_ACPI_10_GUID_DATA2, ER_ACPI_10_GUID_DATA3,
  {ER_ACPI_10_GUID_BYTE0, ER_ACPI_10_GUID_BYTE1, ER_ACPI_GUID_BYTE0, ER_ACPI_10_GUID_BYTE3,
   ER_ACPI_10_GUID_BYTE4, ER_ACPI_10_GUID_BYTE5, ER_ACPI_10_GUID_BYTE6, ER_ACPI_10_GUID_BYTE7}
};

static const EFI_GUID g_acpi_20_table_guid = {
  ER_ACPI_20_GUID_DATA1, ER_ACPI_20_GUID_DATA2, ER_ACPI_20_GUID_DATA3,
  {ER_ACPI_20_GUID_BYTE0, ER_ACPI_20_GUID_BYTE1, ER_ACPI_GUID_BYTE0, ER_ACPI_20_GUID_BYTE3,
   ER_ACPI_20_GUID_BYTE4, ER_ACPI_20_GUID_BYTE5, ER_ACPI_20_GUID_BYTE6, ER_ACPI_20_GUID_BYTE7}
};

static UINT8 er_acpi_guid_equal(const EFI_GUID* a, const EFI_GUID* b) {
  UINTN i;

  if (a == 0 || b == 0 || a->Data1 != b->Data1 || a->Data2 != b->Data2 || a->Data3 != b->Data3) {
    return 0;
  }
  for (i = 0; i < ER_ACPI_GUID_DATA4_LEN; ++i) {
    if (a->Data4[i] != b->Data4[i]) {
      return 0;
    }
  }
  return 1;
}

static UINT32 er_acpi_get_u32(const UINT8* bytes) {
  return (UINT32)((UINT32)bytes[0] | ((UINT32)bytes[1] << ER_ACPI_U16_BYTE1_SHIFT) |
                  ((UINT32)bytes[ER_ACPI_U32_BYTE2_INDEX] << ER_ACPI_U32_BYTE2_SHIFT) |
                  ((UINT32)bytes[ER_ACPI_U32_BYTE3_INDEX] << ER_ACPI_U32_BYTE3_SHIFT));
}

static UINT16 er_acpi_get_u16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << ER_ACPI_U16_BYTE1_SHIFT));
}

static UINT64 er_acpi_get_u64(const UINT8* bytes) {
  return (UINT64)er_acpi_get_u32(bytes) |
         ((UINT64)er_acpi_get_u32(bytes + ER_ACPI_U64_HIGH32_OFFSET) << ER_ACPI_U64_HIGH32_SHIFT);
}

UINT32 er_acpi_signature(const char* s) {
  if (s == 0 || s[0] == 0 || s[1] == 0 ||
      s[ER_ACPI_U32_BYTE2_INDEX] == 0 || s[ER_ACPI_U32_BYTE3_INDEX] == 0) {
    return 0;
  }
  return (UINT32)(UINT8)s[0] | ((UINT32)(UINT8)s[1] << ER_ACPI_U16_BYTE1_SHIFT) |
         ((UINT32)(UINT8)s[ER_ACPI_U32_BYTE2_INDEX] << ER_ACPI_U32_BYTE2_SHIFT) |
         ((UINT32)(UINT8)s[ER_ACPI_U32_BYTE3_INDEX] << ER_ACPI_U32_BYTE3_SHIFT);
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

  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  out_info->found = 1;
  out_info->revision = rsdp[ER_ACPI_RSDP_REVISION_OFFSET];
  out_info->checksum_valid = er_acpi_checksum_valid(rsdp, ER_ACPI_RSDP_V1_LEN);
  out_info->rsdp_address = (UINT64)(UINTN)rsdp;
  out_info->rsdt_address = er_acpi_get_u32(rsdp + ER_ACPI_RSDP_RSDT_OFFSET);

  if (out_info->revision >= 2u) {
    length = er_acpi_get_u32(rsdp + ER_ACPI_RSDP_LENGTH_OFFSET);
    if (length >= ER_ACPI_RSDP_V2_MIN_LEN) {
      out_info->xsdt_address = er_acpi_get_u64(rsdp + ER_ACPI_RSDP_XSDT_OFFSET);
      out_info->xsdt_checksum_valid = er_acpi_checksum_valid(rsdp, (UINTN)length);
    }
  }
  return 1;
}

//@optimizer-ignore-function UEFI ACPI discovery must scan firmware configuration-table entries for ACPI GUIDs
UINT8 er_acpi_find_rsdp(EFI_SYSTEM_TABLE* st, ErAcpiRsdpInfo* out_info) {
  UINTN i;
  UINT8 found_10 = 0;
  UINT8* rsdp_10 = 0;

  if (out_info == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));

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

  length = er_acpi_get_u32(table + ER_ACPI_SDT_LENGTH_OFFSET);
  if (length < ER_ACPI_SDT_HEADER_LEN) {
    return 0;
  }

  out_info->signature = er_acpi_get_u32(table + ER_ACPI_SDT_SIGNATURE_OFFSET);
  out_info->length = length;
  out_info->revision = table[ER_ACPI_SDT_REVISION_OFFSET];
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
  er_mem_zero((UINT8*)out_list, (UINTN)sizeof(*out_list));

  if (rsdp == 0 || rsdp->found == 0u || rsdp->checksum_valid == 0u) {
    return 0;
  }

  use_xsdt = (UINT8)(rsdp->xsdt_address != 0u && rsdp->xsdt_checksum_valid != 0u);
  root = (const UINT8*)(UINTN)(use_xsdt != 0u ? rsdp->xsdt_address : (UINT64)rsdp->rsdt_address);
  if (root == 0) {
    return 0;
  }

  root_len = er_acpi_get_u32(root + ER_ACPI_SDT_LENGTH_OFFSET);
  if (root_len < ER_ACPI_SDT_HEADER_LEN || er_acpi_checksum_valid(root, (UINTN)root_len) == 0u) {
    return 0;
  }

  out_list->found = 1;
  out_list->table_kind = use_xsdt != 0u ? ER_ACPI_TABLE_KIND_XSDT : ER_ACPI_TABLE_KIND_RSDT;
  if (use_xsdt != 0u) {
    entry_count = (root_len - ER_ACPI_SDT_HEADER_LEN) / ER_ACPI_XSDT_ENTRY_BYTES;
  } else {
    entry_count = (root_len - ER_ACPI_SDT_HEADER_LEN) / ER_ACPI_RSDT_ENTRY_BYTES;
  }
  if (entry_count > ER_ACPI_MAX_TABLES) {
    entry_count = ER_ACPI_MAX_TABLES;
  }

  for (i = 0; i < entry_count; ++i) {
    UINT64 address;

    if (use_xsdt != 0u) {
      address = er_acpi_get_u64(root + ER_ACPI_SDT_HEADER_LEN + (i * ER_ACPI_XSDT_ENTRY_BYTES));
    } else {
      address = (UINT64)er_acpi_get_u32(root + ER_ACPI_SDT_HEADER_LEN + (i * ER_ACPI_RSDT_ENTRY_BYTES));
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
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
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
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (madt == 0 || er_acpi_get_u32(madt) != er_acpi_signature("APIC")) {
    return 0;
  }

  length = er_acpi_get_u32(madt + ER_ACPI_SDT_LENGTH_OFFSET);
  if (length < ER_ACPI_MADT_HEADER_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(madt, (UINTN)length);
  out_info->lapic_address = er_acpi_get_u32(madt + ER_ACPI_MADT_LAPIC_ADDRESS_OFFSET);
  out_info->flags = er_acpi_get_u32(madt + ER_ACPI_MADT_FLAGS_OFFSET);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  offset = ER_ACPI_MADT_HEADER_LEN;
  while (offset + ER_ACPI_MADT_ENTRY_HEADER_LEN <= length) {
    UINT8 entry_type = madt[offset + ER_ACPI_MADT_ENTRY_TYPE_OFFSET];
    UINT8 entry_len = madt[offset + ER_ACPI_MADT_ENTRY_LEN_OFFSET];
    const UINT8* entry = madt + offset;

    if (entry_len < ER_ACPI_MADT_ENTRY_HEADER_LEN || offset + entry_len > length) {
      return 1;
    }

    if (entry_type == ER_ACPI_MADT_ENTRY_LAPIC && entry_len >= ER_ACPI_MADT_LAPIC_ENTRY_LEN &&
        out_info->lapic_count < ER_ACPI_MAX_MADT_LAPICS) {
      ErAcpiMadtLapic* lapic = &out_info->lapics[out_info->lapic_count];

      lapic->acpi_processor_id = entry[ER_ACPI_MADT_LAPIC_PROCESSOR_ID_OFFSET];
      lapic->apic_id = entry[ER_ACPI_MADT_LAPIC_APIC_ID_OFFSET];
      lapic->flags = er_acpi_get_u32(entry + ER_ACPI_MADT_LAPIC_FLAGS_OFFSET);
      ++out_info->lapic_count;
    } else if (entry_type == ER_ACPI_MADT_ENTRY_IOAPIC && entry_len >= ER_ACPI_MADT_IOAPIC_ENTRY_LEN &&
               out_info->ioapic_count < ER_ACPI_MAX_MADT_IOAPICS) {
      ErAcpiMadtIoapic* ioapic = &out_info->ioapics[out_info->ioapic_count];

      ioapic->ioapic_id = entry[ER_ACPI_MADT_IOAPIC_ID_OFFSET];
      ioapic->address = er_acpi_get_u32(entry + ER_ACPI_MADT_IOAPIC_ADDRESS_OFFSET);
      ioapic->global_system_interrupt_base = er_acpi_get_u32(entry + ER_ACPI_MADT_IOAPIC_GSI_BASE_OFFSET);
      ++out_info->ioapic_count;
    } else if (entry_type == ER_ACPI_MADT_ENTRY_INTERRUPT_SOURCE_OVERRIDE && entry_len >= ER_ACPI_MADT_ISO_ENTRY_LEN &&
               out_info->interrupt_source_override_count < ER_ACPI_MAX_MADT_ISO) {
      ErAcpiMadtInterruptSourceOverride* iso =
          &out_info->interrupt_source_overrides[out_info->interrupt_source_override_count];

      iso->bus = entry[ER_ACPI_MADT_ISO_BUS_OFFSET];
      iso->source = entry[ER_ACPI_MADT_ISO_SOURCE_OFFSET];
      iso->global_system_interrupt = er_acpi_get_u32(entry + ER_ACPI_MADT_ISO_GSI_OFFSET);
      iso->flags = er_acpi_get_u16(entry + ER_ACPI_MADT_ISO_FLAGS_OFFSET);
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
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (mcfg == 0 || er_acpi_get_u32(mcfg) != er_acpi_signature("MCFG")) {
    return 0;
  }

  length = er_acpi_get_u32(mcfg + ER_ACPI_SDT_LENGTH_OFFSET);
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

    allocation->base_address = er_acpi_get_u64(mcfg + offset + ER_ACPI_MCFG_ALLOC_BASE_OFFSET);
    allocation->pci_segment_group = er_acpi_get_u16(mcfg + offset + ER_ACPI_MCFG_ALLOC_SEGMENT_OFFSET);
    allocation->start_bus = mcfg[offset + ER_ACPI_MCFG_ALLOC_START_BUS_OFFSET];
    allocation->end_bus = mcfg[offset + ER_ACPI_MCFG_ALLOC_END_BUS_OFFSET];
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
      dev >= ER_ACPI_ECAM_DEVICE_COUNT || func >= ER_ACPI_ECAM_FUNCTION_COUNT ||
      offset >= ER_ACPI_ECAM_CONFIG_SPACE_BYTES) {
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
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (hpet == 0 || er_acpi_get_u32(hpet) != er_acpi_signature("HPET")) {
    return 0;
  }

  length = er_acpi_get_u32(hpet + ER_ACPI_SDT_LENGTH_OFFSET);
  if (length < ER_ACPI_HPET_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(hpet, (UINTN)length);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  event_timer_block_id = er_acpi_get_u32(hpet + ER_ACPI_HPET_EVENT_TIMER_BLOCK_ID_OFFSET);
  out_info->hardware_rev_id = (UINT8)(event_timer_block_id & ER_ACPI_HPET_HARDWARE_REV_MASK);
  out_info->comparator_count =
      (UINT8)(((event_timer_block_id >> ER_ACPI_HPET_COMPARATOR_COUNT_SHIFT) &
               ER_ACPI_HPET_COMPARATOR_COUNT_MASK) + 1u);
  out_info->counter_size_64 =
      (UINT8)((event_timer_block_id >> ER_ACPI_HPET_COUNTER_SIZE_SHIFT) & ER_ACPI_HPET_COUNTER_SIZE_MASK);
  out_info->pci_vendor_id =
      (UINT16)((event_timer_block_id >> ER_ACPI_HPET_VENDOR_ID_SHIFT) & ER_ACPI_HPET_VENDOR_ID_MASK);
  out_info->address_space_id = hpet[ER_ACPI_HPET_ADDRESS_SPACE_ID_OFFSET];
  out_info->register_bit_width = hpet[ER_ACPI_HPET_REGISTER_BIT_WIDTH_OFFSET];
  out_info->register_bit_offset = hpet[ER_ACPI_HPET_REGISTER_BIT_OFFSET_OFFSET];
  out_info->address_size = hpet[ER_ACPI_HPET_ADDRESS_SIZE_OFFSET];
  out_info->address = er_acpi_get_u64(hpet + ER_ACPI_HPET_ADDRESS_OFFSET);
  out_info->hpet_number = hpet[ER_ACPI_HPET_NUMBER_OFFSET];
  out_info->minimum_tick = er_acpi_get_u16(hpet + ER_ACPI_HPET_MINIMUM_TICK_OFFSET);
  out_info->page_protection = hpet[ER_ACPI_HPET_PAGE_PROTECTION_OFFSET];
  return 1;
}

static void er_acpi_parse_gas(const UINT8* bytes, ErAcpiGenericAddress* out_address) {
  if (bytes == 0 || out_address == 0) {
    return;
  }
  out_address->address_space_id = bytes[ER_ACPI_GAS_ADDRESS_SPACE_ID_OFFSET];
  out_address->register_bit_width = bytes[ER_ACPI_GAS_REGISTER_BIT_WIDTH_OFFSET];
  out_address->register_bit_offset = bytes[ER_ACPI_GAS_REGISTER_BIT_OFFSET_OFFSET];
  out_address->access_size = bytes[ER_ACPI_GAS_ACCESS_SIZE_OFFSET];
  out_address->address = er_acpi_get_u64(bytes + ER_ACPI_GAS_ADDRESS_OFFSET);
}

UINT8 er_acpi_parse_fadt(UINT64 fadt_address, ErAcpiFadtInfo* out_info) {
  const UINT8* fadt = (const UINT8*)(UINTN)fadt_address;
  UINT32 length;

  if (out_info == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  if (fadt == 0 || er_acpi_get_u32(fadt) != er_acpi_signature("FACP")) {
    return 0;
  }

  length = er_acpi_get_u32(fadt + ER_ACPI_SDT_LENGTH_OFFSET);
  if (length < ER_ACPI_FADT_MIN_LEN) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = er_acpi_checksum_valid(fadt, (UINTN)length);
  if (out_info->checksum_valid == 0u) {
    return 1;
  }

  out_info->sci_interrupt = er_acpi_get_u16(fadt + ER_ACPI_FADT_SCI_INTERRUPT_OFFSET);
  out_info->smi_command_port = er_acpi_get_u32(fadt + ER_ACPI_FADT_SMI_COMMAND_PORT_OFFSET);
  out_info->acpi_enable = fadt[ER_ACPI_FADT_ACPI_ENABLE_OFFSET];
  out_info->acpi_disable = fadt[ER_ACPI_FADT_ACPI_DISABLE_OFFSET];
  out_info->pm1a_event_block = er_acpi_get_u32(fadt + ER_ACPI_FADT_PM1A_EVENT_BLOCK_OFFSET);
  out_info->pm1b_event_block = er_acpi_get_u32(fadt + ER_ACPI_FADT_PM1B_EVENT_BLOCK_OFFSET);
  out_info->pm1a_control_block = er_acpi_get_u32(fadt + ER_ACPI_FADT_PM1A_CONTROL_BLOCK_OFFSET);
  out_info->pm1b_control_block = er_acpi_get_u32(fadt + ER_ACPI_FADT_PM1B_CONTROL_BLOCK_OFFSET);
  out_info->pm_timer_block = er_acpi_get_u32(fadt + ER_ACPI_FADT_PM_TIMER_BLOCK_OFFSET);
  out_info->pm1_event_length = fadt[ER_ACPI_FADT_PM1_EVENT_LENGTH_OFFSET];
  out_info->pm1_control_length = fadt[ER_ACPI_FADT_PM1_CONTROL_LENGTH_OFFSET];
  out_info->pm_timer_length = fadt[ER_ACPI_FADT_PM_TIMER_LENGTH_OFFSET];
  out_info->boot_architecture_flags = er_acpi_get_u16(fadt + ER_ACPI_FADT_BOOT_ARCH_FLAGS_OFFSET);
  out_info->flags = er_acpi_get_u32(fadt + ER_ACPI_FADT_FLAGS_OFFSET);
  if (length >= ER_ACPI_FADT_RESET_VALUE_MIN_LEN) {
    er_acpi_parse_gas(fadt + ER_ACPI_FADT_RESET_REGISTER_OFFSET, &out_info->reset_register);
    out_info->reset_value = fadt[ER_ACPI_FADT_RESET_VALUE_OFFSET];
  }
  return 1;
}
