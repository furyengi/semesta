import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store_scope.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/doc_card.dart';
import '../widgets/next_up_card.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Max width of the content column on wide screens.
const double kContentMaxWidth = 840;

/// Horizontal gutter that centres content on wide screens.
double contentGutter(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w > kContentMaxWidth + 40 ? (w - kContentMaxWidth) / 2 : 20;
}

int gridColumns(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 840) return 4;
  if (w >= 560) return 3;
  return 2;
}

/// The Library tab: continue reading, what's next, and the document grid.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key, required this.importing});

  /// True while a file import is running (driven by the shell's Add button).
  final ValueListenable<bool> importing;

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  DocCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);

    final used = store.usedCategories;
    final filter = used.contains(_filter) ? _filter : null;
    final docs = store.docsSorted(filter);
    final resume = store.continueReading;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    BrutalIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const _SearchButton(),
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.medium2),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.topStart,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    resume != null
                        ? 'Pick up where\nyou left off.'
                        : 'Read. Learn.\nProgress.',
                    key: ValueKey(resume != null),
                    style: text.displayMedium,
                  ),
                ),
                AnimatedSize(
                  duration: Motion.of(context, Motion.medium2),
                  curve: Motion.emphasized,
                  alignment: Alignment.topCenter,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: widget.importing,
                    builder: (context, busy, _) => busy
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 6),
                                Text(
                                  'Adding to your library…',
                                  style: text.labelMedium,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ),
                if (resume != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Reveal(child: ContinueCard(doc: resume)),
                  ),
                ],
                const NextUpCard(),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text('Library', style: text.titleLarge),
                    const SizedBox(width: 8),
                    Text(
                      '${docs.length}',
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (used.length > 1) ...[
                  const SizedBox(height: 12),
                  _CategoryFilter(
                    categories: used,
                    selected: filter,
                    onSelected: (c) => setState(() => _filter = c),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (store.docs.isEmpty)
            SliverToBoxAdapter(child: _EmptyLibrary(gutter: gutter))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 112),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(context),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 18,
                  mainAxisExtent: DocCard.extentFor(context),
                ),
                itemCount: docs.length,
                findChildIndexCallback: (key) {
                  final id = (key as ValueKey<String>).value;
                  final i = docs.indexWhere((d) => d.id == id);
                  return i < 0 ? null : i;
                },
                itemBuilder: (context, i) => Reveal(
                  key: ValueKey(docs[i].id),
                  index: i,
                  child: DocCard(doc: docs[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<DocCategory> categories;
  final DocCategory? selected;
  final ValueChanged<DocCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(c.icon, size: 18),
              label: Text(c.label),
              selected: selected == c,
              onSelected: (_) => onSelected(selected == c ? null : c),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 120),
      child: Reveal(
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Your library is empty', style: text.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Add a PDF to start reading. Semesta remembers your place.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Search icon that expands into the search screen (M3 container transform).
class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    return Tooltip(
      message: 'Search',
      child: Semantics(
        button: true,
        label: 'Search',
        excludeSemantics: true,
        child: BrutalShadow(
          radius: 12,
          offset: const Offset(3, 4),
          child: SizedBox.square(
            dimension: 48,
            child: OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              transitionDuration: Motion.of(context, Motion.long2),
              closedElevation: 0,
              openElevation: 0,
              closedColor: brutal.card,
              openColor: scheme.surface,
              middleColor: scheme.surface,
              closedShape: brutalShape(context, 12),
              openShape: const RoundedRectangleBorder(),
              openBuilder: (_, _) => const SearchScreen(),
              closedBuilder: (_, _) =>
                  const Center(child: Icon(Icons.search_rounded, size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}
