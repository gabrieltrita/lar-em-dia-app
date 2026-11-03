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

  test('translates the first detail code of a field', () {
    ApiError withDetail(String code) => ApiError(
      code: 'validation_failed',
      details: {
        'email': [FieldError(code: code), const FieldError(code: 'invalid')],
      },
    );

    final expected = {
      'blank': l10n.validationRequired,
      'required': l10n.validationRequired,
      'too_short': l10n.validationPasswordTooShort,
      'too_long': l10n.validationPasswordTooLong,
      'weak_password': l10n.validationWeakPassword,
      'confirmation': l10n.validationMismatch,
      'taken': l10n.validationTaken,
      'whatever': l10n.validationInvalid,
    };

    for (final MapEntry(:key, :value) in expected.entries) {
      expect(withDetail(key).localizedField(l10n, 'email'), value, reason: key);
    }
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
