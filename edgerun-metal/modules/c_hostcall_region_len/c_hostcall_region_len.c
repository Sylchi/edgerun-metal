extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
extern i64 region_len(i64) __import("edgerun.memory", "region_len");
memory(1);
export i64 main(void) { return region_len(2); }
