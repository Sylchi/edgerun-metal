const std = @import("std");

const const_keyword = "const ";
const var_keyword = "var ";
const fn_keyword = "fn ";
const export_fn_keyword = "export fn ";
const pub_export_fn_keyword = "pub export fn ";

pub const Stats = struct {
    declaration_count: u32 = 0,
    export_count: u32 = 0,
    export_name_bytes: u32 = 0,
};

pub const ParsedExport = struct {
    name: []const u8,
    args: []const u8,
    signature_tail: []const u8,
    body: []const u8,
    next_index: usize,
    exported: bool,
};

pub const ParsedConst = struct {
    name: []const u8,
    type_expr: []const u8,
    value: []const u8,
    next_index: usize,
};

pub fn parse(source: []const u8) ?Stats {
    var stats = Stats{};
    var index: usize = 0;
    while (true) {
        index = skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            index = parseConst(source, index) orelse return null;
            stats.declaration_count += 1;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            index = parseVar(source, index) orelse return null;
            stats.declaration_count += 1;
            continue;
        }
        if (parseFunction(source, index)) |parsed| {
            index = parsed.next_index;
            stats.declaration_count += 1;
            if (parsed.exported) {
                stats.export_count += 1;
                stats.export_name_bytes += @intCast(parsed.name.len);
            }
            continue;
        }
        return null;
    }
    if (stats.declaration_count == 0 or stats.export_count == 0) return null;
    return stats;
}

pub fn parseConst(source: []const u8, start: usize) ?usize {
    return if (parseConstDecl(source, start)) |decl| decl.next_index else null;
}

pub fn parseVar(source: []const u8, start: usize) ?usize {
    return if (parseVarDecl(source, start)) |decl| decl.next_index else null;
}

pub fn parseConstDecl(source: []const u8, start: usize) ?ParsedConst {
    return parseTypedValueDecl(source, start, const_keyword);
}

pub fn parseVarDecl(source: []const u8, start: usize) ?ParsedConst {
    return parseTypedValueDecl(source, start, var_keyword);
}

fn parseTypedValueDecl(source: []const u8, start: usize, keyword: []const u8) ?ParsedConst {
    if (!std.mem.startsWith(u8, source[start..], keyword)) return null;
    var index = start + keyword.len;
    index = skipSpace(source, index);
    const name_end = scanIdentifierEnd(source, index) orelse return null;
    const name = source[index..name_end];
    const type_start = skipSpace(source, name_end);
    if (type_start >= source.len or source[type_start] != ':') return null;
    const type_expr_start = skipSpace(source, type_start + 1);
    index = type_expr_start;
    var paren_depth: usize = 0;
    var brace_depth: usize = 0;
    var bracket_depth: usize = 0;
    while (index < source.len) : (index += 1) {
        switch (source[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            '{' => brace_depth += 1,
            '}' => {
                if (brace_depth == 0) return null;
                brace_depth -= 1;
            },
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth == 0) return null;
                bracket_depth -= 1;
            },
            '=' => {
                if (paren_depth == 0 and brace_depth == 0 and bracket_depth == 0) break;
            },
            ';' => return null,
            else => {},
        }
    }
    if (index >= source.len or source[index] != '=') return null;
    const type_expr = trimSpace(source[type_expr_start..index]);
    const value_start = skipSpace(source, index + 1);
    index = value_start;
    paren_depth = 0;
    brace_depth = 0;
    bracket_depth = 0;
    while (index < source.len) : (index += 1) {
        switch (source[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            '{' => brace_depth += 1,
            '}' => {
                if (brace_depth == 0) return null;
                brace_depth -= 1;
            },
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth == 0) return null;
                bracket_depth -= 1;
            },
            ';' => {
                if (paren_depth == 0 and brace_depth == 0 and bracket_depth == 0) {
                    return .{
                        .name = name,
                        .type_expr = type_expr,
                        .value = trimSpace(source[value_start..index]),
                        .next_index = index + 1,
                    };
                }
            },
            else => {},
        }
    }
    return null;
}

pub fn parseExport(source: []const u8, start: usize) ?ParsedExport {
    const parsed = parseFunction(source, start) orelse return null;
    return if (parsed.exported) parsed else null;
}

pub fn parseFunction(source: []const u8, start: usize) ?ParsedExport {
    const FnPrefix = struct {
        len: usize,
        exported: bool,
    };
    const prefix: FnPrefix = if (std.mem.startsWith(u8, source[start..], pub_export_fn_keyword))
        .{ .len = pub_export_fn_keyword.len, .exported = true }
    else if (std.mem.startsWith(u8, source[start..], export_fn_keyword))
        .{ .len = export_fn_keyword.len, .exported = true }
    else if (std.mem.startsWith(u8, source[start..], fn_keyword))
        .{ .len = fn_keyword.len, .exported = false }
    else
        return null;

    const name_start = start + prefix.len;
    const name_end = scanIdentifierEnd(source, name_start) orelse return null;
    var index = skipSpace(source, name_end);
    if (index >= source.len or source[index] != '(') return null;
    const args_start = index + 1;
    index = scanBalanced(source, index, '(', ')') orelse return null;
    const args = source[args_start .. index - 1];
    const signature_tail_start = index;
    index = skipSpace(source, index);
    while (index < source.len and source[index] != '{') : (index += 1) {
        if (source[index] == ';' or source[index] == '}') return null;
    }
    if (index >= source.len or source[index] != '{') return null;
    const body_start = index + 1;
    const next_index = scanBalanced(source, index, '{', '}') orelse return null;
    return .{
        .name = source[name_start..name_end],
        .args = args,
        .signature_tail = source[signature_tail_start..index],
        .body = source[body_start .. next_index - 1],
        .next_index = next_index,
        .exported = prefix.exported,
    };
}

