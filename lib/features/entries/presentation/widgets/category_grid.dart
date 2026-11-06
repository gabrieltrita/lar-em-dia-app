import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class CategoryGrid extends StatelessWidget {
  const new({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  static const minTileWidth = 80.0;
  static const spacing = 4.0;

  final List<Category> categories;
  final String? selected;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minTileWidth + spacing))
                .floor()
                .clamp(1, 12);
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: spacing,
            runSpacing: 8,
            children: [
              for (final category in categories)
                SizedBox(
                  width: tileWidth,
                  child: Semantics(
                    button: true,
                    selected: category.id == selected,
                    child: InkWell(
                      key: ValueKey('category_${category.key}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelected(category),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: category.id == selected
                              ? theme.colorScheme.secondaryContainer
                              : null,
                          border: Border.all(
                            color: category.id == selected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            CategoryAvatar(category: category),
                            const SizedBox(height: 4),
                            Text(
                              categoryLabel(l10n, category),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
