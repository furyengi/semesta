import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/library_service.dart';
import '../core/services.dart';
import 'doc_sheets.dart';

/// Lets the user pick PDFs and adds them to the library. [onBusy] reports
/// when the (possibly slow) copy-and-scan phase starts and ends.
Future<void> pickAndImport(
  BuildContext context, {
  ValueChanged<bool>? onBusy,
}) async {
  final library = ServicesScope.of(context).library;
  final messenger = ScaffoldMessenger.of(context);

  List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'Add PDFs',
    );
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text("Couldn't open the file picker")),
      );
    return;
  }
  if (files.isEmpty) return;

  onBusy?.call(true);
  final ImportResult result;
  try {
    result = await library.importFiles([
      for (final f in files)
        PickedFile(name: f.name, path: f.path, readBytes: f.readAsBytes),
    ]);
  } finally {
    onBusy?.call(false);
  }

  final added = result.added;
  final failed = result.failed;
  final message = [
    if (added.length == 1) 'Added "${added.first.title}"',
    if (added.length > 1) 'Added ${added.length} documents',
    if (failed.isNotEmpty)
      failed.length == 1
          ? "Couldn't read ${failed.first}"
          : "Couldn't read ${failed.length} files",
  ].join(' · ');

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: added.length == 1
            ? SnackBarAction(
                label: 'Details',
                onPressed: () {
                  if (context.mounted) showDocEditor(context, added.first);
                },
              )
            : null,
      ),
    );
}
