import 'dart:io';

class NetworkHelper {
  /// Gets the local IPv4 address of the device on the Wi-Fi network.
  static Future<String?> getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Ignored
    }
    return null;
  }
}
