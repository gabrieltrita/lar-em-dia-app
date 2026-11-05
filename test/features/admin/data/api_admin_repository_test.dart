import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/admin/data/api_admin_repository.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

import '../../../helpers/admin_fixtures.dart';
import '../../../helpers/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;

  final carlaJson = {
    'id': 'user-2',
    'email': 'carla@example.com',
    'first_name': 'Carla',
    'last_name': 'Lima',
    'full_name': 'Carla Lima',
    'role': 'user',
    'email_confirmed': true,
    'two_factor_enabled': false,
    'locked': false,
    'deactivated': false,
    'deactivated_at': null,
    'sign_in_count': 4,
    'created_at': '2026-10-01T12:00:00Z',
    'last_sign_in_at': '2026-11-03T13:30:00Z',
  };

  ApiAdminRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiAdminRepository(ApiClient(dio));
  }

  RequestOptions lastRequest() => adapter.requests.last;

  test('lists a page of users with the filters', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [carlaJson],
        'meta': {'next': 3},
      }),
    );

    final page = await repository.users(
      page: 2,
      email: 'carla@example.com',
      status: AccountStatus.active,
    );

    expect(page, AdminUserPage(users: [carla], nextPage: 3));
    expect(lastRequest().path, '/admin/users');
    expect(lastRequest().queryParameters, {
      'page': 2,
      'limit': ApiAdminRepository.pageSize,
      'email': 'carla@example.com',
      'status': 'active',
    });
  });

  test('omits empty filters and reads the last page', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [
          {
            'id': 'user-9',
            'email': 'new@example.com',
            'full_name': 'New',
            'role': 'owner',
            'created_at': '2026-10-01T12:00:00Z',
          },
        ],
        'meta': {'next': null},
      }),
    );

    final page = await repository.users(page: 1, email: '');

    expect(page.nextPage, isNull);
    expect(page.users.single.role, UserRole.user);
    expect(page.users.single.signInCount, 0);
    expect(page.users.single.lastSignInAt, isNull);
    expect(lastRequest().queryParameters, {
      'page': 1,
      'limit': ApiAdminRepository.pageSize,
    });
  });

  test('reads one user', () async {
    final repository = build((_) => FakeAdapter.json(200, {'data': carlaJson}));

    expect(await repository.user('user-2'), carla);
    expect(lastRequest().path, '/admin/users/user-2');
  });

  for (final (action, call) in [
    ('unlock', (ApiAdminRepository r) => r.unlock('user-2')),
    ('deactivate', (ApiAdminRepository r) => r.deactivate('user-2')),
    ('reactivate', (ApiAdminRepository r) => r.reactivate('user-2')),
  ]) {
    test('posts the $action action', () async {
      final repository = build(
        (_) => FakeAdapter.json(200, {'data': carlaJson}),
      );

      expect(await call(repository), carla);
      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/admin/users/user-2/$action');
    });
  }

  test('resets the second factor', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.resetTwoFactor('user-2');

    expect(lastRequest().method, 'DELETE');
    expect(lastRequest().path, '/admin/users/user-2/two_factor');
  });

  test('changes the role', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {...carlaJson, 'role': 'admin'},
      }),
    );

    final user = await repository.changeRole('user-2', UserRole.admin);

    expect(user.isAdmin, isTrue);
    expect(lastRequest().method, 'PATCH');
    expect(lastRequest().data, {'role': 'admin'});
  });

  test('surfaces the missing second factor of the admin', () async {
    final repository = build(
      (_) => FakeAdapter.json(403, {
        'error': {'code': 'two_factor_setup_required', 'message': 'Enable 2FA'},
      }),
    );

    await expectLater(
      repository.users(page: 1),
      throwsA(
        isA<ApiError>().having(
          (error) => error.code,
          'code',
          'two_factor_setup_required',
        ),
      ),
    );
  });

  test('reads the aggregated metrics', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'users': {
            'total': 42,
            'confirmed': 40,
            'active_30d': 31,
            'new_30d': 7,
            'deactivated': 2,
            'with_two_factor': 5,
          },
          'engagement': {
            'with_balance': 30,
            'with_entries': 28,
            'with_5_series': 19,
            'entries_created_30d': 512,
          },
          'signups_by_week': [
            {'week': '2026-11-02', 'count': 3},
          ],
        },
      }),
    );

    final result = await repository.metrics();

    expect(
      result,
      metrics.copyWith(
        signupsByWeek: [WeeklySignups(week: DateTime(2026, 11, 2), count: 3)],
      ),
    );
    expect(lastRequest().path, '/admin/metrics');
  });

  test('reads metrics with missing counts as zero', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'users': <String, Object?>{},
          'engagement': <String, Object?>{},
        },
      }),
    );

    final result = await repository.metrics();

    expect(result.users.total, 0);
    expect(result.engagement.withFiveSeries, 0);
    expect(result.signupsByWeek, isEmpty);
  });

  group('categories', () {
    final petsJson = {
      'id': 'cat-2',
      'kind': 'expense',
      'key': 'pets',
      'name': 'Pets',
      'position': 16,
      'default_nature': 'variable',
      'active': false,
      'created_at': '2026-10-01T12:00:00Z',
      'updated_at': '2026-10-02T12:00:00Z',
    };

    test('lists every category with defaults for missing fields', () async {
      final repository = build(
        (_) => FakeAdapter.json(200, {
          'data': [
            {
              'id': 'cat-1',
              'kind': 'income',
              'key': 'salary',
              'name': 'Salary',
              'default_nature': null,
            },
            petsJson,
          ],
        }),
      );

      final result = await repository.categories();

      expect(result, [adminSalary, adminPets]);
      expect(lastRequest().path, ApiAdminRepository.categoriesPath);
      expect(lastRequest().method, 'GET');
    });

    test('creates a category with its kind and key', () async {
      final repository = build(
        (_) => FakeAdapter.json(201, {'data': petsJson}),
      );

      final result = await repository.createCategory(adminPets.toDraft());

      expect(result, adminPets);
      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/admin/categories');
      expect(lastRequest().data, {
        'kind': 'expense',
        'key': 'pets',
        'name': 'Pets',
        'position': 16,
        'default_nature': 'variable',
        'active': false,
      });
    });

    test('updates a category without its kind and key', () async {
      final repository = build(
        (_) => FakeAdapter.json(200, {'data': petsJson}),
      );

      await repository.updateCategory('cat-1', adminSalary.toDraft());

      expect(lastRequest().method, 'PATCH');
      expect(lastRequest().path, '/admin/categories/cat-1');
      expect(lastRequest().data, {
        'name': 'Salary',
        'position': 0,
        'default_nature': null,
        'active': true,
      });
    });
  });
}
