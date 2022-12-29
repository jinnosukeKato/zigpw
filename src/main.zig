const std = @import("std");
const time = std.time;
const mem = std.mem;
const Allocator = mem.Allocator;
const fmt = std.fmt;
const DefaultPrng = std.rand.DefaultPrng;

const IlligalArgumentsError = error{
    TooManyArguments,
    InvalidArguments,
};

pub fn main() !void {
    const allocator: Allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit(); // 内部バッファを解放

    const stdout = std.io.getStdOut().writer();

    var count: usize = 0;
    var len: usize = 16;
    // while with optional 結果がnullだと離脱する
    while (args.next()) |arg| : (count += 1) {
        switch (count) {
            0 => continue,
            1 => {
                if (mem.eql(u8, arg, "-n")) {
                    continue;
                } else {
                    return IlligalArgumentsError.InvalidArguments;
                }
            },
            2 => len = try fmt.parseUnsigned(usize, arg, 0),
            else => return IlligalArgumentsError.TooManyArguments,
        }
    }

    if (len <= 0) {
        return;
    }

    // アロケーター使ってメモリ確保
    const buff = try allocator.alloc(u8, len); // メモリ確保
    defer allocator.free(buff); // deferによってこのスコープを抜けるとメモリが解放

    generateWithCsprng(buff);
    try stdout.print("{s}", .{buff});
}

// 0x21 から 0x7E が使用する文字 で、 0x7E-0x21=93
// PRNG でu64の範囲の乱数を生成し、それを 93 + 1 の余剰で 0-93 の範囲に収め、
// 0x21 を加算してランダムなコードポイントを生成する
fn generate(buff: []u8) void {
    var prng = DefaultPrng.init(@intCast(u64, time.milliTimestamp()));

    var c: usize = 0;
    while (c < buff.len) : (c += 1) {
        const rand = prng.next();
        const point = rand % (93 + 1) + 0x21;
        buff[c] = @intCast(u8, point);
    }
}

fn generateWithCsprng(buff: []u8) void {
    var prng = DefaultPrng.init(@intCast(u64, time.milliTimestamp()));
    var cs_seed: [32]u8 = undefined;
    prng.fill(&cs_seed);
    var csprng = std.rand.DefaultCsprng.init(cs_seed);

    var c: usize = 0;
    while (c < buff.len) : (c += 1) {
        buff[c] = csprng.random().intRangeAtMost(u8, 0x21, 0x7E);
    }
}

test "expect all character code points to range in 0x21 to 0x7E" {
    const allocator: Allocator = std.heap.page_allocator;
    const buff = try allocator.alloc(u8, 64); // メモリ確保
    defer allocator.free(buff); // deferによってこのスコープを抜けるとメモリが解放

    generateWithCsprng(buff);

    for (buff) |c| {
        try std.testing.expect((c >= 0x21) and (c <= 0x7E));
    }
}
