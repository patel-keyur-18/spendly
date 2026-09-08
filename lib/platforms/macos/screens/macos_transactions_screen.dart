import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/db/row_extensions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_glyph.dart';
import '../../../features/accounts/account_repository.dart';
import '../../../features/expenses/all_transactions_screen.dart' show groupExpensesByDay, transactionsQueryKey, visibleCategoryChips;
import '../../../features/expenses/expense_repository.dart';
import '../../../features/home/dashboard_providers.dart' show categoriesByIdProvider;
import '../../../features/expenses/widgets/expense_tile.dart' show DayGroupHeader;
import '../widgets/macos_expense_row.dart';

/// Master-detail transactions browser — read only, so unlike the mobile
/// `AllTransactionsScreen` there's no swipe-to-delete, tap-to-edit, or Quick
/// Add link; selecting a row just shows its detail in the right pane.
///
/// Queries the whole synced history at once (limit 1000) rather than the
/// mobile screen's lazy month-window pagination — a Sync import is a fixed
/// snapshot, not a live, ever-growing local ledger, so there's no cold-start
/// cost to page around.
class MacosTransactionsScreen extends ConsumerStatefulWidget {
  const MacosTransactionsScreen({super.key});

  @override
  ConsumerState<MacosTransactionsScreen> createState() => _MacosTransactionsScreenState();
}

class _MacosTransactionsScreenState extends ConsumerState<MacosTransactionsScreen> {
  late (DateTime, DateTime) _range = monthBounds(DateTime.now());
  Set<int> _selectedCategoryIds = {};
  bool _categoryChipsExpanded = false;
  int? _selectedExpenseId;
  String _search = '';

  String get _categoryKey => (_selectedCategoryIds.toList()..sort()).join(',');

  void _stepMonth(int delta) {
    final anchor = DateTime(_range.$1.year, _range.$1.month + delta, 1);
    setState(() {
      _range = monthBounds(anchor);
      _selectedCategoryIds = {};
      _categoryChipsExpanded = false;
      _selectedExpenseId = null;
    });
  }

