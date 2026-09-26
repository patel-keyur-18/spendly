import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/features/ledger/account_balance_provider.dart';

void main() {
  test('balance starts hidden, toggles, and hide() re-masks it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(balanceHiddenProvider.notifier);

    expect(container.read(balanceHiddenProvider), isTrue);
    notifier.toggle();
    expect(container.read(balanceHiddenProvider), isFalse);
    notifier.hide();
    expect(container.read(balanceHiddenProvider), isTrue);
  });
}
