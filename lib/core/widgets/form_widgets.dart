import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

FormFieldValidator<String> validateWith(
  AppLocalizations l10n,
  ValidationError? Function(String? value) rule,
) =>
    (value) => rule(value)?.localized(l10n);

class SubmitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const new(this.messages, {super.key});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in messages)
            Text(message, style: TextStyle(color: colors.onErrorContainer)),
        ],
      ),
    );
  }
}

class InfoMessage extends StatelessWidget {
  const new(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, textAlign: TextAlign.center);
  }
}

class ConsentField extends FormField<bool> {
  new({required String label, required String requiredMessage, super.key})
    : super(
        initialValue: false,
        validator: (value) => value! ? null : requiredMessage,
        builder: (field) => CheckboxListTile(
          value: field.value,
          onChanged: field.didChange,
          title: Text(label),
          subtitle: field.errorText == null
              ? null
              : Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(field.context).colorScheme.error,
                  ),
                ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      );
}

class RetryMessage extends StatelessWidget {
  const new({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
