import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/layout/breakpoints.dart';

GoRoute formRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
  GoRouterRedirect? redirect,
}) => GoRoute(
  path: path,
  redirect: redirect,
  pageBuilder: (context, state) =>
      adaptivePage(context, key: state.pageKey, child: builder(context, state)),
);

Page<void> adaptivePage(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) => Breakpoints.isDesktop(context)
    ? DialogPage(key: key, child: child)
    : MaterialPage(key: key, child: child);

class DialogPage<T> extends Page<T> {
  const new({required this.child, super.key});

  static const width = 560.0;

  static const maxHeight = 760.0;

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
    context: context,
    settings: this,
    builder: (context) {
      final screen = MediaQuery.sizeOf(context);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: width,
          height: math.min(maxHeight, screen.height - 48),
          child: child,
        ),
      );
    },
  );
}
