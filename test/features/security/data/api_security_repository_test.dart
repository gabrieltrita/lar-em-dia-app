import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/security/data/api_security_repository.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/security_fixtures.dart';

void main() {
  late FakeAdapter adapter;

  ApiSecurityRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiSecurityRepository(ApiClient(dio));
  }

  RequestOptions lastRequest() => adapter.requests.last;

  test('reads the 2FA status', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'enabled': true,
          'required': true,
          'backup_codes_remaining': 8,
        },
      }),
    );

    final status = await repository.twoFactorStatus();

    expect(status.enabled, isTrue);
    expect(status.mandatory, isTrue);
    expect(status.backupCodesRemaining, 8);
    expect(lastRequest().path, '/me/two_factor');
  });

  test('reads a status with missing fields as off', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {'data': <String, Object?>{}}),
    );

    expect(await repository.twoFactorStatus(), twoFactorOff);
  });

  test('sets up with the password and enables with the code', () async {
    final repository = build(
      (options) => options.path.endsWith('setup')
          ? FakeAdapter.json(200, {
              'data': {
                'secret': twoFactorSetup.secret,
                'provisioning_uri': twoFactorSetup.provisioningUri,
              },
            })
          : FakeAdapter.json(200, {
              'data': {'enabled': true, 'backup_codes': backupCodes},
            }),
    );

    expect(await repository.setupTwoFactor(passwordOnly), twoFactorSetup);
    expect(lastRequest().data, {'current_password': 'Secret123'});

    expect(await repository.enableTwoFactor('654321'), backupCodes);
    expect(lastRequest().path, '/me/two_factor/enable');
    expect(lastRequest().data, {'code': '654321'});
  });

  test('disables with the password and the code', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.disableTwoFactor(passwordAndCode);

    expect(lastRequest().method, 'DELETE');
    expect(lastRequest().data, {
      'current_password': 'Secret123',
      'code': '123456',
    });
  });

  test('regenerates the backup codes', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {'backup_codes': backupCodes},
      }),
    );

    expect(
      await repository.regenerateBackupCodes(passwordAndCode),
      backupCodes,
    );
    expect(lastRequest().path, '/me/two_factor/backup_codes');
  });

  test('deletes the account with the password and the code', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.deleteAccount(passwordAndCode);

    expect(lastRequest().method, 'DELETE');
    expect(lastRequest().path, '/me');
    expect(lastRequest().data, {
      'current_password': 'Secret123',
      'code': '123456',
    });
  });
}
