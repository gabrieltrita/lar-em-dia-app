import 'package:intl/intl.dart';

abstract final class PerShare {
  static const centsToE8 = 1000000;
  static const e8Decimals = 8;
  static const e8PerUnit = 100000000;
  static final _input = RegExp(r'^(\d{1,9})(?:,(\d{1,8}))?$');
  static const _decimals = 4;
  static const _e8PerUnit = 10000;
  static final _grouping = NumberFormat.decimalPattern('pt_BR');

  static String formatE8(int e8) {
    final sign = e8 < 0 ? '-' : '';
    final scaled = roundedDivision(e8.abs(), _e8PerUnit);
    final units = scaled ~/ 10000;
    var fraction = (scaled % 10000).toString().padLeft(_decimals, '0');
    while (fraction.length > 2 && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    return '${sign}R\$ ${_grouping.format(units)},$fraction';
  }

  static int? parseE8(String text) {
    final compact = text.replaceAll(r'R$', '').replaceAll(RegExp(r'\s'), '');
    final cleaned = compact.contains(',')
        ? compact.replaceAll('.', '')
        : compact.replaceAll('.', ',');
    final match = _input.firstMatch(cleaned);
    if (match == null) {
      return null;
    }
    final fraction = (match.group(2) ?? '').padRight(e8Decimals, '0');
    final value = int.parse(match.group(1)!) * e8PerUnit + int.parse(fraction);
    return value > 0 ? value : null;
  }

  static String inputE8(int e8) {
    var fraction = (e8 % e8PerUnit).toString().padLeft(e8Decimals, '0');
    while (fraction.length > 2 && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    return '${e8 ~/ e8PerUnit},$fraction';
  }

  static int? basisPoints(int part, int whole) =>
      whole == 0 ? null : roundedDivision(part * 10000, whole);

  static String percentFromBps(int bps, {bool signed = false}) {
    final sign = switch (bps) {
      < 0 => '−',
      > 0 when signed => '+',
      _ => '',
    };
    final absolute = bps.abs();
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '$sign${absolute ~/ 100},$fraction%';
  }

  static int roundedDivision(int numerator, int denominator) {
    final negative = (numerator < 0) != (denominator < 0);
    final quotient =
        (2 * numerator.abs() + denominator.abs()) ~/ (2 * denominator.abs());
    return negative ? -quotient : quotient;
  }
}
