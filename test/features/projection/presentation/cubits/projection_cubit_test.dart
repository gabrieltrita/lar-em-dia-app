import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockProjectionRepository repository;

  setUpAll(registerFinanceFallbacks);
  setUp(() => repository = MockProjectionRepository());

  test('flags negative months', () {
    expect(novemberProjection.isNegative, isFalse);
    expect(decemberProjection.isNegative, isTrue);
  });

  blocTest<ProjectionCubit, LoadState<Projection>>(
    'loads twelve months from the current month',
    setUp: () =>
        when(() => repository.fetch(from: november, months: 12))
            .thenAnswer((_) async => projection),
    build: () => ProjectionCubit(repository),
    act: (cubit) => cubit.load(today: DateTime(2026, 11, 3)),
    expect: () => [
      const LoadState<Projection>.loading(),
      LoadState.loaded(projection),
    ],
  );

  blocTest<ProjectionCubit, LoadState<Projection>>(
    'uses today by default and reports failures',
    setUp: () => when(
      () => repository.fetch(
        from: Dates.firstOfMonth(DateTime.now()),
        months: 12,
      ),
    ).thenThrow(const ApiError(code: 'network_error')),
    build: () => ProjectionCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => const [
      LoadState<Projection>.loading(),
      LoadState<Projection>.failure(ApiError(code: 'network_error')),
    ],
  );
}
