enum ValidationError {
  required,
  invalidEmail,
  passwordTooShort,
  passwordTooLong,
  weakPassword,
  mismatch,
}

abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _upper = RegExp('[A-Z]');
  static final _lower = RegExp('[a-z]');
  static final _digit = RegExp(r'\d');

  static ValidationError? required(String? value) =>
      (value == null || value.trim().isEmpty) ? ValidationError.required : null;

  static ValidationError? email(String? value) {
    final missing = required(value);
    if (missing != null) {
      return missing;
    }
    return _email.hasMatch(value!.trim()) ? null : ValidationError.invalidEmail;
  }

  static ValidationError? password(String? value) {
    final missing = required(value);
    if (missing != null) {
      return missing;
    }
    if (value!.length < 8) {
      return ValidationError.passwordTooShort;
    }
    if (value.length > 72) {
      return ValidationError.passwordTooLong;
    }
    final strong =
        _upper.hasMatch(value) &&
        _lower.hasMatch(value) &&
        _digit.hasMatch(value);
    return strong ? null : ValidationError.weakPassword;
  }

  static ValidationError? matches(String? value, String other) =>
      value == other ? null : ValidationError.mismatch;
}
