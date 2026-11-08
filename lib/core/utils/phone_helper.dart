/// Helper functions for validating, identifying, and formatting phone numbers.
class PhoneHelper {
  PhoneHelper._();

  /// Cleans the input to a standard 10-digit mobile string.
  /// Handles optional '+91' or '91' country code or leading '0'.
  /// Returns empty string if the length does not match standard formats.
  static String cleanPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return digits;
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Returns true if the phone number is missing, incomplete, or matches known
  /// migration dummy/placeholder patterns (e.g. `90000000XX`, all repeated digits, dummy sequence).
  static bool isPlaceholderPhoneNumber(String? phone) {
    if (phone == null) return true;
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return true;

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return true;

    // Check if the total digits match valid lengths (10 digits, or 12 starting with 91, or 11 starting with 0)
    if (digits.length != 10 &&
        !(digits.length == 12 && digits.startsWith('91')) &&
        !(digits.length == 11 && digits.startsWith('0'))) {
      return true;
    }

    final tenDigit = cleanPhoneNumber(trimmed);
    if (tenDigit.length != 10) return true;

    // Migration placeholder specific pattern: 90000000{uid} (e.g. 9000000008, 9000000011, 9000000083)
    if (tenDigit.startsWith('90000000')) return true;

    // All identical digits (e.g. 0000000000, 1111111111, 9999999999)
    if (RegExp(r'^(\d)\1{9}$').hasMatch(tenDigit)) return true;

    // Common dummy sequential numbers
    if (tenDigit == '1234567890' || tenDigit == '0123456789' || tenDigit.startsWith('000')) {
      return true;
    }

    // Standard Indian mobile numbers must start with 6, 7, 8, or 9
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(tenDigit)) return true;

    return false;
  }

  /// Form field validator for personal 10-digit mobile numbers.
  /// Returns null if valid, or an error description string if invalid.
  static String? validateMobileNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Mobile number is required';
    }

    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10 &&
        !(digits.length == 12 && digits.startsWith('91')) &&
        !(digits.length == 11 && digits.startsWith('0'))) {
      return 'Must be a 10-digit mobile number';
    }

    final tenDigit = cleanPhoneNumber(phone.trim());

    if (tenDigit.length != 10) {
      return 'Must be a 10-digit mobile number';
    }

    if (!RegExp(r'^[6-9]').hasMatch(tenDigit)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }

    if (isPlaceholderPhoneNumber(tenDigit)) {
      return 'Please enter your actual active personal mobile number';
    }

    return null;
  }

  /// Formats a 10-digit phone number as `+91 XXXXX XXXXX` for readability.
  static String formatDisplayPhone(String phone) {
    final clean = cleanPhoneNumber(phone);
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return phone;
  }
}
