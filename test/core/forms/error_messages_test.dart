import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('pt'));

  test('translates known API error codes and falls back for others', () {
    final expected = {
      'invalid_credentials': l10n.errorInvalidCredentials,
      'email_not_confirmed': l10n.errorEmailNotConfirmed,
      'invalid_two_factor_code': l10n.errorInvalidTwoFactorCode,
      'invalid_unsubscribe_token': l10n.errorInvalidUnsubscribeToken,
      'two_factor_challenge_expired': l10n.errorTwoFactorChallengeExpired,
      'invalid_confirmation_token': l10n.errorInvalidConfirmationToken,
      'invalid_reset_token': l10n.errorInvalidResetToken,
      'invalid_unlock_token': l10n.errorInvalidUnlockToken,
      'validation_failed': l10n.errorValidationFailed,
      'rate_limited': l10n.errorRateLimited,
      'two_factor_setup_required': l10n.errorTwoFactorSetupRequired,
      'forbidden': l10n.errorForbidden,
      'invalid_current_password': l10n.errorInvalidCurrentPassword,
      'google_sign_in_failed': l10n.errorGoogleSignInFailed,
      'oauth_token_invalid': l10n.errorOauthTokenInvalid,
      'oauth_email_unverified': l10n.errorOauthEmailUnverified,
      'oauth_provider_unavailable': l10n.errorOauthProviderUnavailable,
      'provider_unavailable': l10n.errorOauthProviderUnavailable,
      'invalid_provider_token': l10n.errorInvalidProviderToken,
      'two_factor_already_enabled': l10n.errorTwoFactorAlreadyEnabled,
      'two_factor_required': l10n.errorTwoFactorRequired,
      'reauthentication_unavailable': l10n.errorReauthenticationUnavailable,
      'only_for_single_entry': l10n.errorOnlyForSingleEntry,
      'installment_amount_locked': l10n.errorInstallmentAmountLocked,
      'insufficient_quantity': l10n.errorInsufficientQuantity,
      'insufficient_reserve': l10n.errorInsufficientReserve,
      'invalid_filter': l10n.errorInvalidFilter,
      'invalid_sort': l10n.errorInvalidFilter,
      ApiError.networkErrorCode: l10n.errorNetwork,
      'something_new': l10n.errorUnknown,
    };

    for (final MapEntry(:key, :value) in expected.entries) {
      expect(ApiError(code: key).localized(l10n), value, reason: key);
    }
  });

  ApiError withDetail(String field, String code) => ApiError(
    code: 'validation_failed',
    details: {
      field: [FieldError(code: code), const FieldError(code: 'invalid')],
    },
  );

  test('translates the first detail code of a field', () {
    final expected = {
      'blank': l10n.validationRequired,
      'required': l10n.validationRequired,
      'too_short': l10n.validationInvalid,
      'too_long': l10n.validationTooLong,
      'weak_password': l10n.validationWeakPassword,
      'confirmation': l10n.validationMismatch,
      'taken': l10n.validationTaken,
      'in_future': l10n.validationInFuture,
      'inactive': l10n.validationInactive,
      'immutable': l10n.validationImmutable,
      'insufficient_quantity': l10n.validationInsufficientQuantity,
      'unknown_asset': l10n.validationUnknownAsset,
      'stock_only': l10n.validationStockOnly,
      'no_income_data': l10n.validationNoIncomeData,
      'before_record_on': l10n.validationBeforeRecordOn,
      'only_for_trades': l10n.validationOnlyForTrades,
      'insufficient_reserve': l10n.validationInsufficientReserve,
      'anchor_not_allowed': l10n.validationAnchorNotAllowed,
      'rate_required': l10n.validationRateRequired,
      'rate_not_allowed': l10n.validationRateNotAllowed,
      'greater_than': l10n.validationAmountRequired,
      'not_an_integer': l10n.validationAmountRequired,
      'whatever': l10n.validationInvalid,
    };

    for (final MapEntry(:key, :value) in expected.entries) {
      expect(
        withDetail('description', key).localizedField(l10n, 'description'),
        value,
        reason: key,
      );
    }
  });

  test('uses the password rules for password lengths', () {
    expect(
      withDetail('password', 'too_short').localizedField(l10n, 'password'),
      l10n.validationPasswordTooShort,
    );
    expect(
      withDetail('password', 'too_long').localizedField(l10n, 'password'),
      l10n.validationPasswordTooLong,
    );
  });

  test('has no field message when the field has no details', () {
    const error = ApiError(
      code: 'validation_failed',
      details: {'email': <FieldError>[]},
    );

    expect(error.localizedField(l10n, 'email'), isNull);
    expect(error.localizedField(l10n, 'password'), isNull);
  });

  test('translates every local validation error', () {
    expect(
      ValidationError.values.map((error) => error.localized(l10n)).toSet(),
      hasLength(ValidationError.values.length),
    );
  });
}
