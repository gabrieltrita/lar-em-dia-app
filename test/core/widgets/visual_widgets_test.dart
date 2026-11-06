import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/theme/app_theme.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/core/widgets/empty_state.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';

Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  bool disableAnimations = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  group('MoneyText', () {
    Text textOf(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

    testWidgets('formats with tabular figures and no color by default', (
      tester,
    ) async {
      await pumpThemed(tester, const MoneyText(123456));

      final text = textOf(tester);
      expect(text.data, r'R$ 1.234,56');
      expect(text.style?.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(text.style?.color, isNot(FinanceColors.light.positive));
    });

    testWidgets('signs positive amounts and colors them by sign', (
      tester,
    ) async {
      final style = AppTheme.dark.textTheme.titleLarge;
      await pumpThemed(
        tester,
        Column(
          children: [
            MoneyText(500, signed: true, colored: true, style: style),
            const MoneyText(-500, signed: true, colored: true),
            const MoneyText(0, signed: true, colored: true),
          ],
        ),
        theme: AppTheme.dark,
      );

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts[0].data, r'+R$ 5,00');
      expect(texts[0].style?.color, FinanceColors.dark.positive);
      expect(texts[0].style?.fontSize, style?.fontSize);
      expect(texts[1].data, r'-R$ 5,00');
      expect(texts[1].style?.color, AppTheme.dark.colorScheme.error);
      expect(texts[2].data, r'R$ 0,00');
    });

    test('formats without a widget', () {
      expect(MoneyText.format(100, signed: true), r'+R$ 1,00');
      expect(MoneyText.format(100), r'R$ 1,00');
      expect(MoneyText.format(-100, signed: true), r'-R$ 1,00');
    });
  });

  group('SkeletonList', () {
    testWidgets('pulses and announces the loading', (tester) async {
      await pumpThemed(tester, const SkeletonList(label: 'Carregando'));

      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SkeletonList),
          matching: find.byType(FadeTransition),
        ),
      );
      final start = fade.opacity.value;
      await tester.pump(const Duration(milliseconds: 450));
      expect(fade.opacity.value, isNot(start));
    });

    testWidgets('stays still when animations are disabled', (tester) async {
      await pumpThemed(
        tester,
        const SkeletonList(label: 'Carregando', itemCount: 2),
        disableAnimations: true,
      );

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SkeletonList),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(fade.opacity.value, 1);
      expect(find.byType(SkeletonBox), findsNWidgets(8));
    });
  });

  group('EmptyState', () {
    testWidgets('shows the message and runs the action', (tester) async {
      var tapped = false;
      await pumpThemed(
        tester,
        EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Nada aqui',
          message: 'Cadastre algo',
          actionLabel: 'Cadastrar',
          onAction: () => tapped = true,
        ),
      );

      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.text('Nada aqui'), findsOneWidget);
      expect(find.text('Cadastre algo'), findsOneWidget);
      await tester.tap(find.text('Cadastrar'));
      expect(tapped, isTrue);
    });

    testWidgets('has no button without an action', (tester) async {
      await pumpThemed(
        tester,
        const EmptyState(icon: Icons.inbox, title: 'Vazio', message: 'Nada'),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
