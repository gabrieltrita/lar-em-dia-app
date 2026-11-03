import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage;

void main() {
  late _MockSecureStorage secureStorage;
  late SecureTokenStorage storage;

  setUp(() {
    secureStorage = _MockSecureStorage();
    storage = SecureTokenStorage(secureStorage);
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => secureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
  });

  test(
    'keeps the access token in memory and the refresh token secure',
    () async {
      await storage.save(accessToken: 'access', refreshToken: 'refresh');

      expect(storage.accessToken, 'access');
      verify(
        () => secureStorage.write(
          key: SecureTokenStorage.refreshTokenKey,
          value: 'refresh',
        ),
      ).called(1);
    },
  );

  test('does not touch the stored refresh token when none is given', () async {
    await storage.save(accessToken: 'access');

    verifyNever(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });

  test('reads the refresh token from secure storage', () async {
    when(() => secureStorage.read(key: SecureTokenStorage.refreshTokenKey))
        .thenAnswer((_) async => 'refresh');

    expect(await storage.readRefreshToken(), 'refresh');
  });

  test('clear forgets both tokens', () async {
    await storage.save(accessToken: 'access');
    await storage.clear();

    expect(storage.accessToken, isNull);
    verify(() => secureStorage.delete(key: SecureTokenStorage.refreshTokenKey))
        .called(1);
  });
}
