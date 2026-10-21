import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store_scope.dart';
import '../screens/collection_screen.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import 'brutal.dart';
import 'helpers.dart';

/// Folder-shaped card for a collection. Opens its screen with an M3
/// container transform.
class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.collection});

  final Collection collection;

  static const double tabInset = 14;

  /// Row height for grids of folder cards, scaled for large text settings.
  static double extentFor(BuildContext context) =>
      164 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    final links = store.linkCount(collection.id);
    final folders = store.folderCount(collection.id);

    final label = [
      collection.name,
      plural(links, 'link'),
      if (folders > 0) plural(folders, 'folder'),
      if (collection.isNew) 'new',
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BrutalShadow(
        topInset: tabInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: FractionallySizedBox(
                    widthFactor: .5,
                    child: Container(
                      height: tabInset + 14,
                      decoration: BoxDecoration(
                        color: collection.color,
                        border: Border.all(
                          color: brutal.border,
                          width: brutal.borderWidth,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: tabInset),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                transitionDuration: Motion.of(context, Motion.long2),
                closedElevation: 0,
                openElevation: 0,
                closedColor: scheme.surfaceContainerLowest,
                openColor: scheme.surface,
                middleColor: scheme.surface,
                closedShape: brutalShape(context),
                openShape: const RoundedRectangleBorder(),
                routeSettings: RouteSettings(
                  name: 'collection/${collection.id}',
                ),
                openBuilder: (_, _) =>
                    CollectionScreen(collectionId: collection.id),
                closedBuilder: (context, _) => Padding(
                  padding: const EdgeInsets.all(14),
                  child: _CardBody(
                    collection: collection,
                    links: links,
                    folders: folders,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.collection,
    required this.links,
    required this.folders,
  });

  final Collection collection;
  final int links;
  final int folders;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .7),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CollectionTile(collection: collection),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AnimatedCount(text: plural(links, 'link'), style: muted),
                      if (collection.isNew) const NewBadge(),
                    ],
                  ),
                  if (folders > 0)
                    AnimatedCount(
                      text: plural(folders, 'folder'),
                      style: muted,
                    ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          collection.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
      ],
    );
  }
}

/// Coloured rounded square holding a collection's icon.
class CollectionTile extends StatelessWidget {
  const CollectionTile({super.key, required this.collection, this.size = 40});

  final Collection collection;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brutal = BrutalTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: collection.color,
        borderRadius: BorderRadius.circular(size * .25),
        border: Border.all(color: brutal.border, width: brutal.borderWidth),
      ),
      child: Icon(
        collection.icon,
        size: size * .55,
        color: const Color(0xFF111111),
      ),
    );
  }
}

class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'NEW',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onTertiary, fontSize: 10),
        ),
      ),
    );
  }
}

/// Text that slides and fades when its value changes (e.g. link counts).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium2),
      switchInCurve: Motion.emphasizedDecelerate,
      switchOutCurve: Motion.emphasizedAccelerate,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .5),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}
