# zig-lz4

![zig-version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FSnorlaxAssist%2Fzig-lz4%2Fmaster%2F.github%2Fworkflows%2Ftests.yml&query=%24.jobs.test.steps%5B1%5D.with.version&label=zig-version)
[![tests](https://github.com/SnorlaxAssist/zig-lz4/actions/workflows/tests.yml/badge.svg)](https://github.com/SnorlaxAssist/zig-lz4/actions/workflows/tests.yml)

Unofficial Zig bindings for [LZ4](https://github.com/lz4/lz4).

## Features
- LZ4 & LZ4Frame Compression
- LZ4 & LZ4Frame Decompression
- [Encoder](https://snorlaxassist.github.io/zig-lz4/#docs.Encoder) (based on LZ4Frame)
- [Decoder](https://snorlaxassist.github.io/zig-lz4/#docs.Encoder) (based on LZ4Frame)

## Installation
1. Add dependency to `build.zig.zon`
```
zig fetch --save https://github.com/SnorlaxAssist/zig-lz4/archive/refs/heads/master.tar.gz
```
2. Add module in `build.zig`
```zig
const ziglz4 = b.dependency("zig-lz4", .{
    .target = target,
    .optimize = optimize,
});
exe.addModule("lz4", ziglz4.module("zig-lz4"));
```

## Documentation
[Link](https://snorlaxassist.github.io/zig-lz4/)

## Examples

### File [Encoder](https://snorlaxassist.github.io/zig-lz4/#docs.Encoder)
```zig
const std = @import("std");

const allocator = ...;

var encoder = try Encoder.init(allocator);
    _ = encoder.setLevel(4)
    .setContentChecksum(Frame.ContentChecksum.Enabled)
    .setBlockMode(Frame.BlockMode.Independent);
defer encoder.deinit();

const input = "Sample Text";

// Compress input
const compressed = try encoder.compress(input);
defer allocator.free(compressed);

// Allocate memory for the output file with space for the size hint
const fileOutput = try allocator.alloc(u8, compressed.len + 4);
defer allocator.free(fileOutput);

// Add size hint to the header of the file
const sizeHintHeader : [4]u8 = @bitCast(@as(u32, @intCast(input.len)));
// Write the size hint and the compressed data to the file output
@memcpy(fileOutput[0..4], sizeHintHeader[0..4]);
// Write the compressed data to the file output
@memcpy(fileOutput[4..][0..compressed.len], compressed[0..]);

// Write the compressed file to workspace
try std.fs.cwd().writeFile("compressedFile", fileOutput);
```

### File [Decoder](https://snorlaxassist.github.io/zig-lz4/#docs.Encoder)
```zig
const std = @import("std");

const allocator = ...;

var decoder = try Decoder.init(allocator);
defer decoder.deinit();

// Read the compressed file
const fileInput = try std.fs.cwd().readFileAlloc(allocator, "compressedFile", std.math.maxInt(usize));
defer allocator.free(fileInput);

// Read the size hint from the header of the file
const sizeHint = std.mem.bytesAsSlice(u32, fileInput[0..4])[0];
// Decompress the compressed data
const decompressed = try decoder.decompress(fileInput[4..], sizeHint);
defer allocator.free(decompressed);

std.debug.print("Decompressed: {s}\n", .{decompressed});
```

### Simple [Compression & Decompression](https://snorlaxassist.github.io/zig-lz4/#docs.Standard)
```zig
const std = @import("std");

const allocator = ...;

const input = "Sample Text";

// Compression
const compressed = try Standard.compress(allocator, input);
defer allocator.free(compressed);

std.debug.print("Compressed: {s}\n", .{compressed});

// Decompression
const decompressed = try Standard.decompress(allocator, compressed, input.len);
defer allocator.free(decompressed);

std.debug.print("Decompressed: {s}\n", .{decompressed});
```
