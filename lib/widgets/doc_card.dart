import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../screens/reader_screen.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import 'brutal.dart';
import 'doc_cover.dart';
import 'doc_sheets.dart';

String progressLabel(Doc d) {
  if (d.finished) return 'Finished';
  if (!d.hasStarted) {
    return d.pageCount == 0 ? 'New' : '${d.pageCount} pages';
  }
  return '${(d.progress * 100).round()}%';
}

/// Slim outlined progress bar that animates between values.
class MiniProgress extends StatelessWidget {
  const MiniProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brutal = BrutalTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: brutal.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: Motion.of(context, Motion.long2),
        curve: Motion.emphasized,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: ColoredBox(
              color: color ?? scheme.primary,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Library grid card. Opens the reader with an M3 container transform.
class DocCard extends StatelessWidget {
  const DocCard({super.key, required this.doc});

  final Doc doc;

  /// Row height for grids of cards, scaled for large text settings.
  static double extentFor(BuildContext context) =>
      270 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${doc.title}, ${doc.category.label}, ${progressLabel(doc)}',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: () => showDocEditor(context, doc),
        child: BrutalShadow(
          child: OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            transitionDuration: Motion.of(context, Motion.long2),
            closedElevation: 0,
            openElevation: 0,
            closedColor: brutal.card,
            openColor: scheme.surface,
            middleColor: scheme.surface,
            closedShape: brutalShape(context),
            openShape: const RoundedRectangleBorder(),
            routeSettings: RouteSettings(name: 'reader/${doc.id}'),
            openBuilder: (_, _) => ReaderScreen(docId: doc.id),
            closedBuilder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DocCover(doc: doc),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _MoreButton(doc: doc),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: brutal.borderWidth,
                  thickness: brutal.borderWidth,
                  color: brutal.border,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: MiniProgress(value: doc.progress)),
                          const SizedBox(width: 8),
                          Text(progressLabel(doc), style: text.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.doc});

  final Doc doc;

  @override
  Widget build(BuildContext context) {
    final brutal = BrutalTheme.of(context);
    return Tooltip(
      message: 'Details',
      child: Material(
        color: brutal.card,
        shape: CircleBorder(
          side: BorderSide(color: brutal.border, width: brutal.borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDocEditor(context, doc),
          child: const SizedBox.square(
            dimension: 32,
            child: Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ),
      ),
    );
  }
}

/// Hero card for the document you were last reading.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.doc});

  final Doc doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    final text = Theme.of(context).textTheme;
    final on = scheme.onPrimary;

    return Semantics(
      button: true,
      label:
          'Continue reading ${doc.title}, page ${doc.lastPage} of ${doc.pageCount}',
      excludeSemantics: true,
      child: BrutalShadow(
        child: OpenContainer(
          transitionType: ContainerTransitionType.fadeThrough,
          transitionDuration: Motion.of(context, Motion.long2),
          closedElevation: 0,
          openElevation: 0,
          closedColor: scheme.primary,
          openColor: scheme.surface,
          middleColor: scheme.surface,
          closedShape: brutalShape(context),
          openShape: const RoundedRectangleBorder(),
          routeSettings: RouteSettings(name: 'reader/${doc.id}'),
          openBuilder: (_, _) => ReaderScreen(docId: doc.id),
          closedBuilder: (context, _) => Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: brutal.border,
                      width: brutal.borderWidth,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DocCover(doc: doc),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTINUE READING',
                        style: text.labelSmall?.copyWith(
                          color: on.withValues(alpha: .75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(color: on),
                      ),
                      const SizedBox(height: 10),
                      MiniProgress(value: doc.progress, color: on, height: 8),
                      const SizedBox(height: 6),
                      Text(
                        'Page ${doc.lastPage} of ${doc.pageCount}',
                        style: text.labelMedium?.copyWith(color: on),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: on),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