  Future<void> _openCategoryFilterDialog(List<CategoryRow> categories) async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _CategoryFilterDialog(categories: categories, initialSelected: _selectedCategoryIds),
    );
    if (result != null) {
      setState(() {
        _selectedCategoryIds = result;
        _categoryChipsExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final atCurrentMonth = _range.$1.year == now.year && _range.$1.month == now.month;
    final key = transactionsQueryKey(
      searching: false,
      search: _search,
      range: _range,
      limit: 1000,
      categoryKey: _categoryKey,
      now: now,
    );
    final expenses = ref.watch(expensesInRangeProvider(key)).value ?? const [];
    final byId = ref.watch(categoriesByIdProvider);
    final accountsById = ref.watch(accountsByIdProvider);
    final categoryChips = ref.watch(categoriesInRangeProvider(_range)).value ?? const [];

    final selectedList = [
      for (final c in categoryChips)
        if (_selectedCategoryIds.contains(c.id)) c,
    ];
    final visibleChips = visibleCategoryChips(selectedList, _categoryChipsExpanded);
    final hiddenChipCount = selectedList.length - visibleChips.length;
    final palette = Theme.of(context).extension<AppPalette>()!;

    final selected = _selectedExpenseId == null
        ? null
        : expenses.cast<ExpenseRow?>().firstWhere((e) => e?.id == _selectedExpenseId, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    hintText: 'Search transactions…',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _stepMonth(-1),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  DateFormat('MMMM yyyy').format(_range.$1),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: atCurrentMonth ? null : () => _stepMonth(1),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Filter by category',
                icon: Badge(
                  label: Text('${_selectedCategoryIds.length}'),
                  isLabelVisible: _selectedCategoryIds.isNotEmpty,
                  child: const Icon(Icons.filter_list_rounded),
                ),
                onPressed: categoryChips.isEmpty ? null : () => _openCategoryFilterDialog(categoryChips),
              ),
            ],
          ),
          if (selectedList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in visibleChips)
                    InputChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryGlyph(c.icon, size: 16),
                          const SizedBox(width: AppSpacing.xs),
                          Text(c.name),
                        ],
                      ),
                      selected: true,
                      onSelected: (_) => setState(() => _selectedCategoryIds.remove(c.id)),
                      onDeleted: () => setState(() => _selectedCategoryIds.remove(c.id)),
                      selectedColor: AppColors.primary,
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      backgroundColor: palette.card,
                      shape: StadiumBorder(side: BorderSide(color: palette.line)),
                    ),
                  if (hiddenChipCount > 0)
                    ActionChip(
                      label: Text('+$hiddenChipCount more'),
                      onPressed: () => setState(() => _categoryChipsExpanded = true),
                      backgroundColor: palette.card,
                      shape: StadiumBorder(side: BorderSide(color: palette.line)),
                    ),
                  if (_categoryChipsExpanded && selectedList.length > 3)
                    ActionChip(
                      label: const Text('Show less'),
                      onPressed: () => setState(() => _categoryChipsExpanded = false),
                      backgroundColor: palette.card,
                      shape: StadiumBorder(side: BorderSide(color: palette.line)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: expenses.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions${_selectedCategoryIds.isNotEmpty || _search.isNotEmpty ? ' match this filter' : atCurrentMonth ? ' yet this month' : ' in this month'}.',
                            style: TextStyle(color: Theme.of(context).extension<AppPalette>()!.textDim),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final entry in groupExpensesByDay(expenses).entries) ...[
                              DayGroupHeader(
                                entry.key,
                                total: entry.value.fold(entry.value.first.amount * 0, (s, e) => s + e.amount),
                              ),
                              for (final e in entry.value)
                                MacosExpenseRow(
                                  expense: e,
                                  category: byId[e.categoryId],
                                  selected: e.id == _selectedExpenseId,
                                  onTap: () => setState(() => _selectedExpenseId = e.id),
                                ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 320,
                  child: selected == null
                      ? const _EmptyDetail()
                      : _DetailPane(expense: selected, category: byId[selected.categoryId], account: accountsById[selected.accountId]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select category filter — a centered dialog (desktop convention)
/// rather than mobile's bottom sheet (`_CategoryFilterSheet` in
/// `all_transactions_screen.dart`), but the same selection model: a
/// `Set<int>` staged locally and only committed to the screen's state on
/// "Apply", so cancelling leaves the current filter untouched.
class _CategoryFilterDialog extends StatefulWidget {
  const _CategoryFilterDialog({required this.categories, required this.initialSelected});

  final List<CategoryRow> categories;
  final Set<int> initialSelected;

  @override
  State<_CategoryFilterDialog> createState() => _CategoryFilterDialogState();
}

class _CategoryFilterDialogState extends State<_CategoryFilterDialog> {
  late final Set<int> _selected = {...widget.initialSelected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final filtered = widget.categories.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return AlertDialog(
      title: const Text('Filter by category'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                hintText: 'Search categories…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final c in filtered)
                    CheckboxListTile(
                      value: _selected.contains(c.id),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(c.id);
                        } else {
                          _selected.remove(c.id);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      secondary: CategoryGlyph(c.icon, size: 18),
                      title: Text(c.name),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No matching categories.', style: TextStyle(color: palette.textDim)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_selected.isNotEmpty)
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('Clear all'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AppCard(
      child: Center(
        child: Text('Select a transaction', style: TextStyle(color: palette.textDim, fontSize: 12.5)),
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.expense, required this.category, required this.account});
  final ExpenseRow expense;
  final CategoryRow? category;
  final AccountRow? account;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (category?.color ?? palette.textDim).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                alignment: Alignment.center,
                child: CategoryGlyph(category?.icon ?? '💸', size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.note?.isNotEmpty == true ? expense.note! : (category?.name ?? 'Expense'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    Text(category?.name ?? 'Uncategorized', style: TextStyle(fontSize: 11.5, color: palette.textDim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '-${expense.amount.format(locale: 'en_IN')}',
            style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 26),
          ),
          const Divider(height: 24),
          _DetailRow('Account', account?.name ?? '—'),
          _DetailRow('Date', DateFormat.yMMMd().add_jm().format(expense.date)),
          _DetailRow('Note', expense.note?.isNotEmpty == true ? expense.note! : '—'),
          _DetailRow('Payment method', expense.paymentMethod ?? '—'),
          if (expense.isForeign) _DetailRow('Paid abroad', expense.fxAmount!.formatAs(expense.fxCurrency!)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 13, color: palette.textDim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'To edit or delete, use Spendly on your iPhone',
                  style: TextStyle(fontSize: 11, color: palette.textDim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: palette.textDim)),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
