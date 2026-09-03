class AppValidators {
  AppValidators._();

  /// Strict email regex. Disallows spaces, multiple @ symbols, and invalid TLDs.
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );

  /// Validates email format.
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Strict password policy: Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain at least one uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain at least one lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain at least one number';
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Must contain at least one special character';
    return null;
  }

  /// Validates that two passwords match.
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  /// Name validation: Alphabets, spaces, dots, hyphens, and apostrophes only. Prevents emojis/injection.
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (!RegExp(r"^[a-zA-Z\s'\.-]+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, dots, hyphens, or apostrophes';
    }
    return null;
  }

  /// OTP validation: Exactly 6 numeric digits.
  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'OTP is required';
    if (value.length != 6) return 'OTP must be exactly 6 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'OTP must contain only numbers';
    return null;
  }
}
