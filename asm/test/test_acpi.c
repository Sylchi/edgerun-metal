// EdgeRun ACPI parser test harness — freestanding
// Tests checksum validation, MADT parsing, and MCFG parsing.

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;

extern int  er_acpi_checksum(const void* table, uint32_t length);
extern int  er_acpi_find_rsdp(uint64_t* out_addr);
extern int  er_acpi_parse_rsdp(uint64_t rsdp_addr, uint64_t* out_rsdt,
                               uint64_t* out_xsdt, uint8_t* out_revision);
extern int  er_acpi_find_table(uint64_t rsdt_addr, uint64_t xsdt_addr,
                               uint32_t signature, uint64_t* out_addr);
extern int  er_acpi_parse_madt(const void* madt, uint32_t length,
                               uint32_t* out_lapic_addr,
                               uint32_t* out_ioapic_addr,
                               uint32_t* out_ioapic_gsi);
extern int  er_acpi_parse_mcfg(const void* mcfg, uint32_t length,
                               uint64_t* out_ecam_base,
                               uint8_t* out_start_bus,
                               uint8_t* out_end_bus);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

#define TEST_EQ(name, actual, expected) do { \
    total_tests++; \
    if ((unsigned long)(actual) == (unsigned long)(expected)) { passed_tests++; } \
} while(0)

// ACPI SDT header layout
struct acpi_sdt {
    uint32_t signature;
    uint32_t length;
    uint8_t  revision;
    uint8_t  checksum;
    uint8_t  oemid[6];
    uint8_t  oem_tableid[8];
    uint32_t oem_revision;
    uint32_t creator_id;
    uint32_t creator_revision;
};

// Fill checksum such that sum of all bytes == 0
static void fix_checksum(struct acpi_sdt* hdr) {
    uint8_t* p = (uint8_t*)hdr;
    uint32_t len = hdr->length;
    uint32_t sum = 0;
    for (uint32_t i = 0; i < len; i++)
        sum += p[i];
    // Adjust checksum byte to make total zero
    p[9] = (uint8_t)(p[9] - sum);
}

