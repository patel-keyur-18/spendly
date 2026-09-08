import 'package:flutter/material.dart';

/// The ten destinations from the approved desktop prototype, sidebar order.
enum MacosTab {
  dashboard('Dashboard', Icons.home_rounded, 'Good evening'),
  transactions('Transactions', Icons.receipt_long_rounded, 'Every entry — view only'),
  insights('Insights', Icons.bar_chart_rounded, 'Deeper cuts of your spending'),
  budgets('Budgets', Icons.flag_rounded, 'Per-category limits and how close you are'),
  goals('Goals', Icons.track_changes_rounded, 'Savings targets you are tracking toward'),
  categories('Categories', Icons.sell_rounded, '18 defaults, as set on your iPhone'),
  trips('Tags & Trips', Icons.location_on_rounded, 'Group spend outside the category system'),
  accounts('Accounts', Icons.account_balance_rounded, 'Balances across cash, cards and wallets'),
  sync('Sync from iPhone', Icons.sync_rounded, 'Pull a read-only copy over — no cloud, nothing sent back'),
  settings('Settings', Icons.settings_rounded, 'Appearance, security and how this Mac displays your data');

  const MacosTab(this.label, this.icon, this.subtitle);
  final String label;
  final IconData icon;
  final String subtitle;
}
