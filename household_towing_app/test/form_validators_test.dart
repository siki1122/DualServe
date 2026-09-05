import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/utils/form_validators.dart';

void main() {
  group('FormValidators - validateRequired', () {
    test('should reject null value', () {
      expect(FormValidators.validateRequired(null, 'Name'), 'Name is required');
    });

    test('should reject empty value', () {
      expect(FormValidators.validateRequired('', 'Name'), 'Name is required');
    });

    test('should accept valid value', () {
      expect(FormValidators.validateRequired('Charles', 'Name'), null);
    });
  });

  group('FormValidators - validateEmail', () {
    test('should reject empty email', () {
      expect(FormValidators.validateEmail(''), 'Email is required');
    });

    test('should reject invalid email', () {
      expect(
        FormValidators.validateEmail('invalid-email'),
        'Please enter a valid email',
      );
    });

    test('should accept valid email', () {
      expect(FormValidators.validateEmail('test@example.com'), null);
    });
  });

  group('FormValidators - validatePhone', () {
    test('should reject empty phone number', () {
      expect(FormValidators.validatePhone(''), 'Phone number is required');
    });

    test('should reject invalid phone number', () {
      expect(
        FormValidators.validatePhone('123'),
        'Please enter a valid phone number',
      );
    });

    test('should accept valid phone number', () {
      expect(FormValidators.validatePhone('09123456789'), null);
    });
  });

  group('FormValidators - validateAddress', () {
    test('should reject empty address', () {
      expect(FormValidators.validateAddress(''), 'Address is required');
    });

    test('should reject address shorter than 5 characters', () {
      expect(
        FormValidators.validateAddress('Abcd'),
        'Please enter a complete address',
      );
    });

    test('should accept valid address', () {
      expect(FormValidators.validateAddress('Talisay City'), null);
    });
  });

  group('FormValidators - validatePassword', () {
    test('should reject empty password', () {
      expect(FormValidators.validatePassword(''), 'Password is required');
    });

    test('should reject password shorter than 8 characters', () {
      expect(
        FormValidators.validatePassword('abc123'),
        'Password must be at least 8 characters',
      );
    });

    test('should reject password without letters', () {
      expect(
        FormValidators.validatePassword('12345678'),
        'Password must contain letters',
      );
    });

    test('should reject password without numbers', () {
      expect(
        FormValidators.validatePassword('abcdefgh'),
        'Password must contain numbers',
      );
    });

    test('should accept valid password', () {
      expect(FormValidators.validatePassword('password123'), null);
    });
  });

  group('FormValidators - validateName', () {
    test('should reject empty name', () {
      expect(FormValidators.validateName(''), 'Name is required');
    });

    test('should reject name containing invalid characters', () {
      expect(
        FormValidators.validateName('John123'),
        'Name can only contain letters, spaces, hyphens and apostrophes',
      );
    });

    test('should accept valid name', () {
      expect(FormValidators.validateName("John Dela Cruz"), null);
    });
  });

  group('FormValidators - validateNumber', () {
    test('should reject empty number', () {
      expect(FormValidators.validateNumber('', 'Age'), 'Age is required');
    });

    test('should reject invalid number', () {
      expect(
        FormValidators.validateNumber('abc', 'Age'),
        'Age must be a valid number',
      );
    });

    test('should accept valid number', () {
      expect(FormValidators.validateNumber('21', 'Age'), null);
    });
  });

  group('FormValidators - validateMinValue', () {
    test('should return required error for empty value', () {
      expect(FormValidators.validateMinValue('', 18, 'Age'), 'Age is required');
    });

    test('should return number error for invalid value', () {
      expect(
        FormValidators.validateMinValue('abc', 18, 'Age'),
        'Age must be a valid number',
      );
    });

    test('should reject value below minimum', () {
      expect(
        FormValidators.validateMinValue('17', 18, 'Age'),
        'Age must be at least 18.0',
      );
    });

    test('should accept value equal to minimum', () {
      expect(FormValidators.validateMinValue('18', 18, 'Age'), null);
    });

    test('should accept value above minimum', () {
      expect(FormValidators.validateMinValue('21', 18, 'Age'), null);
    });
  });

  group('FormValidators - validatePasswordMatch', () {
    test('should reject empty confirmation', () {
      expect(
        FormValidators.validatePasswordMatch('', 'password123'),
        'Please confirm your password',
      );
    });

    test('should reject different passwords', () {
      expect(
        FormValidators.validatePasswordMatch('password1234', 'password123'),
        'Passwords do not match',
      );
    });

    test('should accept matching passwords', () {
      expect(
        FormValidators.validatePasswordMatch('password123', 'password123'),
        null,
      );
    });
  });
}
