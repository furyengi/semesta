import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../data/store_scope.dart';
import '../theme/app_theme.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import 'folder_card.dart';

/// Modal sheet to pick the collection a link should live in.
Future<void> showMoveSheet(BuildContext context, LinkItem link) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      final tree = store.tree();
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        minChildSize: .4,
        maxChildSize: .9,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Move to', style: text.titleLarge),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: tree.length,
                itemBuilder: (context, i) {
                  final (c, depth) = tree[i];
                  final selected = c.id == link.collectionId;
                  return ListTile(
                    contentPadding: EdgeInsetsDirectional.only(
                      start: 24.0 + depth * 20,
                      end: 24,
                    ),
                    leading: CollectionTile(collection: c, size: 36),
                    title: Text(c.name, style: text.titleSmall),
                    trailing: selected ? const Icon(Icons.check_rounded) : null,
                    selected: selected,
                    onTap: () {
                      store.moveLink(link.id, c.id);
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Create a collection (or sub-folder when [parentId] is set), or edit
/// [existing].
Future<void> showCollectionEditor(
  BuildContext context, {
  Collection? existing,
  String? parentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CollectionEditor(
      store: StoreScope.read(context),
      existing: existing,
      parentId: parentId,
    ),
  );
}

class _CollectionEditor extends StatefulWidget {
  const _CollectionEditor({required this.store, this.existing, this.parentId});

  final AppStore store;
  final Collection? existing;
  final String? parentId;

  @override
  State<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<_CollectionEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  )..addListener(() => setState(() {}));
  late int _color = widget.existing?.colorIndex ?? 1;
  late String _icon = widget.existing?.iconKey ?? 'folder';

  bool get _editing => widget.existing != null;
  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    if (_editing) {
      widget.store.updateCollection(
        widget.existing!.id,
        name: _name.text,
        colorIndex: _color,
        iconKey: _icon,
      );
    } else {
      widget.store.addCollection(
        name: _name.text,
        colorIndex: _color,
        iconKey: _icon,
        parentId: widget.parentId,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = _editing
        ? 'Edit collection'
        : widget.parentId == null
        ? 'New collection'
        : 'New folder';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLength: 40,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            Text('Colour', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < CollectionPalette.colors.length; i++)
                  _Choice(
                    selected: _color == i,
                    fill: CollectionPalette.colors[i],
                    circle: true,
                    semanticLabel: 'Colour ${i + 1}',
                    onTap: () => setState(() => _color = i),
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icon', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in CollectionIcons.all.entries)
                  _Choice(
                    selected: _icon == e.key,
                    fill: CollectionPalette.colors[_color],
                    semanticLabel: e.key,
                    onTap: () => setState(() => _icon = e.key),
                    child: Icon(e.value, color: const Color(0xFF111111)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(_editing ? 'Save' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.fill,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.circle = false,
  });

  final bool selected;
  final Color fill;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final brutal = BrutalTheme.of(context);
    final radius = circle ? 24.0 : 12.0;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.short4),
          curve: Motion.emphasized,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected || circle ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? brutal.border
                  : brutal.border.withValues(alpha: .35),
              width: selected ? brutal.borderWidth + 1 : brutal.borderWidth,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!circle) child,
              if (circle)
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: Motion.of(context, Motion.short4),
                  curve: Motion.emphasized,
                  child: Icon(
                    Icons.check_rounded,
                    color: CollectionPalette.on(fill),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
