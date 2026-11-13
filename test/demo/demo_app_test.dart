import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/auth_interceptor.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';
import 'package:lar_em_dia/demo/demo_mode.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/projection/domain/projection_preferences.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';

import '../helpers/finance_fixtures.dart';

import '../helpers/memory_token_storage.dart';
import '../helpers/reserve_fixtures.dart';

void main() {
  setUpAll(() {
    configureDependencies();
    final storage = MemoryTokenStorage();
    Dio demoDio() => DemoMode.apply(
      Dio(BaseOptions(baseUrl: 'http://demo.test/api/v1')),
      enabled: true,
    );
    getIt
      ..allowReassignment = true
      ..registerSingleton<TokenStorage>(storage)
      ..registerSingleton<TokenTransport>(TokenTransport.body)
      ..registerSingleton<ReserveDismissal>(dismissalUntil(null))
      ..registerSingleton<ProjectionPreferences>(FakeProjectionPreferences())
      ..registerSingleton<Dio>(
        demoDio()
          ..interceptors.add(
            AuthInterceptor(
              tokenStorage: storage,
              client: demoDio(),
              transport: TokenTransport.body,
              sessionEvents: getIt<SessionEvents>(),
            ),
          ),
      );
  });

  testWidgets('runs the whole app against the in-memory API', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const App());
    await getIt<SessionCubit>().restore();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email')),
      DemoSeed.email,
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      DemoSeed.password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Ana!'), findsOneWidget);
    expect(find.text(r'R$ 3.500,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Projeção'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp('você vai (guardar|perder)')),
      findsOneWidget,
    );

    await tester.tap(find.text('Tudo'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp('você vai (guardar|perder)')),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver mais ›'));
    await tester.pumpAndSettle();
    expect(find.text('Sua economia'), findsOneWidget);

    GoRouter.of(tester.element(find.text('Sua economia')))
        .go(AppRoutes.investments);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserve_card')));
    await tester.pumpAndSettle();
    expect(find.text('Total líquido'), findsOneWidget);
    expect(find.text('Tesouro Selic'), findsWidgets);
    expect(find.text('Dinheiro em conta parada não rende'), findsOneWidget);
  });
}
