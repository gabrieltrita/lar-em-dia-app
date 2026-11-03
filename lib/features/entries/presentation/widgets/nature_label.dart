import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String natureLabel(AppLocalizations l10n, EntryNature nature) =>
    switch (nature) {
      EntryNature.fixed => l10n.entryNatureFixed,
      EntryNature.variable => l10n.entryNatureVariable,
    };
