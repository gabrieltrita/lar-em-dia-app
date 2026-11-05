import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';

void main() {
  group('Money', () {
    test('formats cents as BRL without floating point', () {
      expect(Money.format(0), r'R$ 0,00');
      expect(Money.format(5), r'R$ 0,05');
      expect(Money.format(123456789), r'R$ 1.234.567,89');
      expect(Money.format(-150), r'-R$ 1,50');
      expect(Money.formatAmount(-150), '-1,50');
    });

    test('parses BRL amounts into cents', () {
      expect(Money.parse('1.234,56'), 123456);
      expect(Money.parse(' 1234,5 '), 123450);
      expect(Money.parse('10'), 1000);
      expect(Money.parse('-0,99'), -99);
      expect(Money.parse('1,234'), isNull);
      expect(Money.parse('12.34'), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse(''), isNull);
    });
  });

  group('MoneyInputFormatter', () {
    TextEditingValue type(MoneyInputFormatter formatter, String text) =>
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: text),
        );

    test('shifts typed digits into cents', () {
      final formatter = MoneyInputFormatter();

      expect(type(formatter, '1').text, '0,01');
      expect(type(formatter, '0,012').text, '0,12');
      expect(type(formatter, '123456').text, '1.234,56');
      expect(type(formatter, '-5').text, '0,05');
      expect(type(formatter, '').text, '');
      expect(type(formatter, '1234').selection.baseOffset, 5);
    });

    test('keeps a leading minus when negatives are allowed', () {
      final formatter = MoneyInputFormatter(allowNegative: true);

      expect(type(formatter, '-').text, '-');
      expect(type(formatter, '-150').text, '-1,50');
    });

    test('ignores digits beyond fifteen', () {
      expect(
        type(MoneyInputFormatter(), '1' * 20).text,
        '1.111.111.111.111,11',
      );
    });
  });
}
