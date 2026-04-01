import 'dart:io';
import 'package:logger/logger.dart';

/// Utility class for IP address operations
class IPUtils {
  static final Logger _logger = Logger();

  /// Retrieves the local IPv4 address of the device
  /// Returns the first non-loopback IPv4 address found
  static Future<String?> getIPAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _logger.i('Local IPv4 address found: ${addr.address}');
            return addr.address;
          }
        }
      }
      _logger.w('No suitable IPv4 address found');
      return null;
    } catch (e) {
      _logger.e('Error retrieving IP address: $e');
      return null;
    }
  }
}