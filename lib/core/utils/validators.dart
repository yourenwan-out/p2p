import 'package:logger/logger.dart';

/// Validation utilities for the app
class Validators {
  static final Logger _logger = Logger();

  /// Validates if the input is a valid IPv4 address format (XXX.XXX.XXX.XXX)
  /// Each octet must be between 0-255
  static String? validateIPAddress(String? value) {
    if (value == null || value.isEmpty) {
      _logger.w('IP address is empty');
      return 'IP address cannot be empty';
    }

    final ipRegex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final match = ipRegex.firstMatch(value);

    if (match == null) {
      _logger.w('IP address format is invalid: $value');
      return 'Invalid IP address format. Use XXX.XXX.XXX.XXX';
    }

    // Check each octet
    for (int i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!);
      if (octet == null || octet < 0 || octet > 255) {
        _logger.w('IP address octet out of range: $value');
        return 'Each IP octet must be between 0 and 255';
      }
    }

    _logger.i('IP address is valid: $value');
    return null; // Valid
  }

  // TC-01: Valid IP (e.g., 192.168.1.1)
  // TC-02: Invalid IP (e.g., 256.1.1.1, 192.168.1, abc.def.ghi.jkl)
}