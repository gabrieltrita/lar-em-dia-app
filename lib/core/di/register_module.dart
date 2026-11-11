import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/cache/local_cache.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/network/auth_interceptor.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';
import 'package:lar_em_dia/demo/demo_mode.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';

@module
abstract class RegisterModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  @lazySingleton
  LocalCache localCache(FinanceCache cache) => cache;

  @lazySingleton
  FlutterLocalNotificationsPlugin get notifications =>
      FlutterLocalNotificationsPlugin();

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;

  @lazySingleton
  TokenTransport get tokenTransport => TokenTransport.platform;

  @lazySingleton
  Dio dio(
    TokenStorage tokenStorage,
    TokenTransport transport,
    SessionEvents sessionEvents,
  ) {
    final options = BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      extra: {'withCredentials': transport.usesCookie},
    );
    return DemoMode.apply(Dio(options))
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: tokenStorage,
          client: DemoMode.apply(Dio(options)),
          transport: transport,
          sessionEvents: sessionEvents,
        ),
      );
  }

  @lazySingleton
  GoRouter router(SessionCubit sessionCubit) => buildRouter(sessionCubit);
}
