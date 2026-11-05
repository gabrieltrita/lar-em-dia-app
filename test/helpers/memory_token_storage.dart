import 'package:lar_em_dia/core/storage/token_storage.dart';

class MemoryTokenStorage implements TokenStorage {
  new({this.accessToken, this.refreshToken});

  @override
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save({required String accessToken, String? refreshToken}) async {
    this.accessToken = accessToken;
    if (refreshToken != null) {
      this.refreshToken = refreshToken;
    }
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}
