import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';

part 'balance_dto.freezed.dart';
part 'balance_dto.g.dart';

@freezed
abstract class BalanceDto with _$BalanceDto {
  const factory({
    required String id,
    required int amountCents,
    required String asOf,
  }) = _BalanceDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$BalanceDtoFromJson(json);

  Balance toDomain() =>
      Balance(id: id, amountCents: amountCents, asOf: Dates.parseIso(asOf));
}
