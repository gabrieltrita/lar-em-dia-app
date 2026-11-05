import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/account/presentation/cubits/account_cubits.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class UnsubscribePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<UnsubscribeCubit, LoadState<NotificationSettings>>(
            builder: (context, state) => switch (state) {
              Loading() => const CircularProgressIndicator(),
              LoadFailure(:final error) => InfoMessage(error.localized(l10n)),
              Loaded() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoMessage(l10n.unsubscribeDone),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.unsubscribeOpenApp),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
