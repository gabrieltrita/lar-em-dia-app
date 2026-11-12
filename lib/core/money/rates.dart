import 'package:lar_em_dia/core/money/per_share.dart';

abstract final class Rates {
  static const _e8PerBps = 10000;

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
}
