/// Comprehensive input validation utilities
class FormValidators {
  /// Validate non-empty field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[0-9+\-\s()]{10,}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Validate address (minimum length)
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    if (value.trim().length < 5) {
      return 'Please enter a complete address';
    }
    return null;
  }

  /// Validate password (minimum 8 characters, mix of letters and numbers)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[a-zA-Z]'))) {
      return 'Password must contain letters';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain numbers';
    }
    return null;
  }

  /// Validate name (letters and spaces only)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens and apostrophes';
    }
    return null;
  }

  /// Validate numeric field
  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }
    return null;
  }

  /// Validate minimum value
  static String? validateMinValue(
    String? value,
    double minValue,
    String fieldName,
  ) {
    final numberError = validateNumber(value, fieldName);
    if (numberError != null) return numberError;

    final number = double.parse(value!);
    if (number < minValue) {
      return '$fieldName must be at least $minValue';
    }
    return null;
  }

  /// Validate password confirmation
  static String? validatePasswordMatch(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
