extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
extern i64 region_base(i64) __import("edgerun.memory", "region_base");
memory(1);
export i64 main(void) { return region_base(2); }
