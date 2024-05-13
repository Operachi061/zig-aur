const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const curl = @import("curl");
const Easy = curl.Easy;

const Data = struct {
    Description: []const u8,
    Name: []const u8,
};

const pkgdata = union(enum) {
    Data: Data,
    pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const parsed = try std.json.innerParse(std.json.Value, allocator, source, options);
        const results = parsed.object.get("Description") orelse return error.UnexpectedToken;
        const classType = std.meta.stringToEnum(std.meta.Tag(@This()), results.string) orelse undefined;
        const result = switch (classType) {
            .Data => {
                const description = parsed.object.get("Description") orelse return error.UnexpectedToken;
                const name = parsed.object.get("Name") orelse return error.UnexpectedToken;

                return pkgdata{
                    .Data = Data{
                        .Description = description.string,
                        .Name = name.string,
                    },
                };
            },
        };
        return result;
    }
};

const Response = struct {
    resultcount: u16,
    results: []pkgdata,
    type: []u8,
    version: u16,
};

var json_output: []const u8 = undefined;

const ops = std.json.ParseOptions{
    .ignore_unknown_fields = true,
};

fn fetch_json(allocator: Allocator, easy: Easy, comptime name: []const u8) !void {
    const pkgurl = "https://aur.archlinux.org/rpc/v5/search/" ++ name;
    try easy.setUrl(pkgurl);
    try easy.setMethod(.PUT);
    var buf = curl.Buffer.init(allocator);
    try easy.setWritedata(&buf);
    try easy.setWritefunction(curl.bufferWriteCallback);

    var resp = try easy.perform();
    resp.body = buf;
    defer resp.deinit();
    json_output = try std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{resp.body.?.items});
}

pub fn fetch_database(name: []const u8, database: []u8) !void {
    const allocator = std.heap.page_allocator;

    const ca_bundle = try curl.allocCABundle(allocator);
    defer ca_bundle.deinit();
    const easy = try Easy.init(allocator, .{
        .ca_bundle = ca_bundle,
    });
    defer easy.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const gpa_allocator = gpa.allocator();

    try fetch_json(allocator, easy, name);
    const parsed = try std.json.parseFromSlice(Response, gpa_allocator, json_output, ops);
    defer parsed.deinit();

    database = parsed;

    // std.debug.print("Packages found: {d}\n\n", .{parsed.value.results.len});
    // for (0..parsed.value.results.len) |i| {
    //     switch (parsed.value.results[i]) {
    //         .Data => |data| {
    //             std.debug.print("Package name: {s}\n", .{data.Name});
    //             std.debug.print("Description: {s}\n\n", .{data.Description});
    //         },
    //     }
    // }
}
