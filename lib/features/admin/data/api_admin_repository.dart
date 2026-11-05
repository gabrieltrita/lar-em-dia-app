import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/admin/data/admin_metrics_dto.dart';
import 'package:lar_em_dia/features/admin/data/admin_user_dto.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/domain/admin_repository.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

@LazySingleton(as: AdminRepository)
class ApiAdminRepository implements AdminRepository {
  new(this._client);

  static const path = '/admin/users';
  static const pageSize = 25;

  final ApiClient _client;

  @override
  Future<AdminUserPage> users({
    required int page,
    String? email,
    AccountStatus? status,
  }) async {
    final response = await _client.get<List<AdminUser>>(
      path,
      decode: (data) => (data! as List<dynamic>).map(_decode).toList(),
      query: {
        'page': page,
        'limit': pageSize,
        if (email != null && email.isNotEmpty) 'email': email,
        'status': ?status?.name,
      },
    );
    return AdminUserPage(
      users: response.data,
      nextPage: response.meta['next'] as int?,
    );
  }

  @override
  Future<AdminUser> user(String id) async =>
      (await _client.get('$path/$id', decode: _decode)).data;

  @override
  Future<AdminUser> unlock(String id) => _action(id, 'unlock');

  @override
  Future<void> resetTwoFactor(String id) =>
      _client.delete('$path/$id/two_factor');

  @override
  Future<AdminUser> deactivate(String id) => _action(id, 'deactivate');

  @override
  Future<AdminUser> reactivate(String id) => _action(id, 'reactivate');

  @override
  Future<AdminUser> changeRole(String id, UserRole role) async =>
      (await _client.patch(
        '$path/$id',
        decode: _decode,
        body: {'role': role.name},
      )).data;

  @override
  Future<AdminMetrics> metrics() async => (await _client.get(
    '/admin/metrics',
    decode: (data) => AdminMetricsDto.fromJson(data! as Json).toDomain(),
  )).data;

  Future<AdminUser> _action(String id, String action) async =>
      (await _client.post('$path/$id/$action', decode: _decode)).data;

  static AdminUser _decode(Object? data) =>
      AdminUserDto.fromJson(data! as Json).toDomain();
}
