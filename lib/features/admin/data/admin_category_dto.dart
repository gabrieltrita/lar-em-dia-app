import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

part 'admin_category_dto.freezed.dart';
part 'admin_category_dto.g.dart';

@freezed
abstract class AdminCategoryDto with _$AdminCategoryDto {
  const factory({
    required String id,
    required EntryKind kind,
    required String key,
    required String name,
    @Default(0) int position,
    @Default(true) bool active,
    EntryNature? defaultNature,
  }) = _AdminCategoryDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AdminCategoryDtoFromJson(json);

  AdminCategory toDomain() => AdminCategory(
    id: id,
    kind: kind,
    key: key,
    name: name,
    position: position,
    active: active,
    defaultNature: defaultNature,
  );
}
