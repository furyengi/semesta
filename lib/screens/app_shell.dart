import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/services.dart';
import '../data/academic_models.dart';
import '../data/reminder_planner.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/course_sheets.dart';
import '../widgets/event_sheets.dart';
import '../widgets/import_flow.dart';
import '../widgets/material_link.dart';
import 'calendar_tab.dart';
import 'courses_tab.dart';
import 'home_screen.dart';
import 'planner_tab.dart';

/// Bottom navigation between Library, Courses and Calendar. Tabs stay alive
/// (scroll position, filters) and cross-fade.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _fabExtended = true;
  final _importing = ValueNotifier<bool>(false);
  final _calendarDay = ValueNotifier<DateTime>(dateOnly(DateTime.now()));

  StreamSubscription<String>? _taps;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    final reminders = ServicesScope.of(context).reminders;
    _taps = reminders.taps.listen(_openFromReminder);
    // The notification that started the app, if any.
    reminders.takeLaunchPayload().then((p) {
      if (p != null && mounted) _openFromReminder(p);
    });
  }

  /// Takes the user where a tapped reminder points.
  void _openFromReminder(String payload) {
    final target = parseReminderPayload(payload);
    if (target == null || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    final tab = target.tab;
    if (tab != null && tab >= 0 && tab <= 3) _select(tab);
    final docId = target.docId;
    if (docId != null) {
      openMaterial(context, MaterialLink(docId: docId, page: target.page));
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    _importing.dispose();
    _calendarDay.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0) return false;
    final extended = n.direction != ScrollDirection.reverse;
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _fabExtended = true;
    });
  }

  Widget _fab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bold(IconData icon, String label, VoidCallback? onPressed) =>
        BrutalShadow(
          key: ValueKey(label),
          radius: 16,
          offset: const Offset(3, 4),
          child: FloatingActionButton.extended(
            // No hero: tab changes and route pushes can overlap (e.g. from a reminder).
            heroTag: null,
            onPressed: onPressed,
            isExtended: _fabExtended,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: brutalShape(context),
            icon: Icon(icon),
            label: Text(label),
          ),
        );

    return switch (_index) {
      0 => ValueListenableBuilder<bool>(
        valueListenable: _importing,
        builder: (context, busy, _) => bold(
          Icons.add_rounded,
          'Add PDF',
          busy
              ? null
              : () =>
                    pickAndImport(context, onBusy: (b) => _importing.value = b),
        ),
      ),
      1 => bold(
        Icons.add_rounded,
        'Add course',
        () => showCourseEditor(context),
      ),
      3 => FloatingActionButton.extended(
        // No hero: tab changes and route pushes can overlap (e.g. from a reminder).
        heroTag: null,
        key: const ValueKey('New plan'),
        onPressed: () => startNewPlan(context),
        isExtended: _fabExtended,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('New plan'),
      ),
      _ => FloatingActionButton.extended(
        // No hero: tab changes and route pushes can overlap (e.g. from a reminder).
        heroTag: null,
        key: const ValueKey('Add event'),
        onPressed: () => showEventEditor(context, day: _calendarDay.value),
        isExtended: _fabExtended,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add event'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: [
              _TabSlot(
                active: _index == 0,
                child: LibraryTab(importing: _importing),
              ),
              _TabSlot(active: _index == 1, child: const CoursesTab()),
              _TabSlot(
                active: _index == 2,
                child: CalendarTab(selectedDay: _calendarDay),
              ),
              _TabSlot(active: _index == 3, child: const PlannerTab()),
            ],
          ),
        ),
        floatingActionButton: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium2),
          switchInCurve: Motion.emphasizedDecelerate,
          switchOutCurve: Motion.emphasizedAccelerate,
          transitionBuilder: (child, a) => ScaleTransition(
            scale: a,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: _fab(context),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Courses',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_rounded),
              label: 'Plan',
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab alive while hidden: fades it out, then stops painting it.
class _TabSlot extends StatefulWidget {
  const _TabSlot({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabSlot> createState() => _TabSlotState();
}

class _TabSlotState extends State<_TabSlot> {
  late bool _paint = widget.active;

  @override
  void didUpdateWidget(_TabSlot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_paint) _paint = true;
  }

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.medium2);
    return Positioned.fill(
      child: Offstage(
        offstage: !_paint,
        child: TickerMode(
          // Keep tickers running until the fade-out finishes, or it never ends.
          enabled: widget.active || _paint,
          child: ExcludeSemantics(
            excluding: !widget.active,
            child: IgnorePointer(
              ignoring: !widget.active,
              child: AnimatedOpacity(
                duration: duration,
                curve: Motion.standard,
                opacity: widget.active ? 1 : 0,
                onEnd: () {
                  if (!widget.active && _paint) setState(() => _paint = false);
                },
                child: AnimatedSlide(
                  duration: duration,
                  curve: Motion.emphasizedDecelerate,
                  offset: widget.active ? Offset.zero : const Offset(0, .02),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
