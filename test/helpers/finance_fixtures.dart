import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockBalanceRepository extends Mock implements BalanceRepository;

class MockEntryRepository extends Mock implements EntryRepository;

final november = DateTime(2026, 11);

final balance = Balance(
  id: 'balance-1',
  amountCents: 123456,
  asOf: DateTime(2026, 11, 3),
);

const salaryCategory = Category(
  id: 'cat-salary',
  kind: EntryKind.income,
  key: 'salary',
  name: 'Salary',
);

const rentCategory = Category(
  id: 'cat-rent',
  kind: EntryKind.income,
  key: 'rent_received',
  name: 'Rent received',
);

final salary = Entry(
  id: 'entry-1',
  kind: EntryKind.income,
  categoryId: salaryCategory.id,
  description: 'Salário ACME',
  amountCents: 500000,
  dueOn: DateTime(2026, 11, 5),
  status: EntryStatus.paid,
  paidOn: DateTime(2026, 11, 5),
);

final rent = Entry(
  id: 'entry-2',
  kind: EntryKind.income,
  categoryId: rentCategory.id,
  description: 'Aluguel apto 12',
  amountCents: 150000,
  dueOn: DateTime(2026, 11, 10),
  status: EntryStatus.pending,
);

const housingCategory = Category(
  id: 'cat-housing',
  kind: EntryKind.expense,
  key: 'housing',
  name: 'Housing',
  defaultNature: EntryNature.fixed,
);

const groceriesCategory = Category(
  id: 'cat-groceries',
  kind: EntryKind.expense,
  key: 'groceries',
  name: 'Groceries',
  defaultNature: EntryNature.variable,
);

final housing = Entry(
  id: 'entry-3',
  kind: EntryKind.expense,
  categoryId: housingCategory.id,
  description: 'Aluguel de casa',
  amountCents: 200000,
  dueOn: DateTime(2026, 11, 10),
  status: EntryStatus.pending,
  nature: EntryNature.fixed,
);

final groceries = Entry(
  id: 'entry-4',
  kind: EntryKind.expense,
  categoryId: groceriesCategory.id,
  description: 'Mercado do mês',
  amountCents: 80000,
  dueOn: DateTime(2026, 11, 7),
  status: EntryStatus.paid,
  nature: EntryNature.variable,
  paidOn: DateTime(2026, 11, 7),
);

void registerFinanceFallbacks() {
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(EntryKind.income);
  registerFallbackValue(salary.toDraft());
  registerFallbackValue(salary);
  registerFallbackValue(balance);
}
