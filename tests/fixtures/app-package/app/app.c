extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) {
  i64 ptr = 1024;
  i64 len = 172;
  return ui_emit(ptr, len);
}
