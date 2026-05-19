extern i64 bus_exec(i64, i64) __import("edgerun.bus", "exec");
memory(1);
export i64 main(void) { return bus_exec(0, 128); }
