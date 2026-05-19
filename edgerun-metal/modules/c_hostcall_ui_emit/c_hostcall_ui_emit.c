extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return ui_emit(1024, 172); }
