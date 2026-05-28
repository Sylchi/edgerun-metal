const std = @import("std");

pub const Token = union(enum) {
    eof,
    invalid: []const u8,
    identifier: []const u8,
    integer_literal: []const u8,
    string_literal: []const u8,

    keyword_const,
    keyword_var,
    keyword_fn,
    keyword_export,
    keyword_pub,
    keyword_return,
    keyword_while,
    keyword_if,
    keyword_else,
    keyword_true,
    keyword_false,
    keyword_module,

    builtin_import,
    builtin_int_cast,
    builtin_int_from_enum,
    builtin_int_from_ptr,

    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    colon,
    semicolon,
    equals,
    dot,
    comma,

    plus,
    minus,
    star,
    slash,
    percent,
    eq_eq,
    not_eq,
    lt,
    gt,
    lt_eq,
    gt_eq,
};

pub const Tokenizer = struct {
    source: []const u8,
    index: usize = 0,

    pub fn init(source: []const u8) Tokenizer {
        return .{ .source = source };
    }

    pub fn peek(tokenizer: *const Tokenizer) Token {
        var copy = tokenizer.*;
        return copy.next();
    }

    pub fn next(tokenizer: *Tokenizer) Token {
        tokenizer.skipSpace();
        if (tokenizer.index >= tokenizer.source.len) return .eof;
        const byte = tokenizer.source[tokenizer.index];
        if (byte == '/' and tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '/') {
            tokenizer.skipLineComment();
            return tokenizer.next();
        }
        if (byte == '@') {
            const start = tokenizer.index;
            tokenizer.index += 1;
            const ident_start = tokenizer.index;
            while (tokenizer.index < tokenizer.source.len and identContinue(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
            const name = tokenizer.source[ident_start..tokenizer.index];
            if (std.mem.eql(u8, name, "import")) return .builtin_import;
            if (std.mem.eql(u8, name, "intCast")) return .builtin_int_cast;
            if (std.mem.eql(u8, name, "intFromEnum")) return .builtin_int_from_enum;
            if (std.mem.eql(u8, name, "intFromPtr")) return .builtin_int_from_ptr;
            return .{ .invalid = tokenizer.source[start..tokenizer.index] };
        }
        if (identStart(byte)) {
            const start = tokenizer.index;
            tokenizer.index += 1;
            while (tokenizer.index < tokenizer.source.len and identContinue(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
            const word = tokenizer.source[start..tokenizer.index];
            return if (matchKeyword(word)) |tok| tok else .{ .identifier = word };
        }
        if (byte >= '0' and byte <= '9') {
            const start = tokenizer.index;
            while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] >= '0' and tokenizer.source[tokenizer.index] <= '9') : (tokenizer.index += 1) {}
            return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
        }
        if (byte == '"') {
            const start = tokenizer.index;
            tokenizer.index += 1;
            while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] != '"') : (tokenizer.index += 1) {
                if (tokenizer.source[tokenizer.index] == '\\') tokenizer.index += 1;
            }
            if (tokenizer.index >= tokenizer.source.len) return .{ .invalid = tokenizer.source[start..tokenizer.index] };
            tokenizer.index += 1;
            return .{ .string_literal = tokenizer.source[start..tokenizer.index] };
        }
        tokenizer.index += 1;
        return switch (byte) {
            '(' => Token{ .lparen = {} },
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            '[' => .lbracket,
            ']' => .rbracket,
            ':' => .colon,
            ';' => .semicolon,
            ',' => .comma,
            '.' => .dot,
            '+' => .plus,
            '-' => .minus,
            '*' => .star,
            '/' => .slash,
            '%' => .percent,
            '=' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .eq_eq = {} };
            } else .equals,
            '!' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .not_eq = {} };
            } else .{ .invalid = tokenizer.source[tokenizer.index - 1 .. tokenizer.index] },
            '<' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .lt_eq = {} };
            } else .lt,
            '>' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .gt_eq = {} };
            } else .gt,
            else => .{ .invalid = tokenizer.source[tokenizer.index - 1 .. tokenizer.index] },
        };
    }

    fn skipSpace(tokenizer: *Tokenizer) void {
        while (tokenizer.index < tokenizer.source.len) {
            const byte = tokenizer.source[tokenizer.index];
            if (byte == '/' and tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '/') {
                tokenizer.skipLineComment();
                continue;
            }
            if (byte != ' ' and byte != '\n' and byte != '\r' and byte != '\t') break;
            tokenizer.index += 1;
        }
    }

    fn skipLineComment(tokenizer: *Tokenizer) void {
        tokenizer.index += 2;
        while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] != '\n' and tokenizer.source[tokenizer.index] != '\r') : (tokenizer.index += 1) {}
    }
};

