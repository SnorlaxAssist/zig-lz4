const std = @import("std");

const c = @cImport({
    @cInclude("lz4.h");
    @cInclude("lz4frame.h");
});

const Allocator = std.mem.Allocator;

/// 2113929216
pub const MAX_INPUT_SIZE = c.LZ4_MAX_INPUT_SIZE;
/// 20
pub const MEMORY_USAGE_MAX = c.LZ4_MEMORY_USAGE_MAX;

pub fn getVersion() []const u8 {
    return std.mem.span(c.LZ4_versionString());
}

pub fn getVersionNumber() i32 {
    return @intCast(c.LZ4_versionNumber());
}

pub const Standard = struct {
    const CompressionError = error {
        Failed,
    };

    const DecompressionError = error {
        Failed,
    };

    pub fn compressBound(size: usize) usize {
        return @intCast(c.LZ4_compressBound(@intCast(size)));
    }

    pub fn compressDefault(src: [*]const u8, srcLen : usize, dest: [*]u8, destLen : usize) !usize {
        const compressedSize = c.LZ4_compress_default(src, dest, @intCast(srcLen), @intCast(destLen));
        if (compressedSize == 0) {
            return CompressionError.Failed;
        }
        return @intCast(compressedSize);
    }

    pub fn decompressSafe(src: [*]const u8, srcLen : usize, dest: [*]u8, destLen : usize) !usize {
        const decompressedSize = c.LZ4_decompress_safe(src, dest, @intCast(srcLen), @intCast(destLen));
        if (decompressedSize < 0) {
            return DecompressionError.Failed;
        }
        return @intCast(decompressedSize);
    }

    pub fn compress(allocator: Allocator, src: []const u8) ![]const u8 {
        const destSize = compressBound(src.len);
        const dest = try allocator.alloc(u8, destSize);
        errdefer allocator.free(dest);
        const compressedSize = try compressDefault(src.ptr, src.len, dest.ptr, destSize);
        return try allocator.realloc(dest, compressedSize);
    }

    pub fn decompress(allocator: Allocator, src: []const u8, szHint : usize) ![]const u8 {
        const dest = try allocator.alloc(u8, szHint);
        errdefer allocator.free(dest);
        const decompressedSize = try decompressSafe(src.ptr, src.len, dest.ptr, szHint);
        return try allocator.realloc(dest, decompressedSize);
    }
};