pub fn skipSpace(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len) {
        if (asciiWhitespace(source[index])) {
            index += 1;
            continue;
        }
        if (index + 1 < source.len and source[index] == '/' and source[index + 1] == '/') {
            index += 2;
            while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
            continue;
        }
        break;
    }
    return index;
}

fn scanBalanced(source: []const u8, start: usize, open: u8, close: u8) ?usize {
    if (start >= source.len or source[start] != open) return null;
    var depth: usize = 1;
    var index = start + 1;
    while (index < source.len) : (index += 1) {
        if (source[index] == open) {
            depth += 1;
        } else if (source[index] == close) {
            depth -= 1;
            if (depth == 0) return index + 1;
        }
    }
    return null;
}

fn scanIdentifierEnd(source: []const u8, start: usize) ?usize {
    if (start >= source.len or !identifierStart(source[start])) return null;
    var index = start + 1;
    while (index < source.len and identifierContinue(source[index])) : (index += 1) {}
    return index;
}

fn identifierStart(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z') or byte == '_';
}

fn identifierContinue(byte: u8) bool {
    return identifierStart(byte) or (byte >= '0' and byte <= '9');
}

fn asciiWhitespace(byte: u8) bool {
    return switch (byte) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

fn trimSpace(source: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = source.len;
    while (start < end and asciiWhitespace(source[start])) : (start += 1) {}
    while (end > start and asciiWhitespace(source[end - 1])) : (end -= 1) {}
    return source[start..end];
}

test "parser accepts typed constants and top level exports" {
    const source =
        \\// comments are fine at top level
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_ui_max_width() u32 { return max_width; }
    ;
    const stats = parse(source).?;
    try std.testing.expectEqual(@as(u32, 3), stats.declaration_count);
    try std.testing.expectEqual(@as(u32, 2), stats.export_count);
    try std.testing.expect(stats.export_name_bytes > 0);
}

test "parser accepts private top level functions without counting exports" {
    const source =
        \\fn helper(value: i32) i32 { return value * 2; }
        \\export fn er_scale(value: i32) i32 { return helper(value); }
    ;
    const stats = parse(source).?;
    try std.testing.expectEqual(@as(u32, 2), stats.declaration_count);
    try std.testing.expectEqual(@as(u32, 1), stats.export_count);

    const helper = parseFunction(source, 0).?;
    try std.testing.expectEqualStrings("helper", helper.name);
    try std.testing.expect(!helper.exported);
    const exported = parseExport(source, skipSpace(source, helper.next_index)).?;
    try std.testing.expectEqualStrings("er_scale", exported.name);
    try std.testing.expect(exported.exported);
}

test "parser accepts top level vars without counting exports" {
    const source =
        \\var committed_len: usize = 0;
        \\pub export fn er_app_main() i32 { return committed_len; }
    ;
    const stats = parse(source).?;
    try std.testing.expectEqual(@as(u32, 2), stats.declaration_count);
    try std.testing.expectEqual(@as(u32, 1), stats.export_count);

    const parsed = parseVarDecl(source, 0).?;
    try std.testing.expectEqualStrings("committed_len", parsed.name);
    try std.testing.expectEqualStrings("usize", parsed.type_expr);
    try std.testing.expectEqualStrings("0", parsed.value);
}

test "parser rejects unsupported top level source" {
    try std.testing.expect(parse("var counter = 0;") == null);
    try std.testing.expect(parse("const max_width = 4096;") == null);
    try std.testing.expect(parse("const max_width: usize;") == null);
    try std.testing.expect(parse("pub fn helper() i32 { return 7; }") == null);
}

test "parser exposes typed const name type and value slices" {
    const source = "const buffer: [max_width]u8 = undefined;";
    const parsed = parseConstDecl(source, 0).?;
    try std.testing.expectEqualStrings("buffer", parsed.name);
    try std.testing.expectEqualStrings("[max_width]u8", parsed.type_expr);
    try std.testing.expectEqualStrings("undefined", parsed.value);
    try std.testing.expectEqual(source.len, parsed.next_index);
}

test "parser returns export body slices without discovering nested exports" {
    const source =
        \\const max_width: usize = 4096;
        \\export fn er_ui_outer() u32 {
        \\    export fn er_ui_nested() u32 { return max_width; }
        \\    return max_width;
        \\}
    ;
    var index = skipSpace(source, 0);
    index = parseConst(source, index).?;
    index = skipSpace(source, index);
    const parsed = parseExport(source, index).?;
    try std.testing.expectEqualStrings("er_ui_outer", parsed.name);
    try std.testing.expect(std.mem.indexOf(u8, parsed.body, "er_ui_nested") != null);
    try std.testing.expectEqual(source.len, skipSpace(source, parsed.next_index));
}
