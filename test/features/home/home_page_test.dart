import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  late MockAuthRepository repository;

  setUpAll(() {
    configureDependencies();
    repository = MockAuthRepository();
    getIt
      ..allowReassignment = true
      ..registerSingleton<AuthRepository>(repository);
  });

  testWidgets('greets the signed in user and logs out', (tester) async {
    when(repository.logout).thenAnswer((_) async {});
    await tester.pumpWidget(const App());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    getIt<SessionCubit>().signedIn(ana);
    await tester.pumpAndSettle();
    expect(find.text('Olá, Ana!'), findsOneWidget);
    expect(find.text('Seu orçamento familiar, mês a mês'), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    verify(repository.logout).called(1);
    expect(find.text('Entrar'), findsWidgets);
  });
}
