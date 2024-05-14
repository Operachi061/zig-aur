const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const curl = @import("curl");
const Easy = curl.Easy;

const Data = struct {
    Description: []const u8,
    Name: []const u8,
    URLPath: []const u8,
    Version: []const u8,
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
                const urlpath = parsed.object.get("URLPath") orelse return error.UnexpectedToken;
                const version = parsed.object.get("Version") orelse return error.UnexpectedToken;

                return pkgdata{
                    .Data = Data{
                        .Description = description.string,
                        .Name = name.string,
                        .URLPath = try std.fmt.allocPrint(std.heap.page_allocator, "https://aur.archlinux.org{s}", .{urlpath.string}),
                        .Version = version.string,
                    },
                };
            },
        };
        return result;
    }
};

pub const Response = struct {
    resultcount: u16,
    results: []pkgdata,
    type: []u8,
    version: u16,
};

pub var json_output: []const u8 = undefined;

pub const ops = std.json.ParseOptions{
    .ignore_unknown_fields = true,
};

fn fetch_json(allocator: Allocator, easy: Easy, name: []u8) !void {
    var buffer: [100]u8 = undefined;
    const pkgurl: [:0]u8 = try std.fmt.bufPrintZ(&buffer, "https://aur.archlinux.org/rpc/v5/search/{s}", .{name});
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

pub const get_pkgdata = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    pub const global_allocator = gpa.allocator();

    pub fn fetch_database(name: []u8) !void {
        const allocator = std.heap.page_allocator;
        const ca_bundle = try curl.allocCABundle(allocator);
        defer ca_bundle.deinit();
        const easy = try Easy.init(allocator, .{
            .ca_bundle = ca_bundle,
        });
        defer easy.deinit();
        try fetch_json(allocator, easy, name);
    }
};
