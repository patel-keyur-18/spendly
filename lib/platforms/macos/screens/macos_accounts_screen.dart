import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/accounts/account_repository.dart';
import '../../../features/accounts/accounts_screen.dart' show accountTypeLabel;
import '../../../features/ledger/account_balance_provider.dart';

/// Read-only account balances — reuses `accountBalancesProvider` and
/// `totalBalanceProvider` (`ledger/account_balance_provider.dart`) verbatim,
/// the same computed-not-stored balance math the mobile Accounts screen and
/// dashboard both already depend on.
class MacosAccountsScreen extends ConsumerWidget {
  const MacosAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider);
    final total = ref.watch(totalBalanceProvider);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net worth across accounts', style: TextStyle(fontSize: 12, color: palette.textDim)),
              Text(
                total.format(locale: 'en_IN'),
                style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('No accounts yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++)
                  _AccountRow(
                    account: accounts[i],
                    balance: balances[accounts[i].id],
                    showDivider: i > 0,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.balance, required this.showDivider});
  final AccountRow account;
  final Money? balance;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final negative = (balance?.minor ?? 0) < 0;
    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: palette.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.card2,
                  border: Border.all(color: palette.line),
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                alignment: Alignment.center,
                child: Icon(_iconFor(account), size: 18, color: palette.textDim),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(accountTypeLabel(account), style: TextStyle(fontSize: 11.5, color: palette.textDim)),
                  ],
                ),
              ),
              Text(
                balance?.format(locale: 'en_IN') ?? '—',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: negative ? AppColors.red : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(AccountRow a) => switch (a.type) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.card => Icons.credit_card_outlined,
        AccountType.wallet => Icons.account_balance_wallet_outlined,
        AccountType.custom => Icons.category_outlined,
      };
}
