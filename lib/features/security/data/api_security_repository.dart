import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/security/data/two_factor_dtos.dart';
import 'package:lar_em_dia/features/security/domain/security_repository.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';

@LazySingleton(as: SecurityRepository)
class ApiSecurityRepository implements SecurityRepository {
  new(this._client);

  static const path = '/me/two_factor';
  static const accountPath = '/me';

  final ApiClient _client;

  @override
  Future<TwoFactorStatus> twoFactorStatus() async => (await _client.get(
    path,
    decode: (data) => TwoFactorStatusDto.fromJson(data! as Json).toDomain(),
  )).data;

  @override
  Future<TwoFactorSetup> setupTwoFactor(
    Reauthentication reauthentication,
  ) async => (await _client.post(
    '$path/setup',
    decode: (data) => TwoFactorSetupDto.fromJson(data! as Json).toDomain(),
    body: _body(reauthentication),
  )).data;

  @override
  Future<List<String>> enableTwoFactor(String code) async =>
      (await _client.post(
        '$path/enable',
        decode: _codes,
        body: {'code': code},
      )).data;

  @override
  Future<void> disableTwoFactor(Reauthentication reauthentication) =>
      _client.delete(path, body: _body(reauthentication));

  @override
  Future<List<String>> regenerateBackupCodes(
    Reauthentication reauthentication,
  ) async => (await _client.post(
    '$path/backup_codes',
    decode: _codes,
    body: _body(reauthentication),
  )).data;

  @override
  Future<void> deleteAccount(Reauthentication reauthentication) =>
      _client.delete(accountPath, body: _body(reauthentication));

  static List<String> _codes(Object? data) =>
      BackupCodesDto.fromJson(data! as Json).backupCodes;

  static Json _body(Reauthentication reauthentication) => {
    'current_password': reauthentication.password,
    'code': ?reauthentication.code,
  };
}
