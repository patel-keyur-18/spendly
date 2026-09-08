import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/backup/backup_format.dart';
import '../../../features/backup/backup_import.dart';
import '../../../features/backup/backup_providers.dart';
import '../../../features/backup/backup_restore_screen.dart' show PrimaryButton;

/// The one screen in the macOS build allowed to write to the local database
/// — everything else is read-only. Reuses the exact same decrypt/preview/
/// merge pipeline the mobile Restore screen uses
/// (`features/backup/backup_import.dart`), unmodified: pick a `.spendly`/
/// `.json` backup file (received via AirDrop, or any other way the user got
/// it onto this Mac), preview it, choose Merge or Replace, import.
///
/// "Last synced" is tracked with its own settings key (`macos_last_sync_at`)
/// — deliberately not `SettingsRepository.lastBackupAtKey`, which already
/// means "this device last *exported* a backup," a different fact.
class MacosSyncScreen extends ConsumerStatefulWidget {
  const MacosSyncScreen({super.key});

  @override
  ConsumerState<MacosSyncScreen> createState() => _MacosSyncScreenState();
}

const _lastSyncKey = 'macos_last_sync_at';

class _MacosSyncScreenState extends ConsumerState<MacosSyncScreen> {
  BackupPreview? _preview;
  bool _busy = false;
  String? _error;
  String? _result;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 30,
                      color: AppColors.primarySoft,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _preview == null
                          ? 'Choose a backup file'
                          : _preview!.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _busy
                          ? 'Reading…'
                          : 'AirDropped from your iPhone, or anywhere else on this Mac',
                      style: TextStyle(fontSize: 11.5, color: palette.textDim),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickFile,
                      icon: const Icon(Icons.file_open_rounded, size: 16),
                      label: const Text('Choose file…'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    const _Step(1, 'On iPhone: Profile → Backup → Share → AirDrop to your Mac'),
                    const _Step(2, 'Accept the AirDrop on this Mac'),
                    const _Step(3, 'Preview it here, then sync — this replaces the copy on your Mac'),
                    const SizedBox(height: AppSpacing.lg),
                    _LastSyncedLine(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            color: AppColors.red.withValues(alpha: 0.08),
            child: Text(_error!, style: const TextStyle(color: AppColors.red)),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            color: AppColors.green.withValues(alpha: 0.08),
            child: Text(_result!, style: const TextStyle(color: AppColors.green)),
          ),
        ],
        if (_preview != null) ...[
          const SectionTitle('File preview'),
          AppCard(
            child: Column(
              children: [
                _PreviewRow('Backup date', DateFormat.yMMMd().add_jm().format(_preview!.exportedAt)),
                _PreviewRow('Expenses', '${_preview!.expenseCount} transactions'),
                _PreviewRow('Categories', '${_preview!.categoryCount}'),
                _PreviewRow('File size', _formatSize(_preview!.fileSizeBytes)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: palette.textDim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "This replaces this Mac's copy entirely with the backup file.",
                  style: TextStyle(fontSize: 11.5, color: palette.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _busy ? 'Syncing…' : 'Sync now',
            onTap: _busy ? null : _sync,
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _result = null;
      _preview = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'spendly'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await _loadFile(path);
  }

  Future<void> _loadFile(String path, {String? password}) async {
    setState(() => _busy = true);
    try {
      final preview = await loadAndValidate(path, password: password);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _error = null;
      });
    } on BackupPasswordRequiredException {
      if (!mounted) return;
      final entered = await _askPassword(wrongPassword: password != null);
      if (entered == null || !mounted) return;
      await _loadFile(path, password: entered);
      return;
    } on BackupWrongPasswordException {
      if (!mounted) return;
      final entered = await _askPassword(wrongPassword: true);
      if (entered == null || !mounted) return;
      await _loadFile(path, password: entered);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassword({required bool wrongPassword}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.boldDialogActions(dialogContext),
        child: AlertDialog(
          title: const Text('Password required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wrongPassword)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Incorrect password — try again.',
                    style: TextStyle(color: AppColors.red, fontSize: 12),
                  ),
                ),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sync() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final repo = ref.read(backupRepositoryProvider);
      await executeRestore(preview.payload, RestoreMode.replace, repo);
      await ref
          .read(settingsRepositoryProvider)
          .set(_lastSyncKey, DateTime.now().toIso8601String());
      ref.invalidate(_lastSyncedProvider);
      if (!mounted) return;
      setState(() {
        _result =
            'Replaced — ${preview.expenseCount} transactions synced from ${preview.fileName}.';
        _preview = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

final _lastSyncedProvider = FutureProvider<DateTime?>((ref) async {
  final raw = await ref.watch(settingsRepositoryProvider).get(_lastSyncKey);
  return raw == null ? null : DateTime.tryParse(raw);
});

class _LastSyncedLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final lastSynced = ref.watch(_lastSyncedProvider).value;
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 14, color: palette.textDim),
        const SizedBox(width: 6),
        Text(
          lastSynced == null
              ? 'Never synced on this Mac'
              : 'Last synced ${DateFormat.yMMMd().add_jm().format(lastSynced)}',
          style: TextStyle(fontSize: 11.5, color: palette.textDim),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.line),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: palette.textDim, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: palette.textDim)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
