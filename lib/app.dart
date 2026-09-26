import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/db/providers.dart';
import 'core/notify/notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/async_state_views.dart';
import 'features/backup/backup_providers.dart';
import 'features/budgets/budget_nudge_provider.dart';
import 'features/expenses/quick_add_screen.dart';
import 'features/expenses/recurring_repository.dart';
import 'features/expenses/recurring_schedule.dart';
import 'features/home/app_shell.dart';
import 'features/ledger/account_balance_provider.dart'
    show balanceHiddenProvider;
import 'features/ledger/income_screen.dart' show showIncomeConfirmSheet;
import 'features/ledger/ledger_repository.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/profile/profile_provider.dart';
import 'features/recap/recap_providers.dart';
import 'features/security/app_lock_provider.dart';
import 'features/security/lock_screen.dart';
import 'features/settings/theme_mode_provider.dart';
import 'features/widgets/widget_refresh.dart';
import 'features/widgets/widget_snapshot.dart' show widgetAppGroupId;

class SpendlyApp extends ConsumerStatefulWidget {
  const SpendlyApp({super.key});

  @override
  ConsumerState<SpendlyApp> createState() => _SpendlyAppState();
}

/// On cold start and every resume, runs the auto-backup due-check (FR-37, see
/// `local_auto_backup.dart`) and refreshes the widget snapshot (FR-29 — the
/// catch-all for changes that don't route through Quick Add, e.g. a restore).
/// Also routes widget quick-add taps into Quick Add (FR-3).
class _SpendlyAppState extends ConsumerState<SpendlyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Must be set before any other HomeWidget call (iOS throws otherwise).
    HomeWidget.setAppGroupId(widgetAppGroupId).then((_) {
      // A widget tap can cold-launch the app; handle both that and taps
      // while running.
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    });
    HomeWidget.widgetClicked.listen(_handleWidgetUri);
    // The notification "Add" action for recurring income routes back into
    // the app through this callback — see NotificationService's own doc
    // comment for why it's a plain callback rather than a Riverpod dependency.
    ref.read(notificationServiceProvider).onIncomeConfirmAction =
        _handleIncomeConfirmAction;
    ref.read(widgetRefreshHookProvider); // arms the on-write refresh hook once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(refreshWidgetsActionProvider)();
      _initNotifications();
      // Cold-start only, not on resume — see AppDatabase.pruneOrphanedReceipts
      // for why a resume during the undo-delete window must never run this.
      ref.read(databaseProvider).pruneOrphanedReceipts();
    });
  }

  /// Deferred off `main()`'s cold-start path (Sprint 7 perf fix) — see
  /// main.dart. Un-awaited: nothing in the first frame depends on this
  /// completing.
  Future<void> _initNotifications() async {
    final notifications = ref.read(notificationServiceProvider);
    await notifications.init();
    await notifications.scheduleMonthlyReport();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(autoBackupCheckProvider);
      ref.invalidate(monthlyRecapCheckProvider);
      ref.invalidate(budgetNudgeCheckProvider);
      ref.invalidate(recurringReminderCheckProvider);
      ref.invalidate(incomeRecurringReminderCheckProvider);
      ref.read(refreshWidgetsActionProvider)();
    } else {
      // Leaving the foreground (including the app switcher's snapshot)
      // re-masks the Home balance, so it's never left revealed in public.
      ref.read(balanceHiddenProvider.notifier).hide();
    }
  }

  /// Widget quick-add deep link: `spendly://quickadd?category=<id>` opens
  /// Quick Add with that category preselected.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.host != 'quickadd') return;
    final id = int.tryParse(uri.queryParameters['category'] ?? '');
    final context = appNavigatorKey.currentContext;
    if (context != null) openQuickAddScreen(context, initialCategoryId: id);
  }

  /// The recurring-income notification's "Add" action: looks the template
  /// up fresh (nothing else could have changed it between the notification
  /// firing and being tapped) and opens the reviewable confirm sheet for
  /// its oldest still-pending occurrence. A silent no-op if the template
  /// was deleted, un-recurred, or already fully confirmed/skipped since —
  /// there's nothing left to confirm.
  Future<void> _handleIncomeConfirmAction(int templateId) async {
    final template = await ref.read(ledgerRepositoryProvider).byId(templateId);
    if (template == null) return;
    final pending = pendingOccurrences(
      nextDueDate: template.nextDueDate,
      recurrence: template.recurrence,
      endDate: template.recurrenceEndDate,
      anchorDay: template.date.day,
      now: DateTime.now(),
    );
    if (pending.isEmpty) return;
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    showIncomeConfirmSheet(context, template: template, occurrence: pending.first);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoBackupCheckProvider); // fires the cold-start check
    ref.watch(
      monthlyRecapCheckProvider,
    ); // fires the once-per-month recap check
    ref.watch(
      budgetNudgeCheckProvider,
    ); // fires the once-per-month budget nudge check
    // Re-arms recurring due-date reminders; no background job exists, so the
    // schedule is rebuilt while the app is open.
    ref.watch(recurringReminderCheckProvider);
    ref.watch(incomeRecurringReminderCheckProvider);
    // Falls back to system while the persisted value loads.
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final profileAsync = ref.watch(profileProvider);
    // Falls back to "not locked" while the persisted value loads, same as
    // every other settings-backed toggle in this app — a locked-by-default
    // flash on every cold start would be worse than the one-frame gap this
    // avoids being theoretically lockable.
    final lockEnabled = ref.watch(appLockEnabledProvider).value ?? false;
    final unlocked = ref.watch(appUnlockedProvider);

    return MaterialApp(
      title: 'Spendly',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Crossfades light/dark colors on a theme switch — the prototype's one
      // intentional motion rule (`body { transition: background .4s ease,
      // color .4s ease }`). No other animation was designed, so this is the
      // only motion this sprint adds (Sprint 7).
      builder: (context, child) => AnimatedTheme(
        data: Theme.of(context),
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
        child: child!,
      ),
      home: (lockEnabled && !unlocked)
          ? const AppLockScreen()
          : profileAsync.when(
              loading: () => const Scaffold(body: LoadingView()),
              error: (e, _) => Scaffold(
                body: ErrorView(
                  message: "Couldn't load your profile.",
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),
              data: (profile) => profile.name.isEmpty
                  ? const WelcomeScreen()
                  : const AppShell(),
            ),
    );
  }
}
