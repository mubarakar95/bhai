import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/utils/phone_helper.dart';

void main() {
  group('PhoneHelper - isPlaceholderPhoneNumber', () {
    test('Detects null and empty strings as placeholder/invalid', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber(null), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber(''), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('   '), isTrue);
    });

    test('Detects migration placeholders (90000000XX)', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000008'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000011'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000032'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000037'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000057'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000071'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9000000083'), isTrue);
      // With country code prefix +91 or 91
      expect(PhoneHelper.isPlaceholderPhoneNumber('+919000000083'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('919000000083'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('+91 9000000083'), isTrue);
    });

    test('Detects all identical digits as placeholder', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber('0000000000'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('1111111111'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9999999999'), isTrue);
    });

    test('Detects sequential dummy patterns', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber('1234567890'), isTrue);
      expect(PhoneHelper.isPlaceholderPhoneNumber('0123456789'), isTrue);
    });

    test('Detects invalid length or invalid Indian starting digit', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber('98765'), isTrue); // too short
      expect(PhoneHelper.isPlaceholderPhoneNumber('1234567890'), isTrue); // starts with 1
      expect(PhoneHelper.isPlaceholderPhoneNumber('5555555555'), isTrue); // starts with 5
    });

    test('Recognizes genuine 10-digit Indian mobile numbers as NOT placeholder', () {
      expect(PhoneHelper.isPlaceholderPhoneNumber('9947189733'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('8281944281'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9656399442'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9207982170'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9746491234'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('8891380087'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9605765778'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('9633216451'), isFalse);
      expect(PhoneHelper.isPlaceholderPhoneNumber('+91 82819 44281'), isFalse);
    });
  });

  group('PhoneHelper - validateMobileNumber', () {
    test('Rejects empty or null', () {
      expect(PhoneHelper.validateMobileNumber(null), equals('Mobile number is required'));
      expect(PhoneHelper.validateMobileNumber(''), equals('Mobile number is required'));
    });

    test('Rejects invalid length', () {
      expect(PhoneHelper.validateMobileNumber('987654'), equals('Must be a 10-digit mobile number'));
      expect(PhoneHelper.validateMobileNumber('987654321012'), equals('Must be a 10-digit mobile number'));
    });

    test('Rejects invalid starting digits', () {
      expect(
        PhoneHelper.validateMobileNumber('4444555566'),
        equals('Mobile number must start with 6, 7, 8, or 9'),
      );
    });

    test('Rejects placeholder mobile numbers', () {
      expect(
        PhoneHelper.validateMobileNumber('9000000008'),
        equals('Please enter your actual active personal mobile number'),
      );
      expect(
        PhoneHelper.validateMobileNumber('9999999999'),
        equals('Please enter your actual active personal mobile number'),
      );
    });

    test('Accepts valid Indian mobile numbers', () {
      expect(PhoneHelper.validateMobileNumber('9947189733'), isNull);
      expect(PhoneHelper.validateMobileNumber('8281944281'), isNull);
      expect(PhoneHelper.validateMobileNumber('+91 9656399442'), isNull);
    });
  });

  group('PhoneHelper - clean and format', () {
    test('cleanPhoneNumber extracts last 10 digits', () {
      expect(PhoneHelper.cleanPhoneNumber('+91 82819 44281'), equals('8281944281'));
      expect(PhoneHelper.cleanPhoneNumber('8281944281'), equals('8281944281'));
    });

    test('formatDisplayPhone formats correctly', () {
      expect(PhoneHelper.formatDisplayPhone('8281944281'), equals('+91 82819 44281'));
    });
  });
}
