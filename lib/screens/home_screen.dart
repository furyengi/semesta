import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/folder_card.dart';
import '../widgets/paste_bar.dart';
import '../widgets/sheets.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final collections = store.rootCollections;
    final gutter = contentGutter(context);

    return Scaffold(
      body: SafeArea(
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
                      BrutalIconButton(
                        icon: Icons.create_new_folder_outlined,
                        tooltip: 'New collection',
                        onPressed: () => showCollectionEditor(context),
                      ),
                      const SizedBox(width: 14),
                      const _SearchButton(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Save now.\nFind anytime.', style: text.displayMedium),
                  const SizedBox(height: 24),
                  const PasteBar(),
                  const SizedBox(height: 28),
                  Text('My Collections', style: text.titleMedium),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 32),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(context),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 18,
                  mainAxisExtent: FolderCard.extentFor(context),
                ),
                itemCount: collections.length,
                findChildIndexCallback: (key) {
                  final id = (key as ValueKey<String>).value;
                  final i = collections.indexWhere((c) => c.id == id);
                  return i < 0 ? null : i;
                },
                itemBuilder: (context, i) => Reveal(
                  key: ValueKey(collections[i].id),
                  index: i,
                  child: FolderCard(collection: collections[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

/// Search icon that expands into the search screen (M3 container transform).
class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              closedColor: scheme.surfaceContainerLowest,
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
