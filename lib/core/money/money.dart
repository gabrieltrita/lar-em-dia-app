import 'package:intl/intl.dart';

abstract final class Money {
  static final _grouping = NumberFormat.decimalPattern('pt_BR');
  static final _compact = NumberFormat.compact(locale: 'pt_BR');
  static final _amount = RegExp(
    r'^(-)?(\d{1,3}(?:\.\d{3})*|\d+)(?:,(\d{1,2}))?$',
  );

  static String format(int cents) {
    final sign = cents < 0 ? '-' : '';
    return '${sign}R\$ ${formatAmount(cents.abs())}';
  }

  static String formatAmount(int cents) {
    final absolute = cents.abs();
    final sign = cents < 0 ? '-' : '';
    final units = _grouping.format(absolute ~/ 100);
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '$sign$units,$fraction';
  }

  static String compact(int cents, {bool signed = false}) {
    final sign = switch (cents) {
      < 0 => '−',
      > 0 when signed => '+',
      _ => '',
    };
    return '$sign${_compact.format(cents.abs() / 100)}';
  }

  static int? parse(String text) {
    final match = _amount.firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    final units = int.parse(match.group(2)!.replaceAll('.', ''));
    final fraction = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    final cents = units * 100 + fraction;
    return match.group(1) == null ? cents : -cents;
  }
}
