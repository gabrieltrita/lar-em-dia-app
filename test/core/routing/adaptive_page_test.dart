import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/routing/adaptive_page.dart';

void main() {
  Future<GoRouter> pumpRouter(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        formRoute(
          path: '/form',
          redirect: (_, state) => state.extra == false ? '/' : null,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(true),
              child: const Text('save'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return router;
  }

  testWidgets('opens forms as a dialog on desktop and returns the result', (
    tester,
  ) async {
    final router = await pumpRouter(tester, const Size(1400, 900));
    final result = router.push<bool>('/form');
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(
      tester.getSize(find.byType(Scaffold).last),
      const Size(DialogPage.width, DialogPage.maxHeight),
    );
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('opens forms as a full page on phones', (tester) async {
    final router = await pumpRouter(tester, const Size(400, 800));
    unawaited(router.push<bool>('/form'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('save'), findsOneWidget);
  });

  testWidgets('keeps the route redirect', (tester) async {
    final router = await pumpRouter(tester, const Size(400, 800));
    router.go('/form', extra: false);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
