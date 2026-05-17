#ifndef ER_ACPI_H
#define ER_ACPI_H

/*
 * Purpose: discover ACPI tables exposed by firmware.
 * Intention: make firmware hardware topology available as addressed data, without policy.
 */

#include "er_types.h"

#define ER_ACPI_MAX_TABLES 32u
#define ER_ACPI_MAX_MADT_LAPICS 32u
#define ER_ACPI_MAX_MADT_IOAPICS 8u
#define ER_ACPI_MAX_MADT_ISO 16u
#define ER_ACPI_MAX_MCFG_ALLOCS 16u

#define ER_ACPI_TABLE_KIND_NONE 0u
#define ER_ACPI_TABLE_KIND_RSDT 1u
#define ER_ACPI_TABLE_KIND_XSDT 2u

#define ER_ACPI_MADT_ENTRY_LAPIC 0u
#define ER_ACPI_MADT_ENTRY_IOAPIC 1u
#define ER_ACPI_MADT_ENTRY_INTERRUPT_SOURCE_OVERRIDE 2u

#define ER_ACPI_MADT_LAPIC_ENABLED 0x00000001u
#define ER_ACPI_MADT_LAPIC_ONLINE_CAPABLE 0x00000002u

typedef struct {
  UINT8 found;
  UINT8 revision;
  UINT8 checksum_valid;
  UINT8 xsdt_checksum_valid;
  UINT64 rsdp_address;
  UINT32 rsdt_address;
  UINT64 xsdt_address;
} ErAcpiRsdpInfo;

typedef struct {
  UINT32 signature;
  UINT32 length;
  UINT8 revision;
  UINT8 checksum_valid;
  UINT64 address;
} ErAcpiTableInfo;

typedef struct {
  UINT8 found;
  UINT8 table_kind;
  UINT32 table_count;
  ErAcpiTableInfo tables[ER_ACPI_MAX_TABLES];
} ErAcpiTableList;

typedef struct {
  UINT8 acpi_processor_id;
  UINT8 apic_id;
  UINT32 flags;
} ErAcpiMadtLapic;

typedef struct {
  UINT8 ioapic_id;
  UINT32 address;
  UINT32 global_system_interrupt_base;
} ErAcpiMadtIoapic;

typedef struct {
  UINT8 bus;
  UINT8 source;
  UINT32 global_system_interrupt;
  UINT16 flags;
} ErAcpiMadtInterruptSourceOverride;

typedef struct {
  UINT8 found;
  UINT8 checksum_valid;
  UINT32 lapic_address;
  UINT32 flags;
  UINT32 lapic_count;
  UINT32 ioapic_count;
  UINT32 interrupt_source_override_count;
  ErAcpiMadtLapic lapics[ER_ACPI_MAX_MADT_LAPICS];
  ErAcpiMadtIoapic ioapics[ER_ACPI_MAX_MADT_IOAPICS];
  ErAcpiMadtInterruptSourceOverride interrupt_source_overrides[ER_ACPI_MAX_MADT_ISO];
} ErAcpiMadtInfo;

typedef struct {
  UINT64 base_address;
  UINT16 pci_segment_group;
  UINT8 start_bus;
  UINT8 end_bus;
} ErAcpiMcfgAllocation;

typedef struct {
  UINT8 found;
  UINT8 checksum_valid;
  UINT32 allocation_count;
  ErAcpiMcfgAllocation allocations[ER_ACPI_MAX_MCFG_ALLOCS];
} ErAcpiMcfgInfo;

typedef struct {
  UINT8 found;
  UINT8 checksum_valid;
  UINT8 hardware_rev_id;
  UINT8 comparator_count;
  UINT8 counter_size_64;
  UINT16 pci_vendor_id;
  UINT8 address_space_id;
  UINT8 register_bit_width;
  UINT8 register_bit_offset;
  UINT8 address_size;
  UINT64 address;
  UINT8 hpet_number;
  UINT16 minimum_tick;
  UINT8 page_protection;
} ErAcpiHpetInfo;

typedef struct {
  UINT8 address_space_id;
  UINT8 register_bit_width;
  UINT8 register_bit_offset;
  UINT8 access_size;
  UINT64 address;
} ErAcpiGenericAddress;

typedef struct {
  UINT8 found;
  UINT8 checksum_valid;
  UINT16 sci_interrupt;
  UINT32 smi_command_port;
  UINT8 acpi_enable;
  UINT8 acpi_disable;
  UINT16 boot_architecture_flags;
  UINT32 flags;
  UINT32 pm1a_event_block;
  UINT32 pm1b_event_block;
  UINT32 pm1a_control_block;
  UINT32 pm1b_control_block;
  UINT32 pm_timer_block;
  UINT8 pm1_event_length;
  UINT8 pm1_control_length;
  UINT8 pm_timer_length;
  ErAcpiGenericAddress reset_register;
  UINT8 reset_value;
} ErAcpiFadtInfo;

UINT32 er_acpi_signature(const char* s);
UINT8 er_acpi_checksum_valid(const UINT8* bytes, UINTN len);
UINT8 er_acpi_find_rsdp(EFI_SYSTEM_TABLE* st, ErAcpiRsdpInfo* out_info);
UINT8 er_acpi_enumerate_tables(const ErAcpiRsdpInfo* rsdp, ErAcpiTableList* out_list);
UINT8 er_acpi_find_table(const ErAcpiTableList* list, UINT32 signature, ErAcpiTableInfo* out_info);
UINT8 er_acpi_parse_madt(UINT64 madt_address, ErAcpiMadtInfo* out_info);
UINT8 er_acpi_parse_mcfg(UINT64 mcfg_address, ErAcpiMcfgInfo* out_info);
UINT8 er_acpi_mcfg_config_address(const ErAcpiMcfgInfo* mcfg, UINT16 segment, UINT8 bus, UINT8 dev,
                                  UINT8 func, UINT16 offset, UINT64* out_address);
UINT8 er_acpi_parse_hpet(UINT64 hpet_address, ErAcpiHpetInfo* out_info);
UINT8 er_acpi_parse_fadt(UINT64 fadt_address, ErAcpiFadtInfo* out_info);

#endif
