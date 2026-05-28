// EdgeRun clock test — freestanding
typedef unsigned char       u8;
typedef unsigned int        u32;
typedef unsigned long long  u64;
typedef unsigned long       size_t;

#define KEEPER_ID_SIZE 32

typedef struct {
    u8  keeper[32];
    u64 tick;
    u64 slot;
    u64 epoch;
    u64 era;
} er_stamp;

typedef struct {
    u64 ticks_per_slot;
    u64 slots_per_epoch;
    u64 epochs_per_era;
} er_limits;

typedef struct {
    er_stamp now;
    er_limits limits;
} er_clock;

extern int  er_memcmp(const void* a, const void* b, size_t n);
extern void er_memset(void* s, int c, size_t n);

extern int er_keeper_id_valid(const u8 *keeper);
extern int er_keeper_id_eql(const u8 *a, const u8 *b);
extern int er_stamp_valid(const er_stamp *s);
extern int er_stamp_same_keeper(const er_stamp *a, const er_stamp *b);
extern int er_stamp_order(const er_stamp *a, const er_stamp *b);
extern int er_limits_valid(const er_limits *lim);
extern int er_clock_init(const u8 *keeper, const er_limits *lim, er_clock *clk);
extern int er_clock_advance_with(er_clock *clk, u64 stride);

static int total = 0;
static int passed = 0;

static void putch(const char c) {
    const char* p = &c;
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov $1, %%rdx\n"
        "syscall"
        :: "r"(p) : "rax", "rdi", "rsi", "rdx", "memory"
    );
}

static void puts(const char* s) {
    for (; *s; s++) putch(*s);
}

#define TEST(msg, expr) do { \
    total++; \
    if (expr) { passed++; } \
    else { puts("FAIL: "); puts(msg); puts("\n"); } \
} while(0)

