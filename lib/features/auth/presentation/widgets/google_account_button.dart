import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/google_web_button.dart';

class GoogleAccountButton extends StatefulWidget {
  const new({
    required this.label,
    required this.rendersOwnButton,
    required this.idTokens,
    required this.onPressed,
    required this.onIdToken,
    super.key,
  });

  final String label;
  final bool rendersOwnButton;
  final Stream<String> idTokens;
  final VoidCallback onPressed;
  final ValueChanged<String> onIdToken;

  @override
  State<GoogleAccountButton> createState() => _GoogleAccountButtonState();
}

class _GoogleAccountButtonState extends State<GoogleAccountButton> {
  late final StreamSubscription<String> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.idTokens.listen((token) => widget.onIdToken(token));
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rendersOwnButton) {
      return Center(child: googleWebButton());
    }
    return OutlinedButton.icon(
      key: const Key('google_sign_in'),
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(widget.label),
      onPressed: widget.onPressed,
    );
  }
}
