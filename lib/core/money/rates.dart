import 'package:lar_em_dia/core/money/per_share.dart';

abstract final class Rates {
  static const _e8PerBps = 10000;
  static final _hundredths = RegExp(r'^(-?)(\d{1,7})(?:[,.](\d{1,2}))?$');

  static String percentFromBps(int bps) {
    final text = PerShare.percentFromBps(bps);
    return text.replaceFirst(RegExp(r',?0+%$'), '%');
  }

  static String percentFromE8(int e8) =>
      percentFromBps(PerShare.roundedDivision(e8, _e8PerBps));

  static String months(int monthsE2) {
    final tenths = PerShare.roundedDivision(monthsE2, 10);
    final whole = tenths ~/ 10;
    final fraction = tenths % 10;
    return fraction == 0 ? '$whole' : '$whole,$fraction';
  }

  static int? parseHundredths(String text) {
    final cleaned = text.replaceAll('%', '').replaceAll(RegExp(r'\s'), '');
    final match = _hundredths.firstMatch(cleaned);
    if (match == null) {
      return null;
    }
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final value = int.parse(match.group(2)!) * 100 + int.parse(fraction);
    return match.group(1)!.isEmpty ? value : -value;
  }

  static String hundredths(int value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    final whole = absolute ~/ 100;
    if (absolute % 100 == 0) {
      return '$sign$whole';
    }
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '$sign$whole,${fraction.endsWith('0') ? fraction[0] : fraction}';
  }
}
