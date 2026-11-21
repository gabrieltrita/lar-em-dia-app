import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

part 'category.freezed.dart';

@freezed
abstract class Category with _$Category {
  const factory({
    required String id,
    required EntryKind kind,
    required String key,
    required String name,
    EntryNature? defaultNature,
    @Default(false) bool custom,
  }) = _Category;
}
