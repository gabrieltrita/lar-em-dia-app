import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

class _EchoCubit extends SubmissionCubit<int>;

void main() {
  test('starts idle', () {
    expect(_EchoCubit().state, isA<SubmissionIdle<int>>());
  });

  blocTest<_EchoCubit, Submission<int>>(
    'emits progress and then the value',
    build: _EchoCubit.new,
    act: (cubit) => cubit.run(() async => 42),
    expect: () => const [Submission<int>.inProgress(), Submission.success(42)],
  );

  blocTest<_EchoCubit, Submission<int>>(
    'emits the API error as a failure',
    build: _EchoCubit.new,
    act: (cubit) =>
        cubit.run(() async => throw const ApiError(code: 'rate_limited')),
    expect: () => const [
      Submission<int>.inProgress(),
      Submission<int>.failure(ApiError(code: 'rate_limited')),
    ],
  );

  blocTest<_EchoCubit, Submission<int>>(
    'ignores a new run while one is in progress',
    build: _EchoCubit.new,
    act: (cubit) async {
      final pending = Completer<int>();
      final first = cubit.run(() => pending.future);
      await cubit.run(() async => 7);
      pending.complete(1);
      await first;
    },
    expect: () => const [Submission<int>.inProgress(), Submission.success(1)],
  );
}
