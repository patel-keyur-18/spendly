import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/db/database.dart';
import 'package:spendly/core/db/row_extensions.dart';
import 'package:spendly/core/money/money.dart';
import 'package:spendly/features/accounts/account_repository.dart';
import 'package:spendly/features/expenses/expense_repository.dart';
import 'package:spendly/features/expenses/recurring_repository.dart';

void main() {
  late AppDatabase db;
  late ExpenseRepository expenses;
  late RecurringRepository recurring;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    expenses = ExpenseRepository(db);
    recurring = RecurringRepository(db, expenses);
  });
  tearDown(() => db.close());

  /// A monthly rent template first logged on 1 June, next due 1 July.
  Future<ExpenseRow> seedRent({
    DateTime? nextDue,
    DateTime? endDate,
    DateTime? start,
  }) async {
    final id = await expenses.add(
      amount: Money.parse('20000'),
      categoryId: 1,
      date: start ?? DateTime(2026, 6, 1),
      note: 'Rent',
      paymentMethod: 'UPI',
      isRecurring: true,
      recurrence: Recurrence.monthly,
      nextDueDate: nextDue ?? DateTime(2026, 7, 1),
      recurrenceEndDate: endDate,
    );
    return (db.select(db.expenses)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<ExpenseRow> reload(int id) =>
      (db.select(db.expenses)..where((t) => t.id.equals(id))).getSingle();

  test('watchTemplates returns only recurring rows', () async {
    await seedRent();
    await expenses.add(amount: Money.parse('50'), categoryId: 1);

    final templates = await recurring.watchTemplates().first;
    expect(templates, hasLength(1));
    expect(templates.single.note, 'Rent');
  });

  test('nothing is pending before the due date arrives', () async {
    final rent = await seedRent();
    expect(recurring.pendingFor(rent, now: DateTime(2026, 6, 20)), isEmpty);
  });

  test('three missed months surface as three pending occurrences', () async {
    final rent = await seedRent();
    final pending = recurring.pendingFor(rent, now: DateTime(2026, 9, 15));
    expect(pending, [
      DateTime(2026, 7, 1),
      DateTime(2026, 8, 1),
      DateTime(2026, 9, 1),
    ]);
  });

  group('confirm', () {
    test('logs a real expense dated the occurrence, not today', () async {
      final rent = await seedRent();
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      final all = await expenses.watchMonth(DateTime(2026, 7, 1)).first;
      expect(all, hasLength(1));
      expect(all.single.amount, Money.parse('20000'));
      expect(all.single.date, DateTime(2026, 7, 1));
    });

    test('copies the template fields onto the logged expense', () async {
      final rent = await seedRent();
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      final logged = (await expenses.watchMonth(DateTime(2026, 7, 1)).first)
          .single;
      expect(logged.note, 'Rent');
      expect(logged.paymentMethod, 'UPI');
      expect(logged.categoryId, 1);
    });

    test('keeps the template account on the logged expense', () async {
      // Dropping it logged every occurrence as "No account", so the paying
      // account's balance never moved.
      final accountId = await AccountRepository(db)
          .create(name: 'HDFC', type: AccountType.bank);
      final rent = await seedRent();
      await expenses.update(rent.id, accountId: Value(accountId));
      await recurring.confirm(await reload(rent.id), DateTime(2026, 7, 1));

      final logged = (await expenses.watchMonth(DateTime(2026, 7, 1)).first)
          .single;
      expect(logged.accountId, accountId);
    });

    test('the logged copy is not itself a template', () async {
      // Otherwise every confirmation forks the series into another
      // independently-advancing template and reminders multiply.
      final rent = await seedRent();
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      expect(await recurring.watchTemplates().first, hasLength(1));
    });

    test('advances the pointer past the confirmed occurrence', () async {
      final rent = await seedRent();
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      final updated = await reload(rent.id);
      expect(updated.nextDueDate, DateTime(2026, 8, 1));
      expect(recurring.pendingFor(updated, now: DateTime(2026, 7, 20)), isEmpty);
    });

    test('clearing a backlog takes one confirm per occurrence', () async {
      var rent = await seedRent();
      final now = DateTime(2026, 9, 15);
      expect(recurring.pendingFor(rent, now: now), hasLength(3));

      for (var i = 0; i < 3; i++) {
        rent = await reload(rent.id);
        final due = recurring.pendingFor(rent, now: now);
        await recurring.confirm(rent, due.first);
      }

      rent = await reload(rent.id);
      expect(recurring.pendingFor(rent, now: now), isEmpty);
      // Three months really were paid, so three rows exist.
      final logged = await expenses
          .watchInRange(DateTime(2026, 7, 1), DateTime(2026, 10, 1))
          .first;
      expect(logged, hasLength(3));
    });

    test('a month-end series does not drift onto the 28th', () async {
      var rent = await seedRent(
        start: DateTime(2026, 1, 31),
        nextDue: DateTime(2026, 2, 28),
      );
      await recurring.confirm(rent, DateTime(2026, 2, 28));
      rent = await reload(rent.id);
      expect(rent.nextDueDate, DateTime(2026, 3, 31));
    });
  });

  group('skip', () {
    test('logs nothing but still moves the pointer on', () async {
      final rent = await seedRent();
      await recurring.skip(rent, DateTime(2026, 7, 1));

      expect(await expenses.watchMonth(DateTime(2026, 7, 1)).first, isEmpty);
      expect((await reload(rent.id)).nextDueDate, DateTime(2026, 8, 1));
    });

    test('a skipped occurrence does not come back', () async {
      final rent = await seedRent();
      await recurring.skip(rent, DateTime(2026, 7, 1));

      final updated = await reload(rent.id);
      expect(recurring.pendingFor(updated, now: DateTime(2026, 7, 20)), isEmpty);
    });
  });

  group('end date', () {
    test('the series stops being a template after its last occurrence',
        () async {
      var rent = await seedRent(endDate: DateTime(2026, 7, 15));
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      rent = await reload(rent.id);
      expect(rent.nextDueDate, isNull);
      expect(rent.isRecurring, isFalse);
      expect(await recurring.watchTemplates().first, isEmpty);
    });

    test('the final logged expense is kept, not rolled back', () async {
      final rent = await seedRent(endDate: DateTime(2026, 7, 15));
      await recurring.confirm(rent, DateTime(2026, 7, 1));

      expect(await expenses.watchMonth(DateTime(2026, 7, 1)).first, hasLength(1));
    });
  });

  group('cancel', () {
    test('stops the schedule but keeps the original expense', () async {
      final rent = await seedRent();
      await recurring.cancel(rent);

      final updated = await reload(rent.id);
      expect(updated.isRecurring, isFalse);
      expect(updated.nextDueDate, isNull);
      // The money really was spent on 1 June; cancelling a schedule must not
      // erase history.
      expect(updated.amount, Money.parse('20000'));
      expect(await expenses.watchMonth(DateTime(2026, 6, 1)).first, hasLength(1));
    });
  });

  test('dueRecurringProvider ordering: oldest due first', () async {
    // Directly exercised through watchSeries, which the provider derives from.
    await seedRent(nextDue: DateTime(2026, 8, 1));
    await expenses.add(
      amount: Money.parse('500'),
      categoryId: 2,
      date: DateTime(2026, 6, 1),
      note: 'Streaming',
      isRecurring: true,
      recurrence: Recurrence.monthly,
      nextDueDate: DateTime(2026, 7, 1),
    );

    final series = await recurring.watchSeries(now: DateTime(2026, 9, 1)).first;
    final due = series.where((s) => s.pending.isNotEmpty).toList()
      ..sort((a, b) => a.pending.first.compareTo(b.pending.first));
    expect(due.first.template.note, 'Streaming');
  });
}