fn matchKeyword(word: []const u8) ?Token {
    if (std.mem.eql(u8, word, "const")) return .keyword_const;
    if (std.mem.eql(u8, word, "var")) return .keyword_var;
    if (std.mem.eql(u8, word, "fn")) return .keyword_fn;
    if (std.mem.eql(u8, word, "export")) return .keyword_export;
    if (std.mem.eql(u8, word, "pub")) return .keyword_pub;
    if (std.mem.eql(u8, word, "return")) return .keyword_return;
    if (std.mem.eql(u8, word, "while")) return .keyword_while;
    if (std.mem.eql(u8, word, "if")) return .keyword_if;
    if (std.mem.eql(u8, word, "else")) return .keyword_else;
    if (std.mem.eql(u8, word, "true")) return .keyword_true;
    if (std.mem.eql(u8, word, "false")) return .keyword_false;
    if (std.mem.eql(u8, word, "module")) return .keyword_module;
    return null;
}

fn identStart(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z') or byte == '_';
}

fn identContinue(byte: u8) bool {
    return identStart(byte) or (byte >= '0' and byte <= '9');
}

pub fn tokenize(source: []const u8) Tokenizer {
    return Tokenizer.init(source);
}

test "tokenizer handles basic tokens" {
    var tok = tokenize("const max: usize = 4096;");
    try std.testing.expectEqual(Token.keyword_const, tok.next());
    try std.testing.expectEqualStrings("max", tok.next().identifier);
    try std.testing.expectEqual(Token.colon, tok.next());
    try std.testing.expectEqualStrings("usize", tok.next().identifier);
    try std.testing.expectEqual(Token.equals, tok.next());
    try std.testing.expectEqualStrings("4096", tok.next().integer_literal);
    try std.testing.expectEqual(Token.semicolon, tok.next());
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles keywords" {
    var tok = tokenize("pub export fn er_app_main() i32 { return 7; }");
    try std.testing.expectEqual(Token.keyword_pub, tok.next());
    try std.testing.expectEqual(Token.keyword_export, tok.next());
    try std.testing.expectEqual(Token.keyword_fn, tok.next());
    try std.testing.expectEqualStrings("er_app_main", tok.next().identifier);
    try std.testing.expectEqual(Token.lparen, tok.next());
    try std.testing.expectEqual(Token.rparen, tok.next());
    try std.testing.expectEqualStrings("i32", tok.next().identifier);
    try std.testing.expectEqual(Token.lbrace, tok.next());
    try std.testing.expectEqual(Token.keyword_return, tok.next());
    try std.testing.expectEqualStrings("7", tok.next().integer_literal);
    try std.testing.expectEqual(Token.semicolon, tok.next());
    try std.testing.expectEqual(Token.rbrace, tok.next());
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer skips comments and handles builtins" {
    var tok = tokenize(
        \\// comment
        \\const val: usize = @intCast(7);
    );
    try std.testing.expectEqual(Token.keyword_const, tok.next());
    try std.testing.expectEqualStrings("val", tok.next().identifier);
    try std.testing.expectEqual(Token.colon, tok.next());
    try std.testing.expectEqualStrings("usize", tok.next().identifier);
    try std.testing.expectEqual(Token.equals, tok.next());
    try std.testing.expectEqual(Token.builtin_int_cast, tok.next());
    try std.testing.expectEqual(Token.lparen, tok.next());
    try std.testing.expectEqualStrings("7", tok.next().integer_literal);
    try std.testing.expectEqual(Token.rparen, tok.next());
    try std.testing.expectEqual(Token.semicolon, tok.next());
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles operators and comparison" {
    var tok = tokenize("a + b * c != d <= e");
    try std.testing.expectEqualStrings("a", tok.next().identifier);
    try std.testing.expectEqual(Token.plus, tok.next());
    try std.testing.expectEqualStrings("b", tok.next().identifier);
    try std.testing.expectEqual(Token.star, tok.next());
    try std.testing.expectEqualStrings("c", tok.next().identifier);
    try std.testing.expectEqual(Token.not_eq, tok.next());
    try std.testing.expectEqualStrings("d", tok.next().identifier);
    try std.testing.expectEqual(Token.lt_eq, tok.next());
    try std.testing.expectEqualStrings("e", tok.next().identifier);
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles string literals" {
    var tok = tokenize("\"hello world\"");
    try std.testing.expectEqualStrings("\"hello world\"", tok.next().string_literal);
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles builtins" {
    var tok = tokenize("@import @intFromEnum @intFromPtr");
    try std.testing.expectEqual(Token.builtin_import, tok.next());
    try std.testing.expectEqual(Token.builtin_int_from_enum, tok.next());
    try std.testing.expectEqual(Token.builtin_int_from_ptr, tok.next());
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles module keyword" {
    var tok = tokenize("const helper: module = @import(\"src/er/self_host/helper.er\");");
    try std.testing.expectEqual(Token.keyword_const, tok.next());
    try std.testing.expectEqualStrings("helper", tok.next().identifier);
    try std.testing.expectEqual(Token.colon, tok.next());
    try std.testing.expectEqual(Token.keyword_module, tok.next());
    try std.testing.expectEqual(Token.equals, tok.next());
    try std.testing.expectEqual(Token.builtin_import, tok.next());
    try std.testing.expectEqual(Token.lparen, tok.next());
    try std.testing.expectEqualStrings("\"src/er/self_host/helper.er\"", tok.next().string_literal);
    try std.testing.expectEqual(Token.rparen, tok.next());
    try std.testing.expectEqual(Token.semicolon, tok.next());
    try std.testing.expectEqual(Token.eof, tok.next());
}

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
