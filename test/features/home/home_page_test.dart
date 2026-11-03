import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/di/injection.dart';

void main() {
  setUpAll(configureDependencies);

  testWidgets('opens on the home page in Portuguese', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Lar em Dia'), findsOneWidget);
    expect(find.text('Seu orçamento familiar, mês a mês'), findsOneWidget);
  });
}
