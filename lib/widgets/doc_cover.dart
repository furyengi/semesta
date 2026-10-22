import 'package:flutter/material.dart';

import '../core/pdf_backend.dart';
import '../core/services.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// First-page thumbnail for a document, with a category-coloured placeholder
/// while it loads (or if the file can't be read).
class DocCover extends StatefulWidget {
  const DocCover({super.key, required this.doc});

  final Doc doc;

  @override
  State<DocCover> createState() => _DocCoverState();
}

class _DocCoverState extends State<DocCover> {
  late final Future<DocSource?> _source = ServicesScope.of(context).storage
      .open(widget.doc.storageKey);

  @override
  Widget build(BuildContext context) {
    final backend = ServicesScope.of(context).backend;
    final category = widget.doc.category;
    return ColoredBox(
      color: category.color.withValues(alpha: .85),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              category.icon,
              size: 36,
              color: AccentPalette.on(category.color),
            ),
          ),
          FutureBuilder<DocSource?>(
            future: _source,
            builder: (context, snap) {
              final source = snap.data;
              return AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium2),
                switchInCurve: Motion.standard,
                child: source == null
                    ? const SizedBox.expand(key: ValueKey('empty'))
                    : KeyedSubtree(
                        key: ValueKey(source.id),
                        child: SizedBox.expand(
                          child: ColoredBox(
                            color: Colors.white,
                            child: backend.buildCover(source),
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}
