const std = @import("std");

pub const Token = union(enum) {
    eof,
    invalid: []const u8,
    identifier: []const u8,
    integer_literal: []const u8,
    float_literal: []const u8,
    string_literal: []const u8,
    char_literal: []const u8,
    multiline_string_literal_line: []const u8,
    builtin: []const u8,
    doc_comment: []const u8,
    container_doc_comment: []const u8,

    keyword_addrspace,
    keyword_align,
    keyword_allowzero,
    keyword_and,
    keyword_anyframe,
    keyword_anytype,
    keyword_asm,
    keyword_break,
    keyword_callconv,
    keyword_catch,
    keyword_comptime,
    keyword_const,
    keyword_continue,
    keyword_defer,
    keyword_else,
    keyword_enum,
    keyword_errdefer,
    keyword_error,
    keyword_export,
    keyword_extern,
    keyword_fn,
    keyword_for,
    keyword_if,
    keyword_inline,
    keyword_noalias,
    keyword_noinline,
    keyword_nosuspend,
    keyword_opaque,
    keyword_or,
    keyword_orelse,
    keyword_packed,
    keyword_pub,
    keyword_resume,
    keyword_return,
    keyword_linksection,
    keyword_struct,
    keyword_suspend,
    keyword_switch,
    keyword_test,
    keyword_threadlocal,
    keyword_try,
    keyword_true,
    keyword_false,
    keyword_union,
    keyword_unreachable,
    keyword_var,
    keyword_volatile,
    keyword_while,
    keyword_module,

    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    colon,
    semicolon,
    comma,

    // Assignment / equality
    equals,
    eq_eq,
    equal_angle_bracket_right,
    bang_equal,
    bang,

    // Comparison
    lt,
    gt,
    lt_eq,
    gt_eq,

    // Arithmetic
    plus,
    minus,
    star,
    slash,
    percent,
    plus_plus,
    plus_equal,
    plus_percent,
    plus_percent_equal,
    plus_pipe,
    plus_pipe_equal,
    minus_equal,
    minus_percent,
    minus_percent_equal,
    minus_pipe,
    minus_pipe_equal,
    star_equal,
    star_percent,
    star_percent_equal,
    star_pipe,
    star_pipe_equal,
    slash_equal,
    percent_equal,

    // Bitwise / logical
    ampersand,
    ampersand_equal,
    pipe,
    pipe_pipe,
    pipe_equal,
    caret,
    caret_equal,
    tilde,

    // Shift
    angle_bracket_angle_bracket_left,
    angle_bracket_angle_bracket_left_equal,
    angle_bracket_angle_bracket_right,
    angle_bracket_angle_bracket_right_equal,

    // Access / range
    dot,
    period_asterisk,
    ellipsis2,
    ellipsis3,
    arrow,
    question_mark,
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
        tokenizer.skipSpaceOrComment();
        if (tokenizer.index >= tokenizer.source.len) return .eof;
        const byte = tokenizer.source[tokenizer.index];

        if (byte == '@') {
            const start = tokenizer.index;
            tokenizer.index += 1;
            const ident_start = tokenizer.index;
            while (tokenizer.index < tokenizer.source.len and identContinue(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
            if (ident_start < tokenizer.index) {
                const name = tokenizer.source[ident_start..tokenizer.index];
                return .{ .builtin = name };
            }
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
            return tokenizer.lexNumber();
        }

        if (byte == '"') {
            return tokenizer.lexString();
        }

        if (byte == '\'') {
            return tokenizer.lexChar();
        }

        if (byte == '\\') {
            return tokenizer.lexMultilineStringLine();
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
            '?' => .question_mark,
            '~' => .tilde,

            '.' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '*') tok: {
                tokenizer.index += 1;
                break :tok Token{ .period_asterisk = {} };
            } else if (tokenizer.index + 1 < tokenizer.source.len and
                tokenizer.source[tokenizer.index] == '.' and
                tokenizer.source[tokenizer.index + 1] == '.')
            tok: {
                tokenizer.index += 2;
                break :tok Token{ .ellipsis3 = {} };
            } else if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '.') tok: {
                tokenizer.index += 1;
                break :tok Token{ .ellipsis2 = {} };
            } else .dot,

            '+' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '+' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .plus_plus = {} };
                },
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .plus_equal = {} };
                },
                '%' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .plus_percent_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .plus_percent = {} };
                },
                '|' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .plus_pipe_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .plus_pipe = {} };
                },
                else => .plus,
            } else .plus,

            '-' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .minus_equal = {} };
                },
                '>' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .arrow = {} };
                },
                '%' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .minus_percent_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .minus_percent = {} };
                },
                '|' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .minus_pipe_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .minus_pipe = {} };
                },
                else => .minus,
            } else .minus,

            '*' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .star_equal = {} };
                },
                '%' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .star_percent_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .star_percent = {} };
                },
                '|' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .star_pipe_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .star_pipe = {} };
                },
                else => .star,
            } else .star,

            '/' => .slash,

            '%' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .percent_equal = {} };
            } else .percent,

            '=' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .eq_eq = {} };
                },
                '>' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .equal_angle_bracket_right = {} };
                },
                else => .equals,
            } else .equals,

            '!' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .bang_equal = {} };
            } else .bang,

            '<' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .lt_eq = {} };
                },
                '<' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .angle_bracket_angle_bracket_left_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .angle_bracket_angle_bracket_left = {} };
                },
                else => .lt,
            } else .lt,

            '>' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .gt_eq = {} };
                },
                '>' => if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index + 1] == '=') tok: {
                    tokenizer.index += 2;
                    break :tok Token{ .angle_bracket_angle_bracket_right_equal = {} };
                } else tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .angle_bracket_angle_bracket_right = {} };
                },
                else => .gt,
            } else .gt,

            '&' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .ampersand_equal = {} };
            } else .ampersand,

            '|' => if (tokenizer.index < tokenizer.source.len) switch (tokenizer.source[tokenizer.index]) {
                '=' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .pipe_equal = {} };
                },
                '|' => tok: {
                    tokenizer.index += 1;
                    break :tok Token{ .pipe_pipe = {} };
                },
                else => .pipe,
            } else .pipe,

            '^' => if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '=') tok: {
                tokenizer.index += 1;
                break :tok Token{ .caret_equal = {} };
            } else .caret,

            else => .{ .invalid = tokenizer.source[tokenizer.index - 1 .. tokenizer.index] },
        };
    }

    fn lexNumber(tokenizer: *Tokenizer) Token {
        const start = tokenizer.index;
        if (tokenizer.source[tokenizer.index] == '0' and tokenizer.index + 1 < tokenizer.source.len) {
            const ch = tokenizer.source[tokenizer.index + 1];
            if (ch == 'x' or ch == 'X') {
                tokenizer.index += 2;
                while (tokenizer.index < tokenizer.source.len and isHexDigit(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
                return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
            }
            if (ch == 'b' or ch == 'B') {
                tokenizer.index += 2;
                while (tokenizer.index < tokenizer.source.len and (tokenizer.source[tokenizer.index] == '0' or tokenizer.source[tokenizer.index] == '1')) : (tokenizer.index += 1) {}
                return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
            }
            if (ch == 'o' or ch == 'O') {
                tokenizer.index += 2;
                while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] >= '0' and tokenizer.source[tokenizer.index] <= '7') : (tokenizer.index += 1) {}
                return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
            }
        }
        while (tokenizer.index < tokenizer.source.len and isDigit(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {
            if (tokenizer.index + 1 < tokenizer.source.len and tokenizer.source[tokenizer.index] == '.') {
                const after_dot = tokenizer.index + 1;
                if (after_dot < tokenizer.source.len and tokenizer.source[after_dot] == '.') {
                    // Range operator '..', stop before dot
                    return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
                }
                // Could be a float
                tokenizer.index = after_dot;
                while (tokenizer.index < tokenizer.source.len and isDigit(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
                // Check for exponent
                if (tokenizer.index < tokenizer.source.len and (tokenizer.source[tokenizer.index] == 'e' or tokenizer.source[tokenizer.index] == 'E')) {
                    tokenizer.index += 1;
                    if (tokenizer.index < tokenizer.source.len and (tokenizer.source[tokenizer.index] == '+' or tokenizer.source[tokenizer.index] == '-'))
                        tokenizer.index += 1;
                    while (tokenizer.index < tokenizer.source.len and isDigit(tokenizer.source[tokenizer.index])) : (tokenizer.index += 1) {}
                }
                return .{ .float_literal = tokenizer.source[start..tokenizer.index] };
            }
        }
        return .{ .integer_literal = tokenizer.source[start..tokenizer.index] };
    }

    fn lexString(tokenizer: *Tokenizer) Token {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] != '"') : (tokenizer.index += 1) {
            if (tokenizer.source[tokenizer.index] == '\\') tokenizer.index += 1;
        }
        if (tokenizer.index >= tokenizer.source.len) return .{ .invalid = tokenizer.source[start..tokenizer.index] };
        tokenizer.index += 1;
        return .{ .string_literal = tokenizer.source[start..tokenizer.index] };
    }

    fn lexChar(tokenizer: *Tokenizer) Token {
        const start = tokenizer.index;
        tokenizer.index += 1; // skip opening '
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '\\') {
            tokenizer.index += 1; // skip backslash
            if (tokenizer.index < tokenizer.source.len) tokenizer.index += 1; // skip escaped char
        } else if (tokenizer.index < tokenizer.source.len) {
            tokenizer.index += 1; // skip single char
        }
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '\'') {
            tokenizer.index += 1;
            return .{ .char_literal = tokenizer.source[start..tokenizer.index] };
        }
        return .{ .invalid = tokenizer.source[start..tokenizer.index] };
    }

    fn lexMultilineStringLine(tokenizer: *Tokenizer) Token {
        const start = tokenizer.index;
        tokenizer.index += 1; // skip \
        while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] != '\n' and tokenizer.source[tokenizer.index] != '\r') : (tokenizer.index += 1) {}
        // skip newline
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '\r') tokenizer.index += 1;
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '\n') tokenizer.index += 1;
        return .{ .multiline_string_literal_line = tokenizer.source[start..tokenizer.index] };
    }

    fn skipSpaceOrComment(tokenizer: *Tokenizer) void {
        while (tokenizer.index < tokenizer.source.len) {
            const byte = tokenizer.source[tokenizer.index];
            if (asciiWhitespace(byte)) {
                tokenizer.index += 1;
                continue;
            }
            if (byte == '/' and tokenizer.index + 1 < tokenizer.source.len) {
                const ch2 = tokenizer.source[tokenizer.index + 1];
                if (ch2 == '/') {
                    tokenizer.skipLineComment();
                    continue;
                }
                if (ch2 == '*') {
                    tokenizer.skipBlockComment();
                    continue;
                }
                break;
            }
            break;
        }
    }

    fn skipLineComment(tokenizer: *Tokenizer) void {
        tokenizer.index += 2;
        while (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] != '\n' and tokenizer.source[tokenizer.index] != '\r') : (tokenizer.index += 1) {}
    }

    fn skipBlockComment(tokenizer: *Tokenizer) void {
        tokenizer.index += 2;
        var depth: usize = 1;
        while (tokenizer.index < tokenizer.source.len and depth > 0) : (tokenizer.index += 1) {
            if (tokenizer.source[tokenizer.index] == '/' and
                tokenizer.index + 1 < tokenizer.source.len and
                tokenizer.source[tokenizer.index + 1] == '*')
            {
                tokenizer.index += 1;
                depth += 1;
            } else if (tokenizer.source[tokenizer.index] == '*' and
                tokenizer.index + 1 < tokenizer.source.len and
                tokenizer.source[tokenizer.index + 1] == '/')
            {
                tokenizer.index += 1;
                depth -= 1;
            }
        }
        if (depth > 0) tokenizer.index = tokenizer.source.len;
    }
};

