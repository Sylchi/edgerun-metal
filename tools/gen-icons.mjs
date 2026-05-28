import { readdirSync, writeFileSync } from 'fs';
import { join } from 'path';

const svgDir = 'edgerun-zig/src/icons/tabler';
const outIcon = 'edgerun-zig/src/icon.zig';
const outEmbed = 'edgerun-zig/src/icon_embed.zig';

const files = readdirSync(svgDir)
  .filter(f => f.endsWith('.svg'))
  .map(f => f.slice(0, -4))
  .sort();

function toVariant(name) {
  let r = '';
  let i = 0;
  if (name.length > 0 && name[0] >= '0' && name[0] <= '9') {
    r += '_';
  }
  while (i < name.length) {
    const c = name[i];
    if (c === '-') {
      r += '_';
    } else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c === '_') {
      r += c;
    } else {
      r += '_';
    }
    i++;
  }
  return r;
}

// Generate icon.zig
let iconZig = `const std = @import("std");

pub const Icon = enum(u16) {
`;

for (let i = 0; i < files.length; i++) {
  iconZig += `    ${toVariant(files[i])}`;
  if (i < files.length - 1) iconZig += ',';
  iconZig += '\n';
}

iconZig += `};

pub const Provider = enum {
    lucide,
    tabler,
};

pub fn tablerName(value: Icon) []const u8 {
    return switch (value) {
`;

for (const name of files) {
  iconZig += `        .${toVariant(name)} => "${name}",\n`;
}

iconZig += `    };
}

pub fn label(value: Icon) []const u8 {
    return tablerName(value);
}

pub fn id(value: Icon) u32 {
    return @as(u32, @intFromEnum(value)) + 1;
}

pub fn fromId(icon_id: u32) ?Icon {
    if (icon_id == 0 or icon_id > @typeInfo(Icon).@"enum".fields.len) return null;
    return @enumFromInt(icon_id - 1);
}

pub fn providerName(value: Icon, provider: Provider) []const u8 {
    _ = provider;
    return tablerName(value);
}

test "icon ids are stable and one based" {
    const count = @typeInfo(Icon).@"enum".fields.len;
    try std.testing.expectEqual(@as(u32, 1), id(@enumFromInt(0)));
    try std.testing.expectEqual(@as(u32, @intCast(count)), id(@enumFromInt(count - 1)));
    try std.testing.expect(id(@enumFromInt(0)) > 0);
    try std.testing.expect(fromId(0) == null);
    try std.testing.expect(fromId(@as(u32, @intCast(count + 1))) == null);
}

test "every icon has a label" {
    inline for (std.meta.fields(Icon)) |field| {
        const value: Icon = @enumFromInt(field.value);
        try std.testing.expect(label(value).len > 0);
    }
}
`;

writeFileSync(outIcon, iconZig, 'utf8');
console.log(`Wrote ${outIcon} (${files.length} icons)`);

// Generate embed file
let embedZig = `const icon = @import("icon.zig");

pub fn source(value: icon.Icon) []const u8 {
    return switch (value) {
`;

for (const name of files) {
  embedZig += `        .${toVariant(name)} => @embedFile("icons/tabler/${name}.svg"),\n`;
}

embedZig += `    };
}

test "all mapped tabler svgs parse without invalid path data" {
    const icon_svg = @import("icon_svg.zig");
    inline for (std.meta.fields(icon.Icon)) |field| {
        var iter = icon_svg.Iterator.init(source(@enumFromInt(field.value)));
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count > 0);
    }
}

test "all mapped tabler svgs match supported stroke contract" {
    const icon_svg = @import("icon_svg.zig");
    inline for (std.meta.fields(icon.Icon)) |field| {
        try icon_svg.validateSupportedTablerStroke(source(@enumFromInt(field.value)));
    }
}
`;

writeFileSync(outEmbed, embedZig, 'utf8');
console.log(`Wrote ${outEmbed}`);
