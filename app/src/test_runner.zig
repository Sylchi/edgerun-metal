const builtin = @import("builtin");
const std = @import("std");

const Reset = "\x1b[0m";
const Green = "\x1b[32m";
const Red = "\x1b[31m";
const Yellow = "\x1b[33m";
const Cyan = "\x1b[36m";
const Bold = "\x1b[1m";

const Format = enum { terminal, tap };

pub fn main() void {
    const format: Format = .terminal;

    const test_fns = builtin.test_functions;
    var passed: usize = 0;
    var skipped: usize = 0;
    var failed: usize = 0;

    for (test_fns, 0..) |test_fn, i| {
        var buf: [64]u8 = undefined;
        const prefix = std.fmt.bufPrint(&buf, "{d}/{d} ", .{ i + 1, test_fns.len }) catch unreachable;

        if (format == .terminal) {
            std.debug.print("{s}{s}{s} {s}... ", .{ Bold, Cyan, prefix, test_fn.name });
        }

        if (test_fn.func()) {
            passed += 1;
            std.debug.print("{s}PASS{s}\n", .{ Green, Reset });
        } else |err| switch (err) {
            error.SkipZigTest => {
                skipped += 1;
                std.debug.print("{s}SKIP{s}\n", .{ Yellow, Reset });
            },
            else => {
                failed += 1;
                std.debug.print("{s}FAIL{s} ({t})\n", .{ Red, Reset, err });
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
            },
        }
    }

    std.debug.print("\n{s}═══ Results ═══{s}\n", .{ Bold, Reset });
    std.debug.print("  {s}Total:{s}  {d} tests\n", .{ Cyan, Reset, test_fns.len });
    std.debug.print("  {s}Passed:{s} {d}\n", .{ Green, Reset, passed });
    if (skipped > 0) std.debug.print("  {s}Skipped:{s}{d}\n", .{ Yellow, Reset, skipped });
    if (failed > 0) {
        std.debug.print("  {s}Failed:{s}  {d}\n", .{ Red, Reset, failed });
    }
    if (failed == 0) {
        std.debug.print("\n{s}✓ All {d} tests passed.{s}\n", .{ Green, passed, Reset });
    } else {
        std.debug.print("\n{s}✗ {d} test(s) failed.{s}\n", .{ Red, failed, Reset });
    }

    if (failed != 0) std.process.exit(1);
}
