import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceCache cache;

  ProjectionMonth row(DateTime month, {int opening = 0, int closing = 0}) =>
      ProjectionMonth(
        month: month,
        openingCents: opening,
        incomeCents: 0,
        expenseCents: 0,
        fixedExpenseCents: 0,
        variableExpenseCents: 0,
        closingCents: closing,
        savingsCents: 0,
      );

  Projection rows(DateTime first, int count, {DateTime? lastEntryMonth}) =>
      Projection(
        lastEntryMonth: lastEntryMonth,
        months: [
          for (var index = 0; index < count; index++)
            row(
              DateTime(first.year, first.month + index),
              opening: index * 10,
              closing: (index + 1) * 10,
            ),
        ],
      );

  setUp(() => cache = FinanceCache());

  test('shares a pending load and starts again once it ends', () async {
    final completer = Completer<int>();
    var loads = 0;
    Future<int> load() {
      loads++;
      return completer.future;
    }

    final first = cache.once('key', load);
    final second = cache.once('key', load);
    completer.complete(7);

    expect(await first, 7);
    expect(await second, 7);
    expect(loads, 1);

    await cache.once('key', () async => 8);
    expect(loads, 1);
  });

  test('clear forgets everything and pending loads', () async {
    final completer = Completer<int>();
    final pending = cache.once('key', () => completer.future);
    cache
      ..categories[EntryKind.income] = [salaryCategory]
      ..storeMonths(november, november, [salary])
      ..storeProjection(rows(november, 1))
      ..latestBalance = Balance(id: 'b', amountCents: 1, asOf: november);
    final generation = cache.generation;

    cache.clear();
    expect(await cache.once('key', () async => 2), 2);
    completer.complete(1);
    await pending;

    expect(cache.generation, generation + 1);
    expect(cache.categories, isEmpty);
    expect(cache.hasMonth(november), isFalse);
    expect(cache.projectionWindow, isNull);
    expect(cache.latestBalanceKnown, isFalse);
    expect(cache.latestBalance, isNull);
  });

  test('keeps entries only in loaded months, sorted by due date', () {
    final later = salary.copyWith(id: 'later', dueOn: DateTime(2026, 11, 20));
    final outside = salary.copyWith(id: 'outside', dueOn: DateTime(2027, 3));
    cache
      ..storeMonths(november, DateTime(2026, 12), [later])
      ..upsertEntries([salary, outside]);

    expect(cache.entriesBetween(november, DateTime(2026, 12, 31)), [
      salary,
      later,
    ]);
    expect(cache.entriesBetween(DateTime(2026, 11, 6), DateTime(2027, 3, 31)), [
      later,
    ]);
    expect(cache.loadedRun(DateTime(2026, 12), DateTime(2026, 12)), (
      november,
      DateTime(2026, 12),
    ));
  });

  test('replaces a series and removes entries', () {
    final first = salary.copyWith(id: 's1', seriesId: 'series');
    final second = salary.copyWith(id: 's2', seriesId: 'series');
    cache
      ..storeMonths(november, november, [first, second, rent])
      ..replaceSeries('series', [second.copyWith(amountCents: 1)])
      ..removeEntries({rent.id});

    expect(cache.entriesBetween(november, DateTime(2026, 11, 30)), [
      second.copyWith(amountCents: 1),
    ]);
  });

  group('projection', () {
    test('joins contiguous or overlapping ranges', () {
      cache
        ..storeProjection(rows(november, 2))
        ..storeProjection(rows(DateTime(2027), 2))
        ..storeProjection(rows(DateTime(2026, 12), 2));

      expect(cache.projectionWindow, (from: november, months: 4));
    });

    test('replaces the range when it would leave a gap or grow too long', () {
      cache
        ..storeProjection(rows(november, 2))
        ..storeProjection(rows(DateTime(2027, 6), 1));
      expect(cache.projectionWindow, (from: DateTime(2027, 6), months: 1));

      cache.storeProjection(rows(DateTime(2027, 7), 60));
      expect(cache.projectionWindow, (from: DateTime(2027, 7), months: 60));

      cache.storeProjection(const Projection(months: []));
      expect(cache.projectionWindow, isNull);
    });

    test('slices a period and recounts savings and negative months', () {
      final source = Projection(
        months: [
          row(november, opening: 100, closing: -50),
          row(DateTime(2026, 12), opening: -50, closing: 70),
          row(DateTime(2027), opening: 70, closing: -10),
          row(DateTime(2027, 2), opening: -10, closing: 30),
        ],
      );
      cache.storeProjection(source);

      final slice = cache.projection(
        DateTime(2026, 12),
        ProjectionPeriod.threeMonths,
      )!;

      expect(slice.months.map((month) => month.savingsCents), [120, 40, 80]);
      expect(slice.firstNegativeMonth, DateTime(2027));
      expect(slice.negativeMonthsCount, 1);
      expect(
        cache.projection(DateTime(2027), ProjectionPeriod.threeMonths),
        isNull,
      );
      expect(
        cache.projection(DateTime(2026, 10), ProjectionPeriod.all),
        isNull,
      );
    });

    test('slices all months through the last entry, at most 60', () {
      expect(cache.projection(november, ProjectionPeriod.all), isNull);
      expect(
        FinanceCache.slice(
          const Projection(months: []),
          november,
          ProjectionPeriod.all,
        ),
        isNull,
      );

      final long = rows(november, 70, lastEntryMonth: DateTime(2033));
      expect(
        FinanceCache.slice(long, november, ProjectionPeriod.all)!.months,
        hasLength(60),
      );
      final short = rows(november, 3, lastEntryMonth: DateTime(2026, 12));
      expect(
        FinanceCache.slice(short, november, ProjectionPeriod.all)!.months,
        hasLength(2),
      );
      final past = rows(november, 3, lastEntryMonth: DateTime(2026));
      expect(
        FinanceCache.slice(past, november, ProjectionPeriod.all)!.months,
        hasLength(1),
      );
    });

    test('adds the cached range to change requests', () {
      expect(cache.withProjectionWindow('/entries'), '/entries');
      expect(
        cache.withProjectionWindow('/entries/1', query: {'scope': 'all'}),
        '/entries/1?scope=all',
      );

      cache.storeProjection(rows(november, 3));

      expect(
        cache.withProjectionWindow('/entries'),
        '/entries?projection_from=2026-11&projection_months=3',
      );
    });

    test('applies a projection answered by a change', () {
      cache
        ..storeProjection(rows(november, 3))
        ..applyProjectionMeta({})
        ..applyProjectionMeta({'projection': 'not a projection'});
      expect(cache.projectionWindow, (from: november, months: 3));

      cache.applyProjectionMeta({
        'projection': {
          'anchor': null,
          'months': [
            {
              'month': '2027-01',
              'opening_cents': 0,
              'income_cents': 0,
              'expense_cents': 0,
              'fixed_expense_cents': 0,
              'variable_expense_cents': 0,
              'closing_cents': 0,
              'savings_cents': 0,
            },
          ],
        },
      });
      expect(cache.projectionWindow, (from: DateTime(2027), months: 1));
    });
  });
}
