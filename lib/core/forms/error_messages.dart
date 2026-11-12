import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension ApiErrorMessages on ApiError {
  String localized(AppLocalizations l10n) => switch (code) {
    'invalid_credentials' => l10n.errorInvalidCredentials,
    'email_not_confirmed' => l10n.errorEmailNotConfirmed,
    'invalid_two_factor_code' => l10n.errorInvalidTwoFactorCode,
    'invalid_unsubscribe_token' => l10n.errorInvalidUnsubscribeToken,
    'two_factor_challenge_expired' => l10n.errorTwoFactorChallengeExpired,
    'invalid_confirmation_token' => l10n.errorInvalidConfirmationToken,
    'invalid_reset_token' => l10n.errorInvalidResetToken,
    'invalid_unlock_token' => l10n.errorInvalidUnlockToken,
    'validation_failed' => l10n.errorValidationFailed,
    'rate_limited' => l10n.errorRateLimited,
    'two_factor_setup_required' => l10n.errorTwoFactorSetupRequired,
    'forbidden' => l10n.errorForbidden,
    'invalid_current_password' => l10n.errorInvalidCurrentPassword,
    'two_factor_already_enabled' => l10n.errorTwoFactorAlreadyEnabled,
    'two_factor_required' => l10n.errorTwoFactorRequired,
    'reauthentication_unavailable' => l10n.errorReauthenticationUnavailable,
    'only_for_single_entry' => l10n.errorOnlyForSingleEntry,
    'installment_amount_locked' => l10n.errorInstallmentAmountLocked,
    'insufficient_quantity' => l10n.errorInsufficientQuantity,
    'google_sign_in_failed' => l10n.errorGoogleSignInFailed,
    'oauth_token_invalid' => l10n.errorOauthTokenInvalid,
    'oauth_email_unverified' => l10n.errorOauthEmailUnverified,
    'oauth_provider_unavailable' ||
    'provider_unavailable' => l10n.errorOauthProviderUnavailable,
    'invalid_provider_token' => l10n.errorInvalidProviderToken,
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
      'too_short' when field == 'password' => l10n.validationPasswordTooShort,
      'too_long' when field == 'password' => l10n.validationPasswordTooLong,
      'too_long' => l10n.validationTooLong,
      'weak_password' => l10n.validationWeakPassword,
      'confirmation' => l10n.validationMismatch,
      'taken' => l10n.validationTaken,
      'in_future' => l10n.validationInFuture,
      'inactive' => l10n.validationInactive,
      'immutable' => l10n.validationImmutable,
      'insufficient_quantity' => l10n.validationInsufficientQuantity,
      'unknown_asset' => l10n.validationUnknownAsset,
      'only_for_trades' => l10n.validationOnlyForTrades,
      'greater_than' || 'not_an_integer' => l10n.validationAmountRequired,
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
    ValidationError.invalidAmount => l10n.validationAmountRequired,
  };
}
