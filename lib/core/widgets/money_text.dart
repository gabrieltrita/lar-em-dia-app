import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';

class MoneyText extends StatelessWidget {
  const new(
    this.cents, {
    super.key,
    this.style,
    this.signed = false,
    this.colored = false,
    this.textAlign,
  });

  final int cents;
  final TextStyle? style;
  final bool signed;
  final bool colored;
  final TextAlign? textAlign;

  static String format(int cents, {bool signed = false}) =>
      signed && cents > 0 ? '+${Money.format(cents)}' : Money.format(cents);

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final color = colored ? FinanceColors.of(context).forAmount(cents) : null;
    return Text(
      format(cents, signed: signed),
      textAlign: textAlign,
      style: base.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
