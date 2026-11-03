import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension ApiErrorMessages on ApiError {
  String localized(AppLocalizations l10n) => switch (code) {
    'invalid_credentials' => l10n.errorInvalidCredentials,
    'email_not_confirmed' => l10n.errorEmailNotConfirmed,
    'invalid_two_factor_code' => l10n.errorInvalidTwoFactorCode,
    'two_factor_challenge_expired' => l10n.errorTwoFactorChallengeExpired,
    'invalid_confirmation_token' => l10n.errorInvalidConfirmationToken,
    'invalid_reset_token' => l10n.errorInvalidResetToken,
    'validation_failed' => l10n.errorValidationFailed,
    'rate_limited' => l10n.errorRateLimited,
    ApiError.networkErrorCode => l10n.errorNetwork,
    _ => l10n.errorUnknown,
  };

  String? localizedField(AppLocalizations l10n, String field) {
    final errors = details[field];
    if (errors == null || errors.isEmpty) {
      return null;
    }
    return switch (errors.first.code) {
      'blank' || 'required' => l10n.validationRequired,
      'too_short' => l10n.validationPasswordTooShort,
      'too_long' => l10n.validationPasswordTooLong,
      'weak_password' => l10n.validationWeakPassword,
      'confirmation' => l10n.validationMismatch,
      'taken' => l10n.validationTaken,
      _ => l10n.validationInvalid,
    };
  }
}

extension ValidationErrorMessages on ValidationError {
  String localized(AppLocalizations l10n) => switch (this) {
    ValidationError.required => l10n.validationRequired,
    ValidationError.invalidEmail => l10n.validationInvalidEmail,
    ValidationError.passwordTooShort => l10n.validationPasswordTooShort,
    ValidationError.passwordTooLong => l10n.validationPasswordTooLong,
    ValidationError.weakPassword => l10n.validationWeakPassword,
    ValidationError.mismatch => l10n.validationMismatch,
  };
}
