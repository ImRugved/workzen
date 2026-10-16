/// Form field validators used across the app. A screen passes one of these to
/// a field's `validator:` instead of writing the checks inline, so the rules
/// and messages stay the same everywhere.
///
/// `Validators.email` is a validator itself; the ones that need an argument
/// (`required`, `confirmPassword`, `intInRange`) return a validator.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  /// A value must be typed. [fieldName] completes the message, for example
  /// `required('your name')` gives "Please enter your name".
  static String? Function(String?) required(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter $fieldName';
      }
      return null;
    };
  }

  /// Required, well formed email address.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Required password of at least [minLength] characters.
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Must match the password read from [original] when the form is checked.
  static String? Function(String?) confirmPassword(
    String Function() original,
  ) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != original()) {
        return 'Passwords do not match';
      }
      return null;
    };
  }

  /// Required 10 digit mobile number.
  static String? mobileNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter mobile number';
    }
    if (value.length != 10) {
      return 'Please enter a valid 10-digit number';
    }
    return null;
  }

  /// Optional 10 digit number: blank is fine, anything typed must be 10 digits.
  static String? optionalMobileNumber(String? value) {
    if (value != null && value.isNotEmpty && value.length != 10) {
      return 'Please enter a valid 10-digit number';
    }
    return null;
  }

  /// Optional whole number between [min] and [max]; blank is fine.
  static String? Function(String?) intInRange(int min, int max) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      final number = int.tryParse(value);
      if (number == null) return 'Invalid number';
      if (number < min || number > max) return 'Must be $min-$max';
      return null;
    };
  }
}
