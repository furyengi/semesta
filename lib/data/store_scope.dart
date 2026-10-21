import 'package:flutter/widgets.dart';

import 'library_store.dart';

/// Exposes the [LibraryStore] to the tree and rebuilds dependents on change.
class StoreScope extends InheritedNotifier<LibraryStore> {
  const StoreScope({
    super.key,
    required LibraryStore store,
    required super.child,
  }) : super(notifier: store);

  static LibraryStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing to changes (for event handlers).
  static LibraryStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }
}
