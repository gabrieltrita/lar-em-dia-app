import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

part 'entry_dtos.freezed.dart';
part 'entry_dtos.g.dart';

@freezed
abstract class CategoryDto with _$CategoryDto {
  const factory({
    required String id,
    required EntryKind kind,
    required String key,
    required String name,
  }) = _CategoryDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$CategoryDtoFromJson(json);

  Category toDomain() => Category(id: id, kind: kind, key: key, name: name);
}

@freezed
abstract class EntryDto with _$EntryDto {
  const factory({
    required String id,
    required EntryKind kind,
    required String categoryId,
    required String description,
    required int amountCents,
    required String dueOn,
    required EntryStatus status,
    String? paidOn,
  }) = _EntryDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$EntryDtoFromJson(json);

  Entry toDomain() => Entry(
    id: id,
    kind: kind,
    categoryId: categoryId,
    description: description,
    amountCents: amountCents,
    dueOn: Dates.parseIso(dueOn),
    status: status,
    paidOn: paidOn == null ? null : Dates.parseIso(paidOn!),
  );
}
