import 'dart:io';
import 'package:logger/logger.dart';

/// Utility class for IP address operations
class IPUtils {
  static final Logger _logger = Logger();

  /// Returns true if this is a real network IP (not a Windows virtual adapter)
  static bool _isRealNetworkIp(String ip) {
    // Skip Windows ICS / Hyper-V virtual adapter ranges
    if (ip.startsWith('10.111.')) return false;
    if (ip.startsWith('10.112.')) return false;
    if (ip.startsWith('169.254.')) return false; // link-local, no real network
    if (ip == '10.0.2.15') return false; // Android emulator internal
    return true;
  }

  /// Returns true if this is a preferred real LAN/Hotspot IP
  static bool _isPreferred(String ip) {
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.0.') ||
        ip.startsWith('10.1.') ||
        ip.startsWith('10.2.') ||
        ip.startsWith('172.16.') ||
        ip.startsWith('172.17.') ||
        ip.startsWith('172.18.') ||
        ip.startsWith('172.19.') ||
        ip.startsWith('172.2') ||
        ip.startsWith('172.3');
  }

  /// Retrieves the best local IPv4 address for LAN/Hotspot hosting.
  /// Works with Wi-Fi, shared hotspot, and personal hotspot.
  static Future<String?> getIPAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      String? fallback;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Skip purely virtual/loopback adapters - NOT hotspot
        if (name.contains('loopback')) continue;
        if (name.contains('vmnet')) continue;
        if (name.contains('vethernet')) continue; // Hyper-V virtual switch

        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              _isRealNetworkIp(addr.address)) {
            if (_isPreferred(addr.address)) {
              _logger.i('Network IP: ${addr.address} on ${interface.name}');
              return addr.address;
 