import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../data/store_scope.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import 'brutal.dart';
import 'sheets.dart';

/// "Paste link to save" field with a clipboard shortcut and a save button.
class PasteBar extends StatefulWidget {
  const PasteBar({super.key, this.collectionId = Collection.unsortedId});

  final String collectionId;

  @override
  State<PasteBar> createState() => _PasteBarState();
}

class _PasteBarState extends State<PasteBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: Motion.medium4,
    value: 1,
  );
  Timer? _savedTimer;
  String? _error;
  bool _justSaved = false;

  @override
  void dispose() {
    _savedTimer?.cancel();
    _shake.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() {
      _error = null;
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });
  }

  void _submit() {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = store.addLink(
      _controller.text,
      collectionId: widget.collectionId,
    );
    switch (result) {
      case AddLinkResult.invalid:
        HapticFeedback.lightImpact();
        setState(
          () => _error = 'Paste a valid web link, like example.com/page',
        );
        if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
      case AddLinkResult.duplicate:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('That link is already saved here')),
          );
      case AddLinkResult.added:
        HapticFeedback.selectionClick();
        final link = store.lastAdded!;
        final name = store.collection(widget.collectionId)?.name ?? 'Unsorted';
        _controller.clear();
        FocusScope.of(context).unfocus();
        setState(() {
          _error = null;
          _justSaved = true;
        });
        _savedTimer?.cancel();
        _savedTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _justSaved = false);
        });
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Saved to $name'),
              action: SnackBarAction(
                label: 'Move',
                onPressed: () {
                  if (mounted) showMoveSheet(context, link);
                },
              ),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    final text = Theme.of(context).textTheme;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.error, width: brutal.borderWidth),
    );

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BrutalShadow(
                  pressable: false,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Paste link to save',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Paste from clipboard',
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: _paste,
                      ),
                      enabledBorder: _error != null ? errorBorder : null,
                      focusedBorder: _error != null ? errorBorder : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox.square(
                dimension: 56,
                child: Tooltip(
                  message: 'Save link',
                  child: Semantics(
                    button: true,
                    label: 'Save link',
                    excludeSemantics: true,
                    child: BrutalBox(
                      color: scheme.primary,
                      onTap: _submit,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.medium2),
                          switchInCurve: Motion.emphasizedDecelerate,
                          switchOutCurve: Motion.emphasizedAccelerate,
                          transitionBuilder: (child, a) => RotationTransition(
                            turns: Tween(begin: .25, end: 0.0).animate(a),
                            child: ScaleTransition(scale: a, child: child),
                          ),
                          child: Icon(
                            _justSaved
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            key: ValueKey(_justSaved),
                            size: 30,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium2),
            curve: Motion.emphasized,
            alignment: Alignment.topLeft,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _error!,
                      style: text.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
