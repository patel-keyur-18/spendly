import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/row_extensions.dart';
import '../../core/money/money.dart';
import '../accounts/account_repository.dart';
import 'balance_math.dart';
import 'ledger_repository.dart';

/// Comfortably before any possible transaction (same convention as
/// `all_transactions_screen.dart`'s search range) through tomorrow, so
/// every income/expense/transfer ever recorded counts — a running balance
/// carries forward forever, it never resets on the 1st of the month.
(DateTime, DateTime) _allTimeRange() {
  final now = DateTime.now();
  return (
    DateTime(2000),
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
  );
}

/// Every account's running balance (`balance_math.dart`): opening balance
/// plus every income/expense/transfer ever recorded against it. Computed
/// from four independently-reactive maps, never stored — each term updates
/// its own provider as its underlying data changes, and this just
/// recombines them.
final accountBalancesProvider = Provider<Map<int, Money>>((ref) {
  final range = _allTimeRange();
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final expense = ref.watch(accountTotalsByRangeProvider(range)).value ?? const {};
  final income =
      ref.watch(incomeTotalsByAccountRangeProvider(range)).value ?? const {};
  final transfersIn =
      ref.watch(transfersInTotalsByAccountRangeProvider(range)).value ??
      const {};
  final transfersOut =
      ref.watch(transfersOutTotalsByAccountRangeProvider(range)).value ??
      const {};
  return {
    for (final a in accounts)
      a.id: computeAccountBalance(
        openingBalance: a.openingBalance,
        income: income[a.id] ?? Money.zero,
        expense: expense[a.id] ?? Money.zero,
        transfersIn: transfersIn[a.id] ?? Money.zero,
        transfersOut: transfersOut[a.id] ?? Money.zero,
      ),
  };
});

/// Sum of every active, opted-in account's balance — the dashboard summary
/// figure. Archived accounts are excluded, same convention as every other
/// account-total shown in the app: they're hidden from every picker, so
/// folding their balance into a headline total would count money the user
/// can no longer act on through the UI. [AccountRow.includeInNetWorth] lets
/// the user exclude a specific account too (a car loan, a credit card's
/// running debt) — this is the only provider that flag affects; every
/// per-account balance (including that account's own detail screen) is
/// computed exactly the same either way.
final totalBalanceProvider = Provider<Money>((ref) {
  final active = ref.watch(activeAccountsProvider).value ?? const [];
  final counted = active.where((a) => a.includeInNetWorth);
  final balances = ref.watch(accountBalancesProvider);
  return counted.fold(
    Money.zero,
    (sum, a) => sum + (balances[a.id] ?? Money.zero),
  );
});

/// Whether the Home "Balance across accounts" figure is masked, so opening
/// the app in public never shows it. In-memory only (same as
/// `appUnlockedProvider`): every cold start begins hidden, and `app.dart`
/// re-hides it whenever the app leaves the foreground.
class BalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;

  void hide() => state = true;
}

final balanceHiddenProvider = NotifierProvider<BalanceHiddenNotifier, bool>(
  BalanceHiddenNotifier.new,
);
