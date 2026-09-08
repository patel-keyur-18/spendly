import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'macos_nav.dart';
import 'macos_tab.dart';
import 'screens/macos_accounts_screen.dart';
import 'screens/macos_budgets_screen.dart';
import 'screens/macos_categories_screen.dart';
import 'screens/macos_dashboard_screen.dart';
import 'screens/macos_goals_screen.dart';
import 'screens/macos_insights_screen.dart';
import 'screens/macos_settings_screen.dart';
import 'screens/macos_sync_screen.dart';
import 'screens/macos_transactions_screen.dart';
import 'screens/macos_trips_screen.dart';
import 'widgets/macos_menu_bar.dart';

/// Root navigation shell for the macOS build: a fixed sidebar (mirrors the
/// mobile bottom nav's role, sized for a desktop window instead of a
/// thumb-reach bar) plus a content pane that swaps between [MacosTab]s.
///
/// Every destination here is read-only except [MacosTab.sync], which is the
/// only screen in the whole macOS build allowed to write to the local
/// database (via a backup import) — see `macos_sync_screen.dart`.
class MacosShell extends StatefulWidget {
  const MacosShell({super.key});

  @override
  State<MacosShell> createState() => _MacosShellState();
}

class _MacosShellState extends State<MacosShell> {
  MacosTab _current = MacosTab.dashboard;

  // Same lazy-build-on-first-visit idea as the mobile AppShell — screens with
  // Drift stream subscriptions shouldn't build until the user actually opens
  // that tab.
  final Set<MacosTab> _visited = {MacosTab.dashboard};

  void _select(MacosTab tab) {
    if (tab == _current) return;
    setState(() {
      _current = tab;
      _visited.add(tab);
    });
  }

  Widget _screenFor(MacosTab tab) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    return switch (tab) {
      MacosTab.dashboard => const MacosDashboardScreen(),
      MacosTab.transactions => const MacosTransactionsScreen(),
      MacosTab.budgets => const MacosBudgetsScreen(),
      MacosTab.goals => const MacosGoalsScreen(),
      MacosTab.categories => const MacosCategoriesScreen(),
      MacosTab.trips => const MacosTripsScreen(),
      MacosTab.accounts => const MacosAccountsScreen(),
      MacosTab.sync => const MacosSyncScreen(),
      MacosTab.insights => const MacosInsightsScreen(),
      MacosTab.settings => const MacosSettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MacosMenuBar(
      onSelectTab: _select,
      child: MacosNav(
        goTo: _select,
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(current: _current, onSelect: _select),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(tab: _current),
                    Expanded(
                      child: IndexedStack(
                        index: _current.index,
                        children: [
                          for (final tab in MacosTab.values) _screenFor(tab),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onSelect});
  final MacosTab current;
  final ValueChanged<MacosTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Container(
      width: 236,
      color: palette.navBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: _Brand(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final tab in MacosTab.values) ...[
                    if (tab == MacosTab.sync)
                      Divider(
                        height: 24,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    _NavItem(
                      tab: tab,
                      selected: tab == current,
                      onTap: () => onSelect(tab),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: _ProfileFooter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          // Matches mobile's Home app-bar mark exactly (₹, not a letter) —
          // see `features/home/home_screen.dart`'s AppBar title.
          child: const FittedBox(
            child: Text('₹', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spendly',
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              'READ-ONLY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
                color: Color(0x80FFFFFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final MacosTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  tab.icon,
                  size: 18,
                  color: selected ? Colors.white : palette.navIconInactive,
                ),
                const SizedBox(width: 11),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.tealDeep, AppColors.teal],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            '🖥',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This Mac',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Read-only mirror',
                style: TextStyle(fontSize: 10.5, color: Color(0x73FFFFFF)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tab});
  final MacosTab tab;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tab.label, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  tab.subtitle,
                  style: TextStyle(fontSize: 12, color: palette.textDim),
                ),
              ],
            ),
          ),
          const _ReadOnlyPill(),
        ],
      ),
    );
  }
}

class _ReadOnlyPill extends StatelessWidget {
  const _ReadOnlyPill();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: palette.card2,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_rounded, size: 13, color: palette.textDim),
          const SizedBox(width: 6),
          Text(
            'Read-only',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
