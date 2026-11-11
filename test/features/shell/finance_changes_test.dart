import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';

void main() {
  test('refresh clears the cache and notifies every listener', () {
    final cache = FinanceCache()..categories[EntryKind.income] = [];
    var notified = 0;
    FinanceChanges(cache)
      ..addListener(() => notified++)
      ..refresh();

    expect(cache.categories, isEmpty);
    expect(notified, 1);
  });
}
