import 'package:flutter/widgets.dart';

import 'doc_storage.dart';
import 'library_service.dart';
import 'pdf_backend.dart';

/// Engine and storage dependencies, injected so tests can swap them.
class Services {
  const Services({
    required this.library,
    required this.storage,
    required this.backend,
  });

  final LibraryService library;
  final DocStorage storage;
  final PdfBackend backend;
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final Services services;

  static Services of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'No ServicesScope found in context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope old) => services != old.services;
}