pub const Frame = struct {
    pub const Context = c.LZ4F_cctx;
    pub const Preferences = c.LZ4F_preferences_t;
    pub const CompressOptions = c.LZ4F_compressOptions_t;

    pub const Error = error {
        Generic,
        MaxBlockSizeInvalid,
        BlockModeInvalid,
        ParameterInvalid,
        CompressionLevelInvalid,
        HeaderVersionWrong,
        BlockChecksumInvalid,
        ReservedFlagSet,
        AllocationFailed,
        SrcSizeTooLarge,
        DstMaxSizeTooSmall,
        FrameHeaderIncomplete,
        FrameTypeUnknown,
        FrameSizeWrong,
        SrcPtrWrong,
        DecompressionFailed,
        HeaderChecksumInvalid,
        ContentChecksumInvalid,
        FrameDecodingAlreadyStarted,
        CompressionStateUninitialized,
        ParameterNull,
        IoWrite,
        IoRead,
        MaxCode,
    };

    pub const BlockSize = enum(c_uint) {
        Default = c.LZ4F_default,
        Max64KB = c.LZ4F_max64KB,
        Max256KB = c.LZ4F_max256KB,
        Max1MB = c.LZ4F_max1MB,
        Max4MB = c.LZ4F_max4MB,
    };

    pub const BlockMode = enum(c_uint) {
        Linked = c.LZ4F_blockLinked,
        Independent = c.LZ4F_blockIndependent,
    };

    pub const ContentChecksum = enum(c_uint) {
        Enabled = c.LZ4F_contentChecksumEnabled,
        Disabled = c.LZ4F_noContentChecksum,
    };

    pub const BlockChecksum = enum(c_uint) {
        Enabled = c.LZ4F_blockChecksumEnabled,
        Disabled = c.LZ4F_noBlockChecksum,
    };

    pub const FrameType = enum(c_uint) {
        Frame = c.LZ4F_frame,
        SkippableFrame = c.LZ4F_skippableFrame,
    };

    fn doError(result : usize) !void {
        const code : usize = @intCast(-@as(isize, @bitCast(result)) - 1);
        switch (code) {
            0 => return Error.Generic,
            1 => return Error.MaxBlockSizeInvalid,
            2 => return Error.BlockModeInvalid,
            3 => return Error.ParameterInvalid,
            4 => return Error.CompressionLevelInvalid,
            5 => return Error.HeaderVersionWrong,
            6 => return Error.BlockChecksumInvalid,
            7 => return Error.ReservedFlagSet,
            8 => return Error.AllocationFailed,
            9 => return Error.SrcSizeTooLarge,
            10 => return Error.DstMaxSizeTooSmall,
            11 => return Error.FrameHeaderIncomplete,
            12 => return Error.FrameTypeUnknown,
            13 => return Error.FrameSizeWrong,
            14 => return Error.SrcPtrWrong,
            15 => return Error.DecompressionFailed,
            16 => return Error.HeaderChecksumInvalid,
            17 => return Error.ContentChecksumInvalid,
            18 => return Error.FrameDecodingAlreadyStarted,
            19 => return Error.CompressionStateUninitialized,
            20 => return Error.ParameterNull,
            21 => return Error.IoWrite,
            22 => return Error.IoRead,
            23 => return Error.MaxCode,
            else => return Error.Generic,
        }
    }

    pub fn compressBound(size: usize, pref : *const Preferences) usize {
        return c.LZ4F_compressBound(@intCast(size), pref);
    }

    pub fn compressBegin(ctx: *Context, dstBuffer : [*]u8, dstCapacity: usize, prefsPtr : ?*const Preferences) !usize {
        const res = c.LZ4F_compressBegin(ctx, @ptrCast(dstBuffer), dstCapacity, prefsPtr);
        if (c.LZ4F_isError(res) != 0) {
            try doError(res);
        }
        return res;
    }
    
    pub fn compressUpdate(ctx: *Context, dstBuffer : [*]u8, dstCapacity: usize, srcBuffer : [*]const u8, srcSize: usize, cOptionsPtr : ?*const CompressOptions) !usize {
        const res = c.LZ4F_compressUpdate(ctx, @ptrCast(dstBuffer), dstCapacity, @ptrCast(srcBuffer), srcSize, cOptionsPtr);
        if (c.LZ4F_isError(res) != 0) {
            try doError(res);
        }
        return res;
    }

    pub fn compressEnd(ctx: *Context, dstBuffer : [*]u8, dstCapacity: usize, cOptionsPtr : ?*const CompressOptions) !usize {
        const res = c.LZ4F_compressEnd(ctx, @ptrCast(dstBuffer), dstCapacity, cOptionsPtr);
        if (c.LZ4F_isError(res) != 0) {
            try doError(res);
        }
        return res;
    }

    pub fn createCompressionContext(allocator: Allocator, versionNumber : ?i32) !**c.LZ4F_cctx {
        const ctxPtr = try allocator.create(*c.LZ4F_cctx);
        errdefer allocator.destroy(ctxPtr);
        const res = c.LZ4F_createCompressionContext(@ptrCast(ctxPtr), @intCast(versionNumber orelse getVersionNumber()));
        if (res != 0) {
            try doError(res);
        }
        return ctxPtr;
    }

    pub fn freeCompressionContext(allocator: Allocator, ctx: **c.LZ4F_cctx) void {
        _ = c.LZ4F_freeCompressionContext(ctx.*);
        allocator.destroy(ctx);
    }
};

const INPUT_CHUNK_SIZE = 64 * 1024;

