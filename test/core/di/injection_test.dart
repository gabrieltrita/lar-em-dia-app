import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/auth_interceptor.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';
import 'package:lar_em_dia/features/auth/data/api_auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/reminders/data/local_notifications_scheduler.dart';
import 'package:lar_em_dia/features/reminders/domain/reminder_scheduler.dart';
import 'package:lar_em_dia/features/reserve/data/api_reserve_repository.dart';
import 'package:lar_em_dia/features/reserve/data/prefs_reserve_dismissal.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(configureDependencies);

  test('wires Dio with the API base URL and the auth interceptor', () {
    final dio = getIt<Dio>();

    expect(dio.options.baseUrl, Env.apiBaseUrl);
    expect(dio.options.extra['withCredentials'], isFalse);
    expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
  });

  test('registers the client, the storage, the session and the router', () {
    expect(getIt<ApiClient>(), isA<ApiClient>());
    expect(getIt<TokenStorage>(), isA<SecureTokenStorage>());
    expect(getIt<TokenTransport>(), same(TokenTransport.body));
    expect(getIt<SessionEvents>(), same(getIt<SessionEvents>()));
    expect(getIt<AuthRepository>(), isA<ApiAuthRepository>());
    expect(getIt<SessionCubit>(), same(getIt<SessionCubit>()));
    expect(getIt<GoRouter>(), same(getIt<GoRouter>()));
    expect(getIt<GoogleSignIn>(), same(GoogleSignIn.instance));
  });

  test('registers the local notifications for the due reminders', () {
    expect(
      getIt<FlutterLocalNotificationsPlugin>(),
      same(FlutterLocalNotificationsPlugin()),
    );
    expect(getIt<ReminderScheduler>(), isA<LocalNotificationsScheduler>());
  });

  test('registers the reserve repository and its dismissal', () {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    expect(getIt<ReserveRepository>(), isA<ApiReserveRepository>());
    expect(getIt<ReserveDismissal>(), isA<PrefsReserveDismissal>());
  });
}
