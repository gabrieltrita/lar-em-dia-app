import 'package:flutter/material.dart';

void paintLabel(
  Canvas canvas,
  String text,
  Offset anchor, {
  required TextStyle style,
  TextAlign align = TextAlign.center,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.right || TextAlign.end => anchor.dx - painter.width,
    TextAlign.left || TextAlign.start => anchor.dx,
    _ => anchor.dx - painter.width / 2,
  };
  painter
    ..paint(canvas, Offset(dx, anchor.dy - painter.height / 2))
    ..dispose();
}
