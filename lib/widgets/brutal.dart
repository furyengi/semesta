import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/brutal_theme.dart';
import '../theme/motion.dart';

/// Outline shape shared by every bordered surface.
RoundedRectangleBorder brutalShape(BuildContext context, [double radius = 16]) {
  final b = BrutalTheme.of(context);
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(color: b.border, width: b.borderWidth),
  );
}

/// Paints a hard offset shadow behind [child] and, while the pointer is down,
/// slides the child onto the shadow so the surface feels physically pressed.
///
/// [topInset] keeps the shadow clear of decorations (like a folder tab) that
/// stick out above the main body.
class BrutalShadow extends StatefulWidget {
  const BrutalShadow({
    super.key,
    required this.child,
    this.radius = 16,
    this.topInset = 0,
    this.offset,
    this.pressable = true,
  });

  final Widget child;
  final double radius;
  final double topInset;
  final Offset? offset;
  final bool pressable;

  @override
  State<BrutalShadow> createState() => _BrutalShadowState();
}

class _BrutalShadowState extends State<BrutalShadow> {
  bool _pressed = false;

  void _set(bool v) {
    if (!widget.pressable || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final brutal = BrutalTheme.of(context);
    final off = widget.offset ?? brutal.shadowOffset;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: off.dx,
            right: -off.dx,
            top: widget.topInset + off.dy,
            bottom: -off.dy,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: brutal.shadow,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            ),
          ),
          AnimatedContainer(
            duration: Motion.of(context, Motion.short2),
            curve: Motion.standard,
            transform: Matrix4.translationValues(
              _pressed ? off.dx : 0,
              _pressed ? off.dy : 0,
              0,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// An outlined, hard-shadowed surface with Material ink feedback.
class BrutalBox extends StatelessWidget {
  const BrutalBox({
    super.key,
    required this.child,
    this.color,
    this.radius = 16,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.offset,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Offset? offset;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null || onLongPress != null;
    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (interactive) {
      content = InkWell(onTap: onTap, onLongPress: onLongPress, child: content);
    }
    return BrutalShadow(
      radius: radius,
      offset: offset,
      pressable: interactive,
      child: Material(
        color: color ?? BrutalTheme.of(context).card,
        shape: brutalShape(context, radius),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// Square outlined icon button used in the home header and app bars.
class BrutalIconButton extends StatelessWidget {
  const BrutalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: BrutalBox(
            radius: 12,
            color: color,
            onTap: onPressed,
            offset: const Offset(3, 4),
            child: Center(child: Icon(icon, size: 24)),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts [child] into place, staggered by [index], using the M3
/// emphasized-decelerate curve. Plays once when first inserted.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.medium4,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .7, curve: Motion.standard),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, .14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Motion.emphasizedDecelerate));
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 8));
      _timer = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
