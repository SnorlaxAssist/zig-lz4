const std = @import("std");

const c = @cImport({
    @cInclude("lz4.h");
    @cInclude("lz4frame.h");
});

const Allocator = std.mem.Allocator;

pub const MAX_INPUT_SIZE = c.LZ4_MAX_INPUT_SIZE;
pub const MEMORY_USAGE_MAX = c.LZ4_MEMORY_USAGE_MAX;

const CompressionError = std.mem.Allocator.Error || error {
    FailedToCompress,
    // Frame
    FailedToCreateContext,
    FailedToStartFrame,
    FailedToEndFrame,
};

const testing = std.testing;

pub fn getVersion() []const u8 {
    return std.mem.span(c.LZ4_versionString());
}

pub fn getVersionNumber() i32 {
    return @intCast(c.LZ4_versionNumber());
}

pub fn regularCompress(allocator: Allocator, source: []const u8) ![]const u8 {
    const destSize = c.LZ4_compressBound(@intCast(source.len));
    const dest = try allocator.alloc(u8, @intCast(destSize));
    defer allocator.free(dest);
    const compressedSize = c.LZ4_compress_default(source.ptr, dest.ptr, @intCast(source.len), destSize);
    if (compressedSize == 0) {
        return CompressionError.FailedToCompress;
    }
    const out = try allocator.dupe(u8, dest[0..@intCast(compressedSize)]);
    return out;
}

pub fn regularDecompress(allocator: Allocator, source: []const u8) ![]const u8 {
    const destSize = c.LZ4_decompress(@intCast(source.len));
    const dest = try allocator.alloc(u8, @intCast(destSize));
    defer allocator.free(dest);
    const compressedSize = c.LZ4_compress_default(source.ptr, dest.ptr, @intCast(source.len), destSize);
    if (compressedSize == 0) {
        return CompressionError.FailedToCompress;
    }
    const out = try allocator.dupe(u8, dest[0..@intCast(compressedSize)]);
    return out;
}

pub const Encoder = struct {
    allocator : Allocator = undefined,
    pub fn init(alloc : Allocator) Encoder {
        return Encoder{
            .allocator = alloc
        };
    }

    pub fn Encode(encoder : Encoder, src: []const u8) ![]const u8 {
        const pref = c.LZ4F_preferences_t{
            .compressionLevel = 4,
        };
        const ctx = .c.LZ4F_cctx{};
        defer encoder.allocator.free(ctx);
        const ctxPtr = try encoder.allocator.create(*c.LZ4F_cctx);
        ctxPtr.* = ctx;
        if (c.LZ4F_createCompressionContext(@ptrCast(ctxPtr), @intCast(getVersionNumber())) != 0) return CompressionError.FailedToCreateContext;
        defer _ = c.LZ4F_freeCompressionContext(ctx);

        const bound = c.LZ4F_compressBound(src.len, &pref);

        var buffer = try encoder.allocator.alloc(u8, bound);

        const startRes = c.LZ4F_compressBegin(ctx, @ptrCast(&buffer), @intCast(bound), &pref);
        if (c.LZ4F_isError(startRes) == 1) return CompressionError.FailedToStartFrame;

        var updateCode : ?usize = null;
        while (updateCode == null or updateCode != 0) {
            updateCode = c.LZ4F_compressUpdate(ctx, @ptrCast(&buffer), @intCast(bound), @ptrCast(&src), @intCast(src.len), @ptrCast(ctxPtr));
            if (c.LZ4F_isError(updateCode.?) == 1) return CompressionError.FailedToCompress;
        }

        const endRes = c.LZ4F_compressEnd(ctx, @ptrCast(&buffer), @intCast(bound), @ptrCast(ctxPtr));
        if (c.LZ4F_isError(endRes) == 1) return CompressionError.FailedToEndFrame;

        return buffer;
    }
};

test "version" {
    // try testing.expect(add(3, 7) == 10);
    try testing.expectEqual(10904, getVersionNumber());
    try testing.expectEqualStrings("1.9.4", getVersion());
}

test "standard compression & decompression" {
    const sample = 
        \\
        \\Lorem ipsum dolor sit amet, consectetur adipiscing elit
    ;
    std.debug.print("sample: {s}\n", .{sample});

    const allocator = std.testing.allocator;
    const compressed = try regularCompress(allocator, sample);
    defer allocator.free(compressed);
    std.debug.print("compressed: {s}\n", .{compressed});
}

test "Encoder" {
    const encoder = Encoder.init(std.testing.allocator);

    const buffer = try encoder.Encode("test");
    try std.testing.expectEqualStrings("test", buffer);
}