import 'package:flutter/material.dart';

import 'macos_tab.dart';

/// Lets any screen jump the sidebar to a different tab (e.g. "View all"
/// linking from Dashboard's recent list to the Transactions tab) without
/// threading a callback through every constructor. [MacosShell] is the sole
/// provider — it wraps its content pane with this, backed by the same
/// `_select` method the sidebar itself calls.
class MacosNav extends InheritedWidget {
  const MacosNav({super.key, required this.goTo, required super.child});

  final void Function(MacosTab tab) goTo;

  static MacosNav of(BuildContext context) {
    final nav = context.dependOnInheritedWidgetOfExactType<MacosNav>();
    assert(nav != null, 'MacosNav.of() called outside MacosShell');
    return nav!;
  }

  @override
  bool updateShouldNotify(MacosNav oldWidget) => goTo != oldWidget.goTo;
}