int main(void) {
    // ── keeper_id_valid ───────────────────────────────────────
    {
        u8 zero[32] = {0};
        TEST("zero keeper invalid", er_keeper_id_valid(zero) == 0);

        u8 one[32] = {0};
        one[0] = 1;
        TEST("non-zero keeper valid", er_keeper_id_valid(one) == 1);
    }

    // ── keeper_id_eql ─────────────────────────────────────────
    {
        u8 a[32], b[32];
        er_memset(a, 0, 32); er_memset(b, 0, 32);
        a[0] = 0xAB; b[0] = 0xAB;
        a[15] = 0xCD; b[15] = 0xCD;
        TEST("equal keepers", er_keeper_id_eql(a, b) == 1);

        b[0] = 0x00;
        TEST("different keepers", er_keeper_id_eql(a, b) == 0);
    }

    // ── stamp_valid ────────────────────────────────────────────
    {
        u8 s_mem[sizeof(er_stamp)];
        er_stamp *s = (er_stamp*)s_mem;
        er_memset(s_mem, 0, sizeof(er_stamp));
        TEST("zero-stamp invalid", er_stamp_valid(s) == 0);

        s->keeper[0] = 0xAA;
        TEST("non-zero keeper valid", er_stamp_valid(s) == 1);
    }

    // ── stamp_same_keeper ──────────────────────────────────────
    {
        u8 a_mem[sizeof(er_stamp)], b_mem[sizeof(er_stamp)];
        er_stamp *a = (er_stamp*)a_mem;
        er_stamp *b = (er_stamp*)b_mem;
        er_memset(a_mem, 0, sizeof(er_stamp));
        er_memset(b_mem, 0, sizeof(er_stamp));
        a->keeper[0] = 0xAA; b->keeper[0] = 0xAA;
        a->tick = 1; b->tick = 5;
        TEST("same keeper", er_stamp_same_keeper(a, b) == 1);

        b->keeper[0] = 0xBB;
        TEST("different keepers", er_stamp_same_keeper(a, b) == 0);
    }

    // ── stamp_order ────────────────────────────────────────────
    {
        u8 a_mem[sizeof(er_stamp)], b_mem[sizeof(er_stamp)];
        er_stamp *a = (er_stamp*)a_mem;
        er_stamp *b = (er_stamp*)b_mem;
        er_memset(a_mem, 0, sizeof(er_stamp));
        er_memset(b_mem, 0, sizeof(er_stamp));
        a->keeper[0] = 1; b->keeper[0] = 1;
        a->tick = 1; a->slot = 2; a->epoch = 3; a->era = 4;
        b->tick = 5; b->slot = 6; b->epoch = 7; b->era = 8;
        TEST("a < b by tick", er_stamp_order(a, b) == -1);
        TEST("b > a", er_stamp_order(b, a) == 1);

        // equal stamps
        u8 e_mem[sizeof(er_stamp)];
        er_stamp *e = (er_stamp*)e_mem;
        er_memset(e_mem, 0, sizeof(er_stamp));
        e->keeper[0] = 1; e->tick = 1; e->slot = 2; e->epoch = 3; e->era = 4;
        TEST("equal stamps", er_stamp_order(a, e) == 0);

        // different keeper dominates
        u8 d_mem[sizeof(er_stamp)];
        er_stamp *d = (er_stamp*)d_mem;
        er_memset(d_mem, 0, sizeof(er_stamp));
        d->keeper[0] = 2;
        TEST("keeper cmp: a < d", er_stamp_order(a, d) == -1);
        TEST("keeper cmp: d > a", er_stamp_order(d, a) == 1);
    }

    // ── limits_valid ──────────────────────────────────────────
    {
        er_limits good = {2, 4, 8};
        TEST("valid limits (2,4,8)", er_limits_valid(&good) == 1);

        er_limits bad_t = {3, 4, 8};
        TEST("invalid ticks_per_slot", er_limits_valid(&bad_t) == 0);

        er_limits bad_s = {2, 5, 8};
        TEST("invalid slots_per_epoch", er_limits_valid(&bad_s) == 0);

        er_limits bad_e = {2, 4, 9};
        TEST("invalid epochs_per_era", er_limits_valid(&bad_e) == 0);
    }

    // ── clock_init ─────────────────────────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {4, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));

        TEST("init ok", er_clock_init(keeper, &lim, clk) == 1);
        TEST("keeper copied", er_memcmp(clk->now.keeper, keeper, 32) == 0);
        TEST("init tick=0", clk->now.tick == 0);
        TEST("init slot=0", clk->now.slot == 0);
        TEST("init epoch=0", clk->now.epoch == 0);
        TEST("init era=0", clk->now.era == 0);
        TEST("limits ticks/slot", clk->limits.ticks_per_slot == 4);
        TEST("limits slot/epoch", clk->limits.slots_per_epoch == 4);
        TEST("limits epoch/era", clk->limits.epochs_per_era == 4);

        u8 zero[32];
        er_memset(zero, 0, 32);
        u8 clk2_mem[sizeof(er_clock)];
        er_clock *clk2 = (er_clock*)clk2_mem;
        er_memset(clk2_mem, 0, sizeof(er_clock));
        TEST("init fail zero keeper", er_clock_init(zero, &lim, clk2) == 0);

        er_limits bad = {3, 4, 4};
        TEST("init fail bad limits", er_clock_init(keeper, &bad, clk2) == 0);
    }

    // ── clock_advance_with (basic) ─────────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);

        int flags = er_clock_advance_with(clk, 1);
        TEST("advance 1: no boundary", flags == 0);
        TEST("advance 1: tick=1", clk->now.tick == 1);
        TEST("advance 1: slot=0", clk->now.slot == 0);
        TEST("advance 1: epoch=0", clk->now.epoch == 0);
        TEST("advance 1: era=0", clk->now.era == 0);

        flags = er_clock_advance_with(clk, 255);
        TEST("slot boundary", flags == 1);
        TEST("slot boundary: tick=0", clk->now.tick == 0);
        TEST("slot boundary: slot=1", clk->now.slot == 1);
    }

    // ── advance_with (multiple slot boundaries) ────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);

        er_clock_advance_with(clk, 256 * 2);
        TEST("2 slots: slot=2", clk->now.slot == 2);
        TEST("2 slots: epoch=0", clk->now.epoch == 0);
    }

    // ── advance_with (epoch boundary) ──────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);

        // 256*4 = 1024 ticks = exactly 1 epoch (4 slots)
        int flags = er_clock_advance_with(clk, 1024);
        TEST("one epoch: slot+epoch flags", flags == 3);
        TEST("one epoch: tick=0", clk->now.tick == 0);
        TEST("one epoch: slot=0", clk->now.slot == 0);
        TEST("one epoch: epoch=1", clk->now.epoch == 1);
        TEST("one epoch: era=0", clk->now.era == 0);
    }

    // ── advance_with (era boundary) ────────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);

        int flags = er_clock_advance_with(clk, 4096);
        TEST("era boundary: all flags", flags == 7);
        TEST("era boundary: tick=0", clk->now.tick == 0);
        TEST("era boundary: slot=0", clk->now.slot == 0);
        TEST("era boundary: epoch=0", clk->now.epoch == 0);
        TEST("era boundary: era=1", clk->now.era == 1);
    }

    // ── advance_with (zero stride) ─────────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);
        int flags = er_clock_advance_with(clk, 0);
        TEST("zero stride: error", flags == 0);
    }

    // ── advance_with (invalid limits) ─────────────────────────
    {
        u8 keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        er_limits lim = {256, 4, 4};
        u8 clk_mem[sizeof(er_clock)];
        er_clock *clk = (er_clock*)clk_mem;
        er_memset(clk_mem, 0, sizeof(er_clock));
        er_clock_init(keeper, &lim, clk);
        clk->limits.ticks_per_slot = 3;
        int flags = er_clock_advance_with(clk, 1);
        TEST("corrupted limits: error", flags == 0);
    }

    if (passed == total) {
        return 0;
    }
    return total - passed;
}
