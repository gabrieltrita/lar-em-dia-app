import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

abstract interface class TokenStorage {
  String? get accessToken;

  Future<String?> readRefreshToken();

  Future<void> save({required String accessToken, String? refreshToken});

  Future<void> clear();
}

@LazySingleton(as: TokenStorage)
class SecureTokenStorage implements TokenStorage {
  new(this._storage);

  static const refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _accessToken;

  @override
  String? get accessToken => _accessToken;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  @override
  Future<void> save({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    if (refreshToken != null) {
      await _storage.write(key: refreshTokenKey, value: refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    await _storage.delete(key: refreshTokenKey);
  }
}
