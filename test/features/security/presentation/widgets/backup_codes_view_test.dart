import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/security/presentation/widgets/backup_codes_view.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

import '../../../../helpers/clipboard.dart';
import '../../../../helpers/security_fixtures.dart';

void main() {
  testWidgets('copies every code and finishes', (tester) async {
    final copied = recordClipboard(tester);
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BackupCodesView(codes: backupCodes, onDone: () => done++),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Copiar códigos'));
    await tester.pumpAndSettle();
    expect(copied, [backupCodes.join('\n')]);
    expect(find.text('Copiado.'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    expect(done, 1);
  });
}
