import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store_scope.dart';
import '../widgets/doc_card.dart' show progressLabel;
import '../widgets/doc_cover.dart';
import '../screens/reader_screen.dart';

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
    final query = _controller.text;
    final empty = query.trim().isEmpty;
    final results = empty
        ? store.docsSorted().take(8).toList()
        : store.search(query);
    final mode = empty ? 'recent' : (results.isEmpty ? 'none' : 'results');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: SearchBar(
                      controller: _controller,
                      autoFocus: true,
                      elevation: const WidgetStatePropertyAll(0),
                      hintText: 'Search your library',
                      onChanged: (_) => setState(() {}),
                      trailing: [
                        if (!empty)
                          IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_controller.clear),
                          ),
                      ],
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
                  key: ValueKey(mode),
                  mode: mode,
                  docs: results,
                  query: query,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.mode,
    required this.docs,
    required this.query,
  });

  final String mode;
  final List<Doc> docs;
  final String query;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (mode == 'none') {
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
                'Nothing in your library matches "${query.trim()}".',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Text(
            mode == 'recent' ? 'Recent' : 'Documents',
            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        for (final d in docs)
          ListTile(
            key: ValueKey(d.id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 60, child: DocCover(doc: d)),
            ),
            title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${d.category.label} · ${progressLabel(d)}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ReaderScreen(docId: d.id),
              ),
            ),
          ),
        if (mode == 'recent' && docs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                'Your documents show up here.',
                style: text.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }
}
