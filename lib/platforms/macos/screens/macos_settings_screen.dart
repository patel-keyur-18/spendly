import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/security/app_lock_provider.dart';
import '../../../features/settings/theme_mode_provider.dart';

/// Appearance + security, reusing the exact same providers as mobile's
/// Profile screen (`features/profile/profile_screen.dart`) — `local_auth`
/// already ships a macOS implementation (Touch ID / device password via
/// `local_auth_darwin`, registered in `GeneratedPluginRegistrant.swift`), so
/// App Lock works here with zero new plugin wiring.
///
/// No data-entry of any kind lives here — Currency is a locked read-only
/// line (this app is INR-only by design, ADR-004), matching the same
/// disabled row on mobile's Profile screen.
class MacosSettingsScreen extends ConsumerWidget {
  const MacosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final lockEnabled = ref.watch(appLockEnabledProvider).value ?? false;
    final lockSupported = ref.watch(appLockSupportedProvider).value ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        const SectionTitle('Appearance'),
        AppCard(
          child: RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) ref.read(themeModeProvider.notifier).setMode(value);
            },
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(_themeLabel(mode)),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle('Security'),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_outline, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App lock', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    Text(
                      lockSupported
                          ? 'Require Touch ID or device password on launch'
                          : 'Set a device password or Touch ID to use this',
                      style: TextStyle(fontSize: 11, color: palette.textDim),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: lockEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: lockSupported
                    ? (value) => ref.read(appLockEnabledProvider.notifier).setEnabled(value)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle('Money'),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.currency_rupee_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Currency', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    Text('Indian Rupee (₹) — locked, matches your iPhone', style: TextStyle(fontSize: 11, color: palette.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle('About'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spendly for Mac', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Read-only mirror of your iPhone data. Pull a fresh copy anytime from the Sync tab — this Mac never writes back, and nothing here reaches the cloud.',
                style: TextStyle(fontSize: 11.5, color: palette.textDim, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeLabel(ThemeMode m) => switch (m) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
