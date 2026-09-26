import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/db/row_extensions.dart';
import '../../core/notify/notifications.dart';
import '../home/dashboard_providers.dart';
import 'expense_repository.dart';
import 'recurring_schedule.dart';

/// One recurring template together with the occurrences currently waiting on
/// the user. [pending] is empty for a template whose next date is still ahead.
typedef RecurringSeries = ({ExpenseRow template, List<DateTime> pending});

/// Reads and advances recurring expense series (FR-7).
///
/// The locked product decision is remind-and-confirm: nothing here ever logs
/// an expense on its own. [confirm] runs only from a user action, and [skip]
/// exists so declining an occurrence is a real, recorded choice rather than
/// an ignored reminder that keeps nagging.
class RecurringRepository {
  RecurringRepository(this._db, this._expenses);

  final AppDatabase _db;
  final ExpenseRepository _expenses;

  /// Every expense flagged recurring, newest first — templates, whether or not
  /// anything is due. Feeds the manage list.
  Stream<List<ExpenseRow>> watchTemplates() {
    return (_db.select(_db.expenses)
          ..where((t) => t.isRecurring.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Templates paired with their pending occurrences, as of [now].
  Stream<List<RecurringSeries>> watchSeries({DateTime? now}) {
    return watchTemplates().map((templates) {
      final at = now ?? DateTime.now();
      return [
        for (final template in templates)
          (template: template, pending: pendingFor(template, now: at)),
      ];
    });
  }

  /// Occurrences of [template] due on or before [now] and not yet resolved.
  List<DateTime> pendingFor(ExpenseRow template, {DateTime? now}) =>
      pendingOccurrences(
        nextDueDate: template.nextDueDate,
        recurrence: template.recurrence,
        endDate: template.recurrenceEndDate,
        // The template's own date is what the series is pinned to, so a
        // month-end series doesn't drift off the 31st.
        anchorDay: template.date.day,
        now: now ?? DateTime.now(),
      );

  /// Logs [occurrence] as a real expense copied from [template], and moves the
  /// template's pointer past it.
  ///
  /// The new row is deliberately NOT itself recurring: exactly one row in a
  /// series carries the schedule, so confirming an occurrence can never fork
  /// the series into two independently-advancing templates.
  Future<void> confirm(ExpenseRow template, DateTime occurrence) async {
    await _db.transaction(() async {
      await _expenses.add(
        amount: template.amount,
        categoryId: template.categoryId,
        date: occurrence,
        note: template.note,
        paymentMethod: template.paymentMethod,
        tagId: template.tagId,
        accountId: template.accountId,
        fxCurrency: template.fxCurrency,
        fxAmount: template.fxAmount,
      );
      await _advancePast(template, occurrence);
    });
  }

  /// Declines [occurrence] — nothing is logged, the pointer still moves on.
  Future<void> skip(ExpenseRow template, DateTime occurrence) =>
      _advancePast(template, occurrence);

  /// Stops the series. The template stays an ordinary expense: the money was
  /// really spent when it was first logged, so cancelling a schedule must not
  /// delete history.
  Future<void> cancel(ExpenseRow template) => _expenses.update(
    template.id,
    isRecurring: false,
    nextDueDate: const Value(null),
  );

  /// Moves the pointer to the occurrence after [resolved], ending the series
  /// when that would pass its end date.
  Future<void> _advancePast(ExpenseRow template, DateTime resolved) {
    final next = nextDueAfter(
      resolved,
      template.recurrence,
      endDate: template.recurrenceEndDate,
      anchorDay: template.date.day,
    );
    return _expenses.update(
      template.id,
      // A finished series stops being a template, so it leaves the manage
      // list and stops being considered for reminders.
      isRecurring: next != null,
      nextDueDate: Value(next),
    );
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(
    ref.watch(databaseProvider),
    ref.watch(expenseRepositoryProvider),
  ),
);

/// Live recurring series with their pending occurrences — feeds the Home
/// "Due now" card and the manage screen.
final recurringSeriesProvider = StreamProvider<List<RecurringSeries>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchSeries(),
);

/// Re-arms every recurring due-date reminder, on cold start and on resume.
///
/// Invalidated from `app.dart`'s lifecycle hook exactly like
/// [autoBackupCheckProvider] and [monthlyRecapCheckProvider]: there is no
/// background execution in this project, so "the schedule stays current" means
/// rebuilding it whenever the app is open.
final recurringReminderCheckProvider = FutureProvider<void>((ref) async {
  // Watched, not read: adding, cancelling or confirming a series has to
  // re-arm the alarms, and a one-shot read here would leave a stale schedule
  // behind until the next resume.
  final series = ref.watch(recurringSeriesProvider).value;
  if (series == null) return;

  final categories = ref.watch(categoriesByIdProvider);
  final reminders = <({int id, String title, DateTime dueAt})>[];
  for (final s in series) {
    final due = s.template.nextDueDate;
    if (due == null) continue;
    reminders.add((
      id: s.template.id,
      title: s.template.note?.isNotEmpty == true
          ? s.template.note!
          : (categories[s.template.categoryId]?.name ?? 'A recurring expense'),
      dueAt: due,
    ));
  }
  await ref
      .read(notificationServiceProvider)
      .scheduleRecurringReminders(reminders);
});

/// Just the series with something waiting, oldest due first — what the Home
/// card shows and what "is anything due?" means everywhere.
final dueRecurringProvider = Provider<List<RecurringSeries>>((ref) {
  final series = ref.watch(recurringSeriesProvider).value ?? const [];
  final due = [
    for (final s in series)
      if (s.pending.isNotEmpty) s,
  ];
  due.sort((a, b) => a.pending.first.compareTo(b.pending.first));
  return due;
});
