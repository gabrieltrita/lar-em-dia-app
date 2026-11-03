import 'package:intl/intl.dart';

abstract final class Dates {
  static final _display = DateFormat('dd/MM/yyyy');

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String toIso(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static DateTime parseIso(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String display(DateTime value) => _display.format(value);

  static DateTime firstOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  static DateTime lastOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0);

  static DateTime addMonths(DateTime month, int months) =>
      DateTime(month.year, month.month + months);

  static DateTime? parseMonth(String? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      return null;
    }
    return DateTime(int.parse(match.group(1)!), month);
  }
}
