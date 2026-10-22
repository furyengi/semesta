import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/pdf_backend.dart';
import '../core/services.dart';
import '../data/library_store.dart';
import '../data/models.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import '../widgets/doc_sheets.dart';

enum _ReaderMenu { bookmarks, goToPage, night, details }

/// Full-screen reader. Tap the page to show or hide the controls; progress
/// and the current page are saved as you read.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.docId, this.initialPage});

  final String docId;

  /// Open at this page instead of the saved position (e.g. from a lecture).
  final int? initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _handle = ReaderHandle();
  Services? _services;
  late final LibraryStore _store;
  DocSource? _source;
  bool _loaded = false;
  bool _chrome = true;
  late int _page;
  late int _pageCount;
  double? _scrub;
  Timer? _saveTimer;
  bool _dirty = false;

  /// Invert + hue-rotate(180°): white pages go black and text goes light,
  /// while colours (like a yellow banner) stay roughly the same hue instead
  /// of flipping to their opposites.
  static const _nightInvert = ColorFilter.matrix(<double>[
    0.574, -1.430, -0.144, 0, 255, //
    -0.426, -0.430, -0.144, 0, 255,
    -0.426, -1.430, 0.856, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    _services = ServicesScope.of(context);
    _store = StoreScope.read(context);
    final store = _store;
    final doc = store.doc(widget.docId);
    _pageCount = doc?.pageCount ?? 0;
    final wanted = widget.initialPage ?? doc?.lastPage ?? 1;
    _page = _pageCount > 0 ? wanted.clamp(1, _pageCount) : wanted;
    if (doc != null) {
      // Notifying during build is not allowed, so do it right after.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => store.markOpened(doc.id),
      );
      _services!.storage.open(doc.storageKey).then((s) {
        if (!mounted) return;
        setState(() {
          _source = s;
          _loaded = true;
        });
      });
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_dirty) {
      final store = _store;
      final id = widget.docId, page = _page, count = _pageCount;
      // Defer: notifying listeners while the tree is unmounting is unsafe.
      scheduleMicrotask(() {
        store.recordProgress(id, page: page, pageCount: count);
        store.flush();
      });
    }
    super.dispose();
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _onPosition(ReaderPosition p) {
    if (p.page == _page && p.pageCount == _pageCount && !_dirty) return;
    setState(() {
      _page = p.page;
      _pageCount = p.pageCount;
    });
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  void _save() {
    if (!_dirty || !mounted) return;
    _dirty = false;
    _store.recordProgress(widget.docId, page: _page, pageCount: _pageCount);
  }

  Future<void> _goTo(int page) async {
    final target = page.clamp(1, _pageCount < 1 ? 1 : _pageCount);
    await _handle.goToPage(target);
  }

  Future<void> _askPage() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(page: _page, pageCount: _pageCount),
    );
    if (result != null) await _goTo(result);
  }

  void _toggleBookmark(Doc doc) {
    final store = StoreScope.read(context);
    final added = store.toggleBookmark(doc.id, _page);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          // Sit above the page slider instead of covering it.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          content: Text(added ? 'Bookmarked page $_page' : 'Bookmark removed'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final doc = store.doc(widget.docId);
    final scheme = Theme.of(context).colorScheme;
    final night = store.nightReading;

    if (doc == null || (_loaded && _source == null)) {
      return _Unavailable(doc: doc);
    }

    final background = night
        ? const Color(0xFFE6E6E6)
        : const Color(0xFF1B1A17);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: night ? Colors.black : background,
        body: Stack(
          children: [
            Positioned.fill(
              child: _source == null
                  ? const Center(child: CircularProgressIndicator())
                  : ColorFiltered(
                      colorFilter: night
                          ? _nightInvert
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: _services!.backend.buildViewer(
                        source: _source!,
                        initialPage: _page,
                        handle: _handle,
                        onPosition: _onPosition,
                        onTap: _toggleChrome,
                        background: background,
                      ),
                    ),
            ),
            _ChromeBar(
              visible: _chrome,
              top: true,
              child: _TopBar(
                doc: doc,
                page: _page,
                pageCount: _pageCount,
                bookmarked: doc.isBookmarked(_page),
                night: night,
                onBookmark: () => _toggleBookmark(doc),
                onMenu: (m) {
                  switch (m) {
                    case _ReaderMenu.bookmarks:
                      showBookmarksSheet(
                        context,
                        docId: doc.id,
                        currentPage: _page,
                        onGoTo: _goTo,
                      );
                    case _ReaderMenu.goToPage:
                      _askPage();
                    case _ReaderMenu.night:
                      store.nightReading = !night;
                    case _ReaderMenu.details:
                      showDocEditor(context, doc);
                  }
                },
              ),
            ),
            _ChromeBar(
              visible: _chrome && _pageCount > 1,
              top: false,
              child: _BottomBar(
                page: _page,
                pageCount: _pageCount,
                scrub: _scrub,
                accent: scheme.primary,
                onScrub: (v) => setState(() => _scrub = v),
                onScrubEnd: (v) {
                  setState(() => _scrub = null);
                  _goTo(v.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides and fades a bar in or out from the top or bottom edge.
class _ChromeBar extends StatelessWidget {
  const _ChromeBar({
    required this.visible,
    required this.top,
    required this.child,
  });

  final bool visible;
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.medium2);
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: duration,
          curve: visible
              ? Motion.emphasizedDecelerate
              : Motion.emphasizedAccelerate,
          offset: visible ? Offset.zero : Offset(0, top ? -1 : 1),
          child: AnimatedOpacity(
            duration: duration,
            curve: Motion.standard,
            opacity: visible ? 1 : 0,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.doc,
    required this.page,
    required this.pageCount,
    required this.bookmarked,
    required this.night,
    required this.onBookmark,
    required this.onMenu,
  });

  final Doc doc;
  final int page;
  final int pageCount;
  final bool bookmarked;
  final bool night;
  final VoidCallback onBookmark;
  final ValueChanged<_ReaderMenu> onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainer.withValues(alpha: .96),
      elevation: 2,
      shadowColor: Colors.black,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 4),
              const BackButton(),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    if (pageCount > 0)
                      Text(
                        'Page $page of $pageCount',
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark this page',
                onPressed: onBookmark,
                icon: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.short4),
                  switchInCurve: Motion.emphasizedDecelerate,
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    key: ValueKey(bookmarked),
                    color: bookmarked ? scheme.primary : null,
                  ),
                ),
              ),
              PopupMenuButton<_ReaderMenu>(
                tooltip: 'More options',
                onSelected: onMenu,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _ReaderMenu.bookmarks,
                    child: ListTile(
                      leading: Icon(Icons.bookmarks_outlined),
                      title: Text('Bookmarks'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _ReaderMenu.goToPage,
                    child: ListTile(
                      leading: Icon(Icons.pin_outlined),
                      title: Text('Go to page'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  CheckedPopupMenuItem(
                    value: _ReaderMenu.night,
                    checked: night,
                    child: const Text('Night reading'),
                  ),
                  const PopupMenuItem(
                    value: _ReaderMenu.details,
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Document details'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.pageCount,
    required this.scrub,
    required this.accent,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final int page;
  final int pageCount;
  final double? scrub;
  final Color accent;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final value = (scrub ?? page.toDouble()).clamp(1.0, pageCount.toDouble());
    final percent = ((value - 1) / (pageCount - 1) * 100).round();
    return Material(
      color: scheme.surfaceContainer.withValues(alpha: .96),
      elevation: 2,
      shadowColor: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('${value.round()}', style: text.labelLarge),
              ),
              Expanded(
                child: Slider(
                  min: 1,
                  max: pageCount.toDouble(),
                  divisions: pageCount <= 400 ? pageCount - 1 : null,
                  value: value,
                  label: 'Page ${value.round()}',
                  onChanged: onScrub,
                  onChangeEnd: onScrubEnd,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.end,
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.doc});

  final Doc? doc;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final services = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 48),
              const SizedBox(height: 16),
              Text('This file isn’t available', style: text.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'It may have been removed from the device. You can take it out '
                'of your library and add it again.',
                textAlign: TextAlign.center,
              ),
              if (doc != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await services.library.delete(doc!);
                    nav.maybePop();
                  },
                  child: const Text('Remove from library'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.page, required this.pageCount});

  final int page;
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.page}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: '1 – ${widget.pageCount}',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_controller.text)),
          child: const Text('Go'),
        ),
      ],
    );
  }
}
