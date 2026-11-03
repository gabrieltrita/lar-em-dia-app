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
      'two_factor_challenge_expired': l10n.errorTwoFactorChallengeExpired,
      'invalid_confirmation_token': l10n.errorInvalidConfirmationToken,
      'invalid_reset_token': l10n.errorInvalidResetToken,
      'validation_failed': l10n.errorValidationFailed,
      'rate_limited': l10n.errorRateLimited,
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
