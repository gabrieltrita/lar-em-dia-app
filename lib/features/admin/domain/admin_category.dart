import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

part 'admin_category.freezed.dart';

@freezed
abstract class AdminCategory with _$AdminCategory {
  const factory({
    required String id,
    required EntryKind kind,
    required String key,
    required String name,
    required int position,
    required bool active,
    EntryNature? defaultNature,
  }) = _AdminCategory;

  const new _();

  Category toCategory() => Category(
    id: id,
    kind: kind,
    key: key,
    name: name,
    defaultNature: defaultNature,
  );

  CategoryDraft toDraft() => CategoryDraft(
    kind: kind,
    key: key,
    name: name,
    position: position,
    active: active,
    defaultNature: defaultNature,
  );
}

@freezed
abstract class CategoryDraft with _$CategoryDraft {
  const factory({
    required EntryKind kind,
    required String key,
    required String name,
    required int position,
    required bool active,
    EntryNature? defaultNature,
  }) = _CategoryDraft;

  static final keyFormat = RegExp(r'^[a-z][a-z0-9_]*$');
}
