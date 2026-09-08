import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../macos_tab.dart';

/// Native macOS menu bar (replaces the Flutter-template's `MainMenu.xib`
/// defaults). Kept deliberately small — an App menu (About, Quit) plus a
/// View menu jumping straight to Sync and Settings, since every other
/// destination is already one click away in the sidebar.
class MacosMenuBar extends StatelessWidget {
  const MacosMenuBar({super.key, required this.onSelectTab, required this.child});

  final ValueChanged<MacosTab> onSelectTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Spendly',
          menus: [
            PlatformMenuItem(
              label: 'About Spendly',
              onSelected: () => showAboutDialog(
                context: context,
                applicationName: 'Spendly',
                applicationVersion: 'Read-only mirror',
              ),
            ),
            const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Sync from iPhone',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () => onSelectTab(MacosTab.sync),
            ),
            PlatformMenuItem(
              label: 'Settings',
              shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: () => onSelectTab(MacosTab.settings),
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
