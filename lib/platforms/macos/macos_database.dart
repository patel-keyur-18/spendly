import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/db/database.dart';

/// Builds the macOS build's own [AppDatabase] — a separate local mirror,
/// never the mobile app's file (different machine entirely; there is no
/// shared filesystem between an iPhone and a Mac). Populated only through
/// the Sync screen's backup import, never written to directly.
///
/// Deliberately not `getApplicationDocumentsDirectory()` (what
/// `AppDatabase._open()` uses for mobile) — that resolves to the user's real
/// `~/Documents` on an unsandboxed macOS build, which is the wrong place to
/// drop an app's sqlite file. `Application Support` is the macOS convention
/// for this, and passing a custom [LazyDatabase] through [AppDatabase]'s
/// existing `executor` parameter gets there without touching `database.dart`
/// at all.
AppDatabase openMacosDatabase() {
  return AppDatabase(
    LazyDatabase(() async {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'Spendly'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'spendly_mac.sqlite'));
      return NativeDatabase.createInBackground(file);
    }),
  );
}
