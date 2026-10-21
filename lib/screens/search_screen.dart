import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../data/store_scope.dart';
import '../widgets/brutal.dart';
import '../widgets/folder_card.dart';
import '../widgets/helpers.dart';
import '../widgets/link_tile.dart';
import 'collection_screen.dart';
import 'home_screen.dart' show contentGutter;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter + 4, 16),
              child: Row(
                children: [
                  BrutalIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: BrutalShadow(
                      pressable: false,
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search links & collections',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(_controller.clear),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation, secondary) =>
                    FadeThroughTransition(
                      animation: animation,
                      secondaryAnimation: secondary,
                      fillColor: Colors.transparent,
                      child: child,
                    ),
                child: _Results(
                  key: ValueKey(_modeFor(store, _controller.text)),
                  query: _controller.text,
                  gutter: gutter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeFor(AppStore store, String q) {
    if (q.trim().isEmpty) return 'recent';
    final hasAny =
        store.searchLinks(q).isNotEmpty ||
        store.searchCollections(q).isNotEmpty;
    return hasAny ? 'results' : 'none';
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.query, required this.gutter});

  final String query;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final empty = query.trim().isEmpty;
    final links = empty ? store.recentLinks(8) : store.searchLinks(query);
    final collections = empty ? <Collection>[] : store.searchCollections(query);

    if (!empty && links.isEmpty && collections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text('No matches', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Nothing saved matches "${query.trim()}".',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 40),
      children: [
        if (collections.isNotEmpty) ...[
          Text('Collections', style: text.titleMedium),
          const SizedBox(height: 12),
          for (final c in collections)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BrutalBox(
                offset: const Offset(3, 4),
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionScreen(collectionId: c.id),
                  ),
                ),
                child: Row(
                  children: [
                    CollectionTile(collection: c),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name, style: text.titleSmall)),
                    Text(
                      plural(store.linkCount(c.id), 'link'),
                      style: text.labelMedium,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (links.isNotEmpty) ...[
          Text(empty ? 'Recently saved' : 'Links', style: text.titleMedium),
          const SizedBox(height: 12),
          for (final l in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LinkTile(
                key: ValueKey(l.id),
                link: l,
                showCollection: true,
              ),
            ),
        ] else if (empty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text('Saved links show up here.', style: text.bodyMedium),
            ),
          ),
      ],
    );
  }
}
