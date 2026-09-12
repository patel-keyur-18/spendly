import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../features/accounts/account_repository.dart';
import '../../../features/accounts/accounts_screen.dart' show accountTypeLabel;
import '../../../features/ledger/account_balance_provider.dart';

/// Wallet stack — accounts as physical-card tiles, grouped by account type
/// (mirrors mobile's own `AccountType` taxonomy), each group a `Wrap` so a
/// stack that doesn't fit the window width continues on the next row rather
/// than overflowing or scrolling sideways — reuses `accountBalancesProvider`/
/// `totalBalanceProvider` verbatim, the same computed-not-stored balance
/// math the mobile Accounts screen and dashboard both already depend on.
class MacosAccountsScreen extends ConsumerWidget {
  const MacosAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider);
    final total = ref.watch(totalBalanceProvider);
    final palette = Theme.of(context).extension<AppPalette>()!;

    if (accounts.isEmpty) {
      return Center(
        child: Text('No accounts yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
      );
    }

    final groups = <AccountType, List<AccountRow>>{};
    for (final a in accounts) {
      groups.putIfAbsent(a.type, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(AppRadius.hero)),
          alignment: Alignment.center,
          child: Column(
            children: [
              const Text('NET WORTH ACROSS ACCOUNTS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              Text(total.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        for (final type in AccountType.values)
          if (groups[type] case final members? when members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            _GroupHeader(
              label: _groupLabel(type),
              subtotal: members.fold(Money.zero, (s, a) => s + (balances[a.id] ?? Money.zero)),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                for (final a in members) _WalletCard(account: a, balance: balances[a.id]),
              ],
            ),
          ],
      ],
    );
  }

  String _groupLabel(AccountType t) => switch (t) {
        AccountType.cash => 'Cash',
        AccountType.bank => 'Bank accounts',
        AccountType.card => 'Cards',
        AccountType.wallet => 'Wallets',
        AccountType.custom => 'Custom',
      };
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.subtotal});
  final String label;
  final Money subtotal;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final negative = subtotal.minor < 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: palette.textDim)),
        Text(
          subtotal.format(locale: 'en_IN'),
          style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 13.5, color: negative ? AppColors.red : null),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.account, required this.balance});
  final AccountRow account;
  final Money? balance;

  @override
  Widget build(BuildContext context) {
    final negative = (balance?.minor ?? 0) < 0;
    final gradient = negative
        ? const LinearGradient(colors: [Color(0xFFB91C1C), AppColors.red], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : _gradientFor(account.type);

    return Container(
      width: 240,
      height: 130,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_iconFor(account.type), size: 20, color: Colors.white),
              Text(
                accountTypeLabel(account).toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
            ],
          ),
          const Spacer(),
          Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            balance?.format(locale: 'en_IN') ?? '—',
            style: const TextStyle(fontFamily: 'Sora', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19),
          ),
        ],
      ),
    );
  }

  LinearGradient _gradientFor(AccountType t) => switch (t) {
        AccountType.bank => const LinearGradient(colors: [AppColors.primaryDeep, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        AccountType.cash => const LinearGradient(colors: [AppColors.tealDeep, AppColors.teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        AccountType.card => const LinearGradient(colors: [AppColors.primary, AppColors.primarySoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
        AccountType.wallet => const LinearGradient(colors: [AppColors.amberDeep, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        AccountType.custom => const LinearGradient(colors: [AppColors.primaryDeep, AppColors.pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
      };

  IconData _iconFor(AccountType t) => switch (t) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.card => Icons.credit_card_outlined,
        AccountType.wallet => Icons.account_balance_wallet_outlined,
        AccountType.custom => Icons.category_outlined,
      };
}
