import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store_scope.dart';
import '../theme/app_theme.dart';
import '../theme/brutal_theme.dart';
import 'brutal.dart';
import 'helpers.dart';
import 'sheets.dart';

enum _LinkAction { open, copy, move, rename, delete }

/// A saved link. Swipe to delete (with undo) or use the overflow menu.
class LinkTile extends StatelessWidget {
  const LinkTile({super.key, required this.link, this.showCollection = false});

  final LinkItem link;
  final bool showCollection;

  void _delete(BuildContext context) {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    store.deleteLink(link.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Link deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.restoreLink(link),
          ),
        ),
      );
  }

  Future<void> _rename(BuildContext context) async {
    final store = StoreScope.read(context);
    final controller = TextEditingController(text: link.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) store.renameLink(link.id, result);
  }

  Future<void> _onAction(BuildContext context, _LinkAction a) async {
    switch (a) {
      case _LinkAction.open:
        await openLink(context, link.url);
      case _LinkAction.copy:
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: link.url));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Link copied')));
      case _LinkAction.move:
        await showMoveSheet(context, link);
      case _LinkAction.rename:
        await _rename(context);
      case _LinkAction.delete:
        _delete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brutal = BrutalTheme.of(context);
    final store = StoreScope.of(context);
    final accent = colorForHost(link.host);
    final where = showCollection
        ? store.collection(link.collectionId)?.name
        : null;
    final subtitle = [link.host, ?where, timeAgo(link.createdAt)].join(' · ');

    return Dismissible(
      key: ValueKey(link.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: BrutalBox(
        offset: const Offset(3, 4),
        onTap: () => openLink(context, link.url),
        onLongPress: () => showMoveSheet(context, link),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: brutal.border,
                  width: brutal.borderWidth,
                ),
              ),
              child: Text(
                link.host.isEmpty ? '?' : link.host[0].toUpperCase(),
                style: text.titleMedium?.copyWith(
                  color: CollectionPalette.on(accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_LinkAction>(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (a) => _onAction(context, a),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _LinkAction.open,
                  child: _MenuRow(Icons.open_in_new_rounded, 'Open'),
                ),
                PopupMenuItem(
                  value: _LinkAction.copy,
                  child: _MenuRow(Icons.copy_rounded, 'Copy link'),
                ),
                PopupMenuItem(
                  value: _LinkAction.move,
                  child: _MenuRow(Icons.drive_file_move_outlined, 'Move to…'),
                ),
                PopupMenuItem(
                  value: _LinkAction.rename,
                  child: _MenuRow(Icons.edit_outlined, 'Rename'),
                ),
                PopupMenuItem(
                  value: _LinkAction.delete,
                  child: _MenuRow(Icons.delete_outline_rounded, 'Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
  );
}
