import 'dart:io';

class NetworkHelper {
  static bool _isRealNetworkIp(String ip) {
    if (ip.startsWith('10.111.')) return false;
    if (ip.startsWith('10.112.')) return false;
    if (ip.startsWith('169.254.')) return false;
    if (ip == '10.0.2.15') return false;
    return true;
  }

  static bool _isPreferred(String ip) {
    return ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.');
  }

  /// Gets the local IPv4 address for LAN/Hotspot connections.
  static Future<String?> getLocalIpAddress() async {
    try {
      String? fallback;
      for (var interface in await NetworkInterface.list()) {
        final name = interface.name.toLowerCase();
        if (name.contains('loopback') || name.contains('vmnet') || name.contains('vethernet')) continue;
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && _isRealNetworkIp(addr.address)) {
            if (_isPreferred(addr.address)) return addr.address;
            fallback ??= addr.address;
          }
        }
      }
      return fallback;
    } catch (e) {
      return null;
    }
  }
}


