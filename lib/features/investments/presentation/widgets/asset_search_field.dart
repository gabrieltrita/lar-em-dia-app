import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AssetSearchField extends StatefulWidget {
  const new({required this.onSelected, this.errorText, super.key});

  final ValueChanged<Asset> onSelected;
  final String? errorText;

  @override
  State<AssetSearchField> createState() => _AssetSearchFieldState();
}

class _AssetSearchFieldState extends State<AssetSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('asset_search'),
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: l10n.investmentFormAsset,
            hintText: l10n.investmentFormAssetHint,
            prefixIcon: const Icon(Icons.search),
            errorText: widget.errorText,
          ),
          onChanged: context.read<AssetSearchCubit>().search,
        ),
        BlocBuilder<AssetSearchCubit, List<Asset>>(
          builder: (context, assets) => Column(
            children: [
              for (final asset in assets)
                ListTile(
                  title: Text(asset.ticker),
                  subtitle: Text(asset.name),
                  trailing: Text(asset.type.label(l10n)),
                  onTap: () => widget.onSelected(asset),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
