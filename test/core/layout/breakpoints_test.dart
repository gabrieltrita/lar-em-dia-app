import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/layout/breakpoints.dart';

void main() {
  for (final (width, desktop) in [(1023.0, false), (1024.0, true)]) {
    testWidgets('treats $width logical pixels as desktop: $desktop', (
      tester,
    ) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              result = Breakpoints.isDesktop(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, desktop);
    });
  }
}
