import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/date_field.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<void> pumpLocalized(WidgetTester tester, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('DateField picks a date and drops the time', (tester) async {
    DateTime? picked;
    await pumpLocalized(
      tester,
      DateField(
        label: 'Data',
        value: DateTime(2026, 11, 3),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026, 12, 31),
        onChanged: (value) => picked = value,
      ),
    );
    expect(find.text('03/11/2026'), findsOneWidget);

    await tester.tap(find.byType(DateField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 11, 10));
  });

  testWidgets('DateField keeps the value when the picker is cancelled', (
    tester,
  ) async {
    DateTime? picked;
    await pumpLocalized(
      tester,
      DateField(
        label: 'Data',
        value: DateTime(2026, 11, 3),
        firstDate: DateTime(2026),
        lastDate: DateTime(2026, 12, 31),
        onChanged: (value) => picked = value,
      ),
    );

    await tester.tap(find.byType(DateField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  for (final (label, expected) in [('Apagar', true), ('Cancelar', false)]) {
    testWidgets('confirmDeletion answers $expected on $label', (tester) async {
      bool? answer;
      await pumpLocalized(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await confirmDeletion(
              context,
              title: 'Apagar?',
              message: 'Some',
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Some'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(answer, expected);
    });
  }

  testWidgets('confirmDeletion answers false when dismissed', (tester) async {
    bool? answer;
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await confirmDeletion(
            context,
            title: 'Apagar?',
            message: 'Some',
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });

  testWidgets('RetryMessage shows the message and retries', (tester) async {
    var retries = 0;
    await pumpLocalized(
      tester,
      RetryMessage(message: 'Falhou', onRetry: () => retries++),
    );

    await tester.tap(find.text('Tentar de novo'));

    expect(find.text('Falhou'), findsOneWidget);
    expect(retries, 1);
  });
}
