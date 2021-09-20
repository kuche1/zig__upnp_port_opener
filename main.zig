
// zig run main.zig -lc -lminiupnpc

// https://gist.github.com/fsmv/389de500ddac60c52a7d

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("arpa/inet.h");
    @cInclude("miniupnpc/miniupnpc.h");
    @cInclude("miniupnpc/upnpcommands.h");
});

const std = @import("std");
const echo = std.debug.print;


pub fn main() !void {

    var err: c_int = 0;

    //get a list of upnp devices (asks on the broadcast address and returns the responses)
    const upnp_dev: ?*c.UPNPDev = c.upnpDiscover(
        1_000, //timeout in milliseconds
        null, //multicast address, default = "239.255.255.250"
        null, //minissdpd socket, default = "/var/run/minissdpd.sock"
        0, //source port, default = 1900
        0, //0 = IPv4, 1 = IPv6
        50, // ttl
        &err, //error output (not?)
    );
    defer c.freeUPNPDevlist(upnp_dev);

    if(upnp_dev == null or err != 0) return error.couldnt_discover_upnp_device;


    var zig_lan_address: [c.INET6_ADDRSTRLEN]u8 = undefined;
    const lan_address: [*c]u8 = &zig_lan_address;
    var upnp_urls: c.UPNPUrls = undefined;
    var upnp_data: c.IGDdatas = undefined;
    const status: c_int = c.UPNP_GetValidIGD(
        upnp_dev,
        &upnp_urls,
        &upnp_data,
        lan_address,
        @sizeOf(@TypeOf(zig_lan_address)),
    );
    defer c.FreeUPNPUrls(&upnp_urls);

    if(status != 1) {
        // 0 = NO IGD found
        // 1 = A valid connected IGD has been found
        // 2 = A valid IGD has been found but it reported as not connected
        // 3 = an UPnP device has been found but was not recognized as an IGD
        if(status == 2){
            echo("ignoring error...\n", .{});
        }else{
            return error.no_valid_internet_gateway_device_could_be_connected_to;
        }
    }


    var zig_wan_address: [c.INET6_ADDRSTRLEN]u8 = undefined;
    const wan_address: [*c] u8 = &zig_wan_address;
    const servicetype: [*c]const u8 = &upnp_data.first.servicetype;
    if(c.UPNP_GetExternalIPAddress(upnp_urls.controlURL, servicetype, wan_address) != 0){
        return error.cant_get_external_ip;
    }else{
        echo("external ip: {s}\n", .{wan_address});
    }


    // add a new TCP port mapping from WAN port 12345 to local host port 24680
    err = c.UPNP_AddPortMapping(
        upnp_urls.controlURL,
        servicetype,
        "12345", // external (WAN) port requested
        "24680", // internal (LAN) port to which packets will be redirected
        lan_address, // internal (LAN) address to which packets will be redirected
        "lol wtf", // text description to indicate why or who is responsible for the port mapping
        "TCP", // protocol must be either TCP or UDP
        null, // remote (peer) host address or nullptr for no restriction
        "86400", // port map lease duration (in seconds) or zero for "as long as possible"
    );

    if(err != 0) return error.failed_to_map_ports;


}


