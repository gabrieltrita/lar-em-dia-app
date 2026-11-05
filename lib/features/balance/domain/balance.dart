import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance.freezed.dart';

@freezed
abstract class Balance with _$Balance {
  const factory({
    required String id,
    required int amountCents,
    required DateTime asOf,
  }) = _Balance;
}
