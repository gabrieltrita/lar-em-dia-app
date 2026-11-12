import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/demo/demo_database.dart';
import 'package:lar_em_dia/demo/demo_investments.dart';

abstract final class DemoSeed {
  static const email = 'ana@demo.laremdia.app';
  static const password = 'Demo1234';

  static const user = <String, Object?>{
    'id': 'user-demo',
    'email': email,
    'first_name': 'Ana',
    'last_name': 'Demo',
    'two_factor_enabled': false,
  };

  static const income = {
    'salary': 'Salary',
    'thirteenth_salary': '13th salary',
    'vacation_bonus': 'Vacation bonus',
    'bonus': 'Bonus and profit sharing',
    'extra_income': 'Extra income',
    'rent_received': 'Rent received',
    'alimony_received': 'Alimony received',
    'tax_refund': 'Tax refund',
    'reimbursement': 'Reimbursement',
    'other_income': 'Other income',
    'investment_redemption': 'Investment redemption',
  };

  static const fixedExpenses = {
    'housing': 'Housing',
    'utilities': 'Utilities',
    'internet_phone': 'Internet and phone',
    'subscriptions': 'Subscriptions',
    'education': 'Education',
    'insurance': 'Insurance',
    'health_plan': 'Health plan',
    'loans': 'Loans',
  };

  static const variableExpenses = {
    'groceries': 'Groceries',
    'restaurants': 'Restaurants',
    'transport': 'Transport',
    'health': 'Health',
    'leisure': 'Leisure',
    'travel': 'Travel',
    'clothing': 'Clothing',
    'personal_care': 'Personal care',
    'pets': 'Pets',
    'gifts_donations': 'Gifts and donations',
    'taxes_fees': 'Taxes and fees',
    'other_expense': 'Other expense',
    'investment_contribution': 'Investment contribution',
  };

  static const _monthly = [
    ('salary', 'Salário', 620000, 5),
    ('health_plan', 'Plano de saúde', 90000, 7),
    ('groceries', 'Mercado', 140000, 8),
    ('housing', 'Aluguel', 230000, 10),
    ('internet_phone', 'Internet e celular', 15000, 12),
    ('utilities', 'Luz, água e gás', 45000, 15),
    ('leisure', 'Lazer', 60000, 20),
  ];

  static const months = 24;
  static const tripMonthOffset = 2;
  static const tripShortfallCents = 80000;
  static const fridgeCents = 120000;
  static const fridgeInstallments = 10;
  static const courseCents = 120000;
  static const courseInstallments = 24;

  static const investmentMonths = 24;
  static const _monthlyBuys = [
    ('HGLG11', 2, 1),
    ('MXRF11', 30, 1),
    ('KNRI11', 1, 2),
    ('ITSA4', 20, 1),
    ('TAEE11', 8, 2),
    ('WEGE3', 5, 3),
  ];

  static void seedInvestments(DemoDatabase database) {
    final investments = database.investments;
    final firstMonth = Dates.firstOfMonth(database.today);
    Row trade(String ticker, String kind, int quantity, DateTime day) => {
      'ticker': ticker,
      'kind': kind,
      'traded_on': Dates.toIso(day),
      'quantity': quantity,
      'price_cents': investments.closeCentsOn(
        DemoInvestments.findAsset(ticker)!,
        day,
      ),
      'fees_cents': 0,
      if (ticker == 'TAEE11') 'goal': 'income',
    };
    for (var back = investmentMonths; back >= 1; back--) {
      final day = Dates.addMonths(
        firstMonth,
        -back,
      ).add(const Duration(days: 9));
      for (final (ticker, quantity, every) in _monthlyBuys) {
        if (back % every == 0) {
          investments.createTransaction(trade(ticker, 'buy', quantity, day));
        }
      }
      if (back == 4) {
        investments.createTransaction(trade('ITSA4', 'sell', 60, day));
      }
    }
  }

  static DemoDatabase build(DateTime today) {
    final database = DemoDatabase(today: today);
    final keys = <String, String>{};
    void addAll(String kind, Map<String, String> names, String? nature) {
      for (final MapEntry(:key, :value) in names.entries) {
        keys[key] = database.addCategory(
          kind: kind,
          key: key,
          name: value,
          defaultNature: nature,
        );
      }
    }

    addAll('income', income, null);
    addAll('expense', fixedExpenses, 'fixed');
    addAll('expense', variableExpenses, 'variable');

    final firstMonth = Dates.firstOfMonth(database.today);
    database.createBalance({
      'amount_cents': 350000,
      'as_of': Dates.toIso(firstMonth),
    });

    Row fields(String key, String description, int cents, DateTime dueOn) {
      final paid = !dueOn.isAfter(database.today);
      return {
        'category_id': keys[key],
        'description': description,
        'amount_cents': cents,
        'due_on': Dates.toIso(dueOn),
        'status': paid ? 'paid' : 'pending',
        'paid_on': paid ? Dates.toIso(dueOn) : null,
      };
    }

    for (final (key, description, cents, day) in _monthly) {
      database.createSeries({
        ...fields(
          key,
          description,
          cents,
          DateTime(firstMonth.year, firstMonth.month, day),
        ),
        'entries_count': months,
        'direction': 'forward',
      });
    }

    for (final (key, description, day, total, count) in [
      ('other_expense', 'Geladeira nova', 14, fridgeCents, fridgeInstallments),
      ('education', 'Curso de inglês', 18, courseCents, courseInstallments),
    ]) {
      database.createSeries({
        ...fields(
          key,
          description,
          1,
          DateTime(firstMonth.year, firstMonth.month, day),
        ),
        'kind': 'installments',
        'total_cents': total,
        'entries_count': count,
      });
    }

    void add(String key, String description, int cents, DateTime dueOn) =>
        database.createEntry(fields(key, description, cents, dueOn));

    for (var offset = 0; offset < months; offset++) {
      final month = Dates.addMonths(firstMonth, offset);
      if (month.month == 12) {
        add(
          'thirteenth_salary',
          '13º salário',
          520000,
          DateTime(month.year, 12, 18),
        );
      }
    }

    final tripMonth = Dates.addMonths(firstMonth, tripMonthOffset);
    final projected = database.projection(from: tripMonth, months: 1).single;
    final beforeTrip = projected['closing_cents']! as int;
    add(
      'travel',
      'Viagem de férias',
      beforeTrip + tripShortfallCents,
      DateTime(tripMonth.year, tripMonth.month, 22),
    );
    seedInvestments(database);
    return database;
  }
}
