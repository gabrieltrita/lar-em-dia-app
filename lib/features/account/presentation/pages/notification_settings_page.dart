import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/account/presentation/cubits/account_cubits.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class NotificationSettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NotificationSettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body:
          BlocBuilder<
            NotificationSettingsCubit,
            LoadState<NotificationSettings>
          >(
            builder: (context, state) => switch (state) {
              Loading() => const Center(child: CircularProgressIndicator()),
              LoadFailure(:final error) => RetryMessage(
                message: error.localized(l10n),
                onRetry: () => unawaited(cubit.load()),
              ),
              Loaded(value: final settings) => _SettingsForm(
                settings: settings,
              ),
            },
          ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const new({required this.settings});

  final NotificationSettings settings;

  Future<void> _update(
    BuildContext context,
    NotificationSettings changed,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<NotificationSettingsCubit>().update(
      changed,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          key: const Key('notifications_enabled'),
          title: Text(l10n.notificationsEmailLabel),
          subtitle: Text(l10n.notificationsEmailHint),
          value: settings.enabled,
          onChanged: (value) =>
              unawaited(_update(context, settings.copyWith(enabled: value))),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const Key('notifications_days_before'),
          initialValue: settings.daysBefore,
          decoration: InputDecoration(labelText: l10n.notificationsDaysLabel),
          items: [
            for (
              var days = NotificationSettings.minDays;
              days <= NotificationSettings.maxDays;
              days++
            )
              DropdownMenuItem(
                value: days,
                child: Text(l10n.notificationsDaysBefore(days)),
              ),
          ],
          onChanged: settings.enabled
              ? (value) => unawaited(
                  _update(context, settings.copyWith(daysBefore: value!)),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(l10n.notificationsWebHint),
      ],
    );
  }
}
