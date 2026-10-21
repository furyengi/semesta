import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store_scope.dart';
import '../widgets/brutal.dart';
import '../widgets/folder_card.dart';
import '../widgets/link_tile.dart';
import '../widgets/paste_bar.dart';
import '../widgets/sheets.dart';
import '../widgets/helpers.dart';
import 'home_screen.dart' show contentGutter, gridColumns;

enum _CollectionAction { edit, newFolder, delete }

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.collectionId});

  final String collectionId;

  Future<void> _delete(BuildContext context, Collection c, int links) async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('Delete "${c.name}"?'),
        content: Text(
          links == 0
              ? 'This collection is empty.'
              : '${plural(links, 'saved link')} will be moved to Unsorted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      nav.pop();
      store.deleteCollection(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = store.collection(collectionId);
    if (c == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final scheme = Theme.of(context).colorScheme;
    final links = store.linksIn(c.id);
    final folders = store.children(c.id);
    final gutter = contentGutter(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<_CollectionAction>(
                tooltip: 'More options',
                onSelected: (a) {
                  switch (a) {
                    case _CollectionAction.edit:
                      showCollectionEditor(context, existing: c);
                    case _CollectionAction.newFolder:
                      showCollectionEditor(context, parentId: c.id);
                    case _CollectionAction.delete:
                      _delete(context, c, store.linkCount(c.id));
                  }
                },
                itemBuilder: (_) => [
                  if (!c.isUnsorted)
                    const PopupMenuItem(
                      value: _CollectionAction.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _CollectionAction.newFolder,
                    child: ListTile(
                      leading: Icon(Icons.create_new_folder_outlined),
                      title: Text('New folder'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!c.isUnsorted)
                    const PopupMenuItem(
                      value: _CollectionAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
            sliver: SliverToBoxAdapter(child: PasteBar(collectionId: c.id)),
          ),
          if (folders.isNotEmpty) ...[
            _SectionHeader(
              gutter: gutter,
              title: plural(folders.length, 'Folder'),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 0),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(context),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 18,
                  mainAxisExtent: FolderCard.extentFor(context),
                ),
                itemCount: folders.length,
                itemBuilder: (context, i) => Reveal(
                  key: ValueKey(folders[i].id),
                  index: i,
                  child: FolderCard(collection: folders[i]),
                ),
              ),
            ),
          ],
          _SectionHeader(gutter: gutter, title: plural(links.length, 'Link')),
          if (links.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(collection: c, gutter: gutter),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 40),
              sliver: SliverList.separated(
                itemCount: links.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                findItemIndexCallback: (key) {
                  final id = (key as ValueKey<String>).value;
                  final i = links.indexWhere((l) => l.id == id);
                  return i < 0 ? null : i;
                },
                itemBuilder: (context, i) => Reveal(
                  key: ValueKey(links[i].id),
                  index: i,
                  child: LinkTile(link: links[i]),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: scheme.surface,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.gutter, required this.title});

  final double gutter;
  final String title;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 16),
    sliver: SliverToBoxAdapter(
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.collection, required this.gutter});

  final Collection collection;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 64),
      child: Column(
        children: [
          Reveal(child: CollectionTile(collection: collection, size: 72)),
          const SizedBox(height: 20),
          Text('Nothing here yet', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Paste a link above to save it to ${collection.name}.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