const ResizableWriteError = error{NoSpaceLeft};
const ResizableBufferStream = struct {
    allocator : Allocator = undefined,
    buffer: []u8,
    pos: usize,

    const Self = @This();

    pub const Writer = std.io.Writer(*Self, ResizableWriteError, write);

    pub fn init(allocator : Allocator) !ResizableBufferStream {
        const buffer = try allocator.alloc(u8, 0);
        return .{
            .allocator = allocator,
            .buffer = buffer,
            .pos = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn getPos(self: *Self) usize {
        return self.pos;
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self};
    }

    pub fn write(self: *Self, bytes : []const u8) !usize {
        const pos = self.pos;
        if (bytes.len == 0) return 0;

        const n = bytes.len;
        if (pos + n > self.buffer.len) self.buffer = self.allocator.realloc(self.buffer, pos + n) catch {
            return error.NoSpaceLeft;
        };

        @memcpy(self.buffer[pos..][0..n], bytes[0..n]);
        self.pos += n;

        return n;
    }
};

pub const Encoder = struct {
    allocator : Allocator = undefined,
    ctx : **c.LZ4F_cctx = undefined,
    writer : []u8 = undefined,

    level : u32 = 0,
    blockSize : Frame.BlockSize = Frame.BlockSize.Default,
    blockMode : Frame.BlockMode = Frame.BlockMode.Linked,
    contentChecksum : Frame.ContentChecksum = Frame.ContentChecksum.Enabled,
    blockChecksum : Frame.BlockChecksum = Frame.BlockChecksum.Disabled,
    frameType : Frame.FrameType = Frame.FrameType.Frame,
    favorDecSpeed : bool = false,
    autoFlush : bool = false,

    pub fn init(alloc : Allocator) !Encoder {
        const ctxPtr = try Frame.createCompressionContext(alloc, null);
        return .{
            .allocator = alloc,
            .ctx = ctxPtr,
        };
    }

    fn setLevel(encoder : *Encoder, level : u32) *Encoder {
        encoder.level = level;
        return encoder;
    }

    fn setBlockSize(encoder : *Encoder, blockSize : Frame.BlockSize) *Encoder {
        encoder.blockSize = blockSize;
        return encoder;
    }

    fn setBlockMode(encoder : *Encoder, blockMode : Frame.BlockMode) *Encoder {
        encoder.blockMode = blockMode;
        return encoder;
    }

    fn setContentChecksum(encoder : *Encoder, contentChecksum : Frame.ContentChecksum) *Encoder {
        encoder.contentChecksum = contentChecksum;
        return encoder;
    }

    fn setBlockChecksum(encoder : *Encoder, blockChecksum : Frame.BlockChecksum) *Encoder {
        encoder.blockChecksum = blockChecksum;
        return encoder;
    }

    fn setFrameType(encoder : *Encoder, frameType : Frame.FrameType) *Encoder {
        encoder.frameType = frameType;
        return encoder;
    }

    fn setAutoFlush(encoder : *Encoder, autoFlush : bool) *Encoder {
        encoder.autoFlush = if (autoFlush) 1 else 0;
        return encoder;
    }

    fn setFavorDecSpeed(encoder : *Encoder, favorDecSpeed : bool) *Encoder {
        encoder.favorDecSpeed = if (favorDecSpeed) 1 else 0;
        return encoder;
    }

    fn deinit(encoder : Encoder) void {
        Frame.freeCompressionContext(encoder.allocator, encoder.ctx);
    }

    fn compressStream(encoder : *Encoder, streamWriter : std.io.AnyWriter, src : []const u8) !void {
        const pref = Frame.Preferences{
            .compressionLevel = 0,
            .frameInfo = .{
                .blockSizeID = @intFromEnum(encoder.blockSize),
                .blockMode = @intFromEnum(encoder.blockMode),
                .contentChecksumFlag = @intFromEnum(encoder.contentChecksum),
                .blockChecksumFlag = @intFromEnum(encoder.blockChecksum),
                .frameType = @intFromEnum(encoder.frameType),
                .dictID = 0,
            },
            .reserved = [3]c_uint{0,0,0},
            .autoFlush = if (encoder.autoFlush) 1 else 0,
            .favorDecSpeed = if (encoder.favorDecSpeed) 1 else 0,
        };
        const ctx = encoder.ctx.*;
        const bound = Frame.compressBound(src.len, &pref);

        const writer = try encoder.allocator.alloc(u8, bound);
        defer encoder.allocator.free(writer);

        const startRes = try Frame.compressBegin(ctx, writer.ptr, bound, &pref);
        try streamWriter.writeAll(writer[0..startRes]);

        var offset : usize = 0;
        while (offset < src.len) {
            const readSize = @min(src.len - offset, INPUT_CHUNK_SIZE);
            const updateLen = try Frame.compressUpdate(ctx, writer.ptr, bound, src[offset..].ptr, readSize, null);
            if (updateLen == 0) break;
            try streamWriter.writeAll(writer[0..updateLen]);
            offset += readSize;
        }

        const endRes = try Frame.compressEnd(ctx, writer.ptr, bound, null);
        try streamWriter.writeAll(writer[0..endRes]);
    }

    fn compress(encoder : *Encoder, src : []const u8) ![]const u8 {
        const allocator = encoder.allocator;
      
        var buffStream = try ResizableBufferStream.init(allocator);
        errdefer buffStream.deinit();
        const buffWriter = buffStream.writer().any();

        try encoder.compressStream(buffWriter, src);

        return buffStream.buffer;
    }
};

// TODO: write Frame decoder and tests
pub const Decoder = struct {
    
};

const testing = std.testing;
test "version" {
    try testing.expectEqual(10904, getVersionNumber());
    try testing.expectEqualStrings("1.9.4", getVersion());
}

test "create compression context error OutOfMemory" {
    const allocator = testing.failing_allocator;
    const ctxPtr = Frame.createCompressionContext(allocator, null) catch |err| {
        try testing.expectEqual(error.OutOfMemory, err);
        return;
    };
    Frame.freeCompressionContext(allocator, ctxPtr);
    @panic("expected error");
}

test "frame compression 112k sample" {
    const allocator = testing.allocator;
    const sampleText = try std.fs.cwd().readFileAlloc(allocator, "./files/112k-sample.txt", std.math.maxInt(usize));
    defer allocator.free(sampleText);

    var encoder = try Encoder.init(allocator);
        _ = encoder.setLevel(16)
        .setContentChecksum(Frame.ContentChecksum.Enabled)
        .setBlockMode(Frame.BlockMode.Independent);
    defer Encoder.deinit(encoder);

    const compressed = try encoder.compress(sampleText);
    defer allocator.free(compressed);

    const expectedCompressed = try std.fs.cwd().readFileAlloc(allocator, "./files/112k-compressed-expected.txt", std.math.maxInt(usize));
    defer allocator.free(expectedCompressed);
    try testing.expectEqualStrings(expectedCompressed, compressed);
}

test "frame compression 1k sample" {
    const allocator = testing.allocator;
    const sampleText = try std.fs.cwd().readFileAlloc(allocator, "./files/1k-sample.txt", std.math.maxInt(usize));
    defer allocator.free(sampleText);

    var encoder = try Encoder.init(allocator);
        _ = encoder.setLevel(16)
        .setContentChecksum(Frame.ContentChecksum.Enabled)
        .setBlockMode(Frame.BlockMode.Independent);
    defer Encoder.deinit(encoder);

    const compressed = try encoder.compress(sampleText);
    defer allocator.free(compressed);

    const expectedCompressed = try std.fs.cwd().readFileAlloc(allocator, "./files/1k-compressed-expected.txt", std.math.maxInt(usize));
    defer allocator.free(expectedCompressed);
    try testing.expectEqualStrings(expectedCompressed, compressed);
}

test "standard compression & decompression" {
    const sample = "\nLorem ipsum dolor sit amet, consectetur adipiscing elit";

    const allocator = testing.allocator;
    const compressed = try Standard.compress(allocator, sample);
    defer allocator.free(compressed);

    const expectedCompressed = try std.fs.cwd().readFileAlloc(allocator, "./files/basic-compressed-expected.txt", std.math.maxInt(usize));
    defer allocator.free(expectedCompressed);

    try testing.expectEqualStrings(expectedCompressed, compressed);

    const decompressed = try Standard.decompress(allocator, compressed, sample.len);
    defer allocator.free(decompressed);

    try testing.expectEqualStrings(sample, decompressed);
}
