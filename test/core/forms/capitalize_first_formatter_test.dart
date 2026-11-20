import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/capitalize_first_formatter.dart';

void main() {
  final formatter = CapitalizeFirstFormatter();

  TextEditingValue format(String text, {int? cursor}) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  test('uppercases the first letter', () {
    expect(format('aluguel').text, 'Aluguel');
  });

  test('uppercases accented first letters', () {
    expect(format('água').text, 'Água');
  });

  test('skips leading spaces', () {
    expect(format('  luz').text, '  Luz');
  });

  test('keeps the rest of the text as typed', () {
    expect(format('conta de luz').text, 'Conta de luz');
  });

  test('keeps the cursor position', () {
    expect(format('luz', cursor: 1).selection.baseOffset, 1);
  });

  test('leaves empty and blank text unchanged', () {
    expect(format('').text, '');
    expect(format('   ').text, '   ');
  });

  test('leaves text that already starts uppercase or with a digit', () {
    expect(format('Netflix').text, 'Netflix');
    expect(format('13º salário').text, '13º salário');
  });

  test('leaves letters whose uppercase changes the length', () {
    expect(format('ßtraße').text, 'ßtraße');
  });
}
