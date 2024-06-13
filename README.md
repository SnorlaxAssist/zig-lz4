# zig-lz4

![zig-version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FSnorlaxAssist%2Fzig-lz4%2Fmaster%2F.github%2Fworkflows%2Ftests.yml&query=%24.jobs.test.steps%5B1%5D.with.version&label=zig-version)
[![tests](https://github.com/SnorlaxAssist/zig-lz4/actions/workflows/tests.yml/badge.svg)](https://github.com/SnorlaxAssist/zig-lz4/actions/workflows/tests.yml)

Unofficial Zig bindings for [LZ4](https://github.com/lz4/lz4).
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
## Usage
### TODO