int main(void) {
    // ─── er_acpi_checksum tests ─────────────────────────────────
    {
        // Valid: single zero byte → sum = 0 → valid
        uint8_t zero = 0;
        TEST("zero byte valid", er_acpi_checksum(&zero, 1) == 1);
    }
    {
        // Invalid: single non-zero byte → sum != 0
        uint8_t one = 1;
        TEST("one byte invalid", er_acpi_checksum(&one, 1) == 0);
    }
    {
        // Length zero → trivially valid
        uint8_t buf[4] = {1, 2, 3, 4};
        TEST("zero length valid", er_acpi_checksum(buf, 0) == 0);
    }
    {
        // Valid checksum: sum of bytes mod 256 = 0
        uint8_t data[] = {0x10, 0x20, 0x30, 0xA0}; // 0x10+0x20+0x30+0xA0 = 0x100
        TEST("valid checksum", er_acpi_checksum(data, 4) == 1);
    }

    // ─── MADT parsing tests ─────────────────────────────────────
    {
        // Build a minimal MADT: SDT header + LAPIC addr + flags +
        // one IOAPIC entry.
        uint8_t madt_buf[64];
        struct acpi_sdt* hdr = (struct acpi_sdt*)madt_buf;
        hdr->signature   = 0x43495041;     // "APIC"
        hdr->length      = sizeof(struct acpi_sdt) + 8 + 12;
        hdr->revision    = 3;
        hdr->checksum    = 0;              // will fix
        hdr->oem_revision = 0;
        hdr->creator_id   = 0;
        hdr->creator_revision = 0;

        // MADT-specific: LAPIC address + flags + entries
        uint32_t* lapic_addr = (uint32_t*)(madt_buf + 36);
        *lapic_addr = 0xFEE00000;           // LAPIC base
        uint32_t* flags = (uint32_t*)(madt_buf + 40);
        *flags = 1;                         // PC-AT compatible

        // IOAPIC entry at offset 44
        uint8_t* entry = madt_buf + 44;
        entry[0] = 1;                       // IOAPIC type
        entry[1] = 12;                      // length = 12
        entry[2] = 0;                       // IOAPIC ID
        entry[3] = 0;
        *(uint32_t*)(entry + 4) = 0xFEC00000; // IOAPIC base
        *(uint32_t*)(entry + 8) = 0;           // GSI base

        fix_checksum(hdr);

        uint32_t out_lapic = 0;
        uint32_t out_ioapic = 0;
        uint32_t out_gsi = 0;

        int r = er_acpi_parse_madt(madt_buf, hdr->length,
                                   &out_lapic, &out_ioapic, &out_gsi);
        TEST("madt parse success", r == 1);
        TEST_EQ("madt lapic addr", out_lapic, 0xFEE00000);
        TEST_EQ("madt ioapic addr", out_ioapic, 0xFEC00000);
        TEST_EQ("madt ioapic gsi", out_gsi, 0);
    }
    {
        // MADT with bad signature
        uint8_t buf[44] = {0};
        *(uint32_t*)(buf) = 0xDEADBEEF;     // wrong sig
        *(uint32_t*)(buf + 4) = 44;          // length
        uint32_t out_lapic = 0, out_ioapic = 0, out_gsi = 0;
        int r = er_acpi_parse_madt(buf, 44, &out_lapic, &out_ioapic, &out_gsi);
        TEST("madt bad sig", r == 0);
    }
    {
        // MADT too short
        uint8_t buf[36] = {0};
        *(uint32_t*)(buf) = 0x43495041;     // "APIC"
        *(uint32_t*)(buf + 4) = 36;          // length (too short, no entries)
        uint32_t out_lapic = 0, out_ioapic = 0, out_gsi = 0;
        int r = er_acpi_parse_madt(buf, 36, &out_lapic, &out_ioapic, &out_gsi);
        TEST("madt too short", r == 0);
    }

    // ─── MCFG parsing tests ─────────────────────────────────────
    {
        // Build minimal MCFG: SDT header + reserved + one allocation
        uint8_t mcfg_buf[64];
        struct acpi_sdt* hdr = (struct acpi_sdt*)mcfg_buf;
        hdr->signature   = 0x4746434d;     // "MCFG"
        hdr->length      = sizeof(struct acpi_sdt) + 8 + 16;
        hdr->revision    = 1;
        hdr->checksum    = 0;
        hdr->oem_revision = 0;
        hdr->creator_id   = 0;
        hdr->creator_revision = 0;

        // Reserved (8 bytes)
        uint64_t* reserved = (uint64_t*)(mcfg_buf + 36);
        *reserved = 0;

        // Allocation entry at offset 44
        uint8_t* alloc = mcfg_buf + 44;
        *(uint64_t*)(alloc + 0) = 0xE0000000;    // ECAM base
        *(uint16_t*)(alloc + 8) = 0;              // segment group
        alloc[10] = 0;                            // start bus
        alloc[11] = 255;                          // end bus

        fix_checksum(hdr);

        uint64_t out_base = 0;
        uint8_t  out_start = 0;
        uint8_t  out_end = 0;

        int r = er_acpi_parse_mcfg(mcfg_buf, hdr->length,
                                   &out_base, &out_start, &out_end);
        TEST("mcfg parse success", r == 1);
        TEST_EQ("mcfg ecam base", out_base, 0xE0000000);
        TEST_EQ("mcfg start bus", (unsigned long)out_start, 0);
        TEST_EQ("mcfg end bus", (unsigned long)out_end, 255);
    }
    {
        // MCFG with bad signature
        uint8_t buf[60] = {0};
        *(uint32_t*)(buf) = 0xDEADBEEF;
        *(uint32_t*)(buf + 4) = 60;
        uint64_t out_base = 0;
        uint8_t out_start = 0, out_end = 0;
        int r = er_acpi_parse_mcfg(buf, 60, &out_base, &out_start, &out_end);
        TEST("mcfg bad sig", r == 0);
    }
    {
        // MCFG too short
        uint8_t buf[40] = {0};
        *(uint32_t*)(buf) = 0x4746434d;
        *(uint32_t*)(buf + 4) = 40;
        uint64_t out_base = 0;
        uint8_t out_start = 0, out_end = 0;
        int r = er_acpi_parse_mcfg(buf, 40, &out_base, &out_start, &out_end);
        TEST("mcfg too short", r == 0);
    }

    if (passed_tests == total_tests) {
        return 0;
    }
    return total_tests - passed_tests;
}