fn isDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

fn isHexDigit(byte: u8) bool {
    return isDigit(byte) or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F');
}

fn matchKeyword(word: []const u8) ?Token {
    if (std.mem.eql(u8, word, "addrspace")) return .keyword_addrspace;
    if (std.mem.eql(u8, word, "align")) return .keyword_align;
    if (std.mem.eql(u8, word, "allowzero")) return .keyword_allowzero;
    if (std.mem.eql(u8, word, "and")) return .keyword_and;
    if (std.mem.eql(u8, word, "anyframe")) return .keyword_anyframe;
    if (std.mem.eql(u8, word, "anytype")) return .keyword_anytype;
    if (std.mem.eql(u8, word, "asm")) return .keyword_asm;
    if (std.mem.eql(u8, word, "break")) return .keyword_break;
    if (std.mem.eql(u8, word, "callconv")) return .keyword_callconv;
    if (std.mem.eql(u8, word, "catch")) return .keyword_catch;
    if (std.mem.eql(u8, word, "comptime")) return .keyword_comptime;
    if (std.mem.eql(u8, word, "const")) return .keyword_const;
    if (std.mem.eql(u8, word, "continue")) return .keyword_continue;
    if (std.mem.eql(u8, word, "defer")) return .keyword_defer;
    if (std.mem.eql(u8, word, "else")) return .keyword_else;
    if (std.mem.eql(u8, word, "enum")) return .keyword_enum;
    if (std.mem.eql(u8, word, "errdefer")) return .keyword_errdefer;
    if (std.mem.eql(u8, word, "error")) return .keyword_error;
    if (std.mem.eql(u8, word, "export")) return .keyword_export;
    if (std.mem.eql(u8, word, "extern")) return .keyword_extern;
    if (std.mem.eql(u8, word, "fn")) return .keyword_fn;
    if (std.mem.eql(u8, word, "for")) return .keyword_for;
    if (std.mem.eql(u8, word, "if")) return .keyword_if;
    if (std.mem.eql(u8, word, "inline")) return .keyword_inline;
    if (std.mem.eql(u8, word, "module")) return .keyword_module;
    if (std.mem.eql(u8, word, "noalias")) return .keyword_noalias;
    if (std.mem.eql(u8, word, "noinline")) return .keyword_noinline;
    if (std.mem.eql(u8, word, "nosuspend")) return .keyword_nosuspend;
    if (std.mem.eql(u8, word, "opaque")) return .keyword_opaque;
    if (std.mem.eql(u8, word, "or")) return .keyword_or;
    if (std.mem.eql(u8, word, "orelse")) return .keyword_orelse;
    if (std.mem.eql(u8, word, "packed")) return .keyword_packed;
    if (std.mem.eql(u8, word, "pub")) return .keyword_pub;
    if (std.mem.eql(u8, word, "resume")) return .keyword_resume;
    if (std.mem.eql(u8, word, "return")) return .keyword_return;
    if (std.mem.eql(u8, word, "linksection")) return .keyword_linksection;
    if (std.mem.eql(u8, word, "struct")) return .keyword_struct;
    if (std.mem.eql(u8, word, "suspend")) return .keyword_suspend;
    if (std.mem.eql(u8, word, "switch")) return .keyword_switch;
    if (std.mem.eql(u8, word, "test")) return .keyword_test;
    if (std.mem.eql(u8, word, "threadlocal")) return .keyword_threadlocal;
    if (std.mem.eql(u8, word, "try")) return .keyword_try;
    if (std.mem.eql(u8, word, "union")) return .keyword_union;
    if (std.mem.eql(u8, word, "unreachable")) return .keyword_unreachable;
    if (std.mem.eql(u8, word, "var")) return .keyword_var;
    if (std.mem.eql(u8, word, "volatile")) return .keyword_volatile;
    if (std.mem.eql(u8, word, "while")) return .keyword_while;
    if (std.mem.eql(u8, word, "true")) return .keyword_true;
    if (std.mem.eql(u8, word, "false")) return .keyword_false;
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
    try std.testing.expectEqualStrings("intCast", tok.next().builtin);
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
    try std.testing.expectEqual(Token.bang_equal, tok.next());
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
    try std.testing.expectEqualStrings("import", tok.next().builtin);
    try std.testing.expectEqualStrings("intFromEnum", tok.next().builtin);
    try std.testing.expectEqualStrings("intFromPtr", tok.next().builtin);
    try std.testing.expectEqual(Token.eof, tok.next());
}

test "tokenizer handles module keyword" {
    var tok = tokenize("const helper: module = @import(\"src/er/self_host/helper.er\");");
    try std.testing.expectEqual(Token.keyword_const, tok.next());
    try std.testing.expectEqualStrings("helper", tok.next().identifier);
    try std.testing.expectEqual(Token.colon, tok.next());
    try std.testing.expectEqual(Token.keyword_module, tok.next());
    try std.testing.expectEqual(Token.equals, tok.next());
    try std.testing.expectEqualStrings("import", tok.next().builtin);
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
