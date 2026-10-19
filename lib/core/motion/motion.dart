import 'package:flutter/material.dart';

/// Shared timing, so the whole app moves at one pace
abstract final class Motion {
  static const quick = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);

  /// Fast start, gentle stop: things arriving
  static const enter = Curves.easeOutCubic;

  /// Slight overshoot, like a spring settling
  static const settle = Curves.easeOutBack;
}

/// Shrinks a little while pressed and springs back on release, so every tap
/// gets an immediate physical response
class Pressable extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const Pressable({super.key, required this.child, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Listener(
    // A Listener doesn't compete with the child's own tap handling
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: _pressed ? Motion.quick : Motion.medium,
      curve: _pressed ? Curves.easeOut : Motion.settle,
      child: widget.child,
    ),
  );
}

/// Fades and rises into place after [delay]; used to stagger list items
class Entrance extends StatefulWidget {
  final Widget child;
  final Duration delay;

  /// False shows the child in place right away (e.g. rows scrolled into view)
  final bool animate;

  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
    value: widget.animate ? 0 : 1,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  void _start() {
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Stagger for the item at [index]; only the first screenful animates
Duration staggerDelay(int index) =>
    Duration(milliseconds: 25 * index.clamp(0, 12));

/// Like IndexedStack (keeps every child's state) but the shown child fades
/// in with a slight zoom: Material's "fade through"
class FadeThroughStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeThroughStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed)
        // Same wrapper types for every child, so switching keeps their state
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index ? _curve : kAlwaysCompleteAnimation,
              child: ScaleTransition(
                scale: i == widget.index
                    ? Tween(begin: 0.97, end: 1.0).animate(_curve)
                    : kAlwaysCompleteAnimation,
                child: child,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Page transition for the whole app: the new page slides in a short way
/// while fading, the old one drifts back (a shared X axis)
class SharedAxisTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const SharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: Motion.enter,
      reverseCurve: Motion.enter.flipped,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.enter,
      reverseCurve: Motion.enter.flipped,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.08, 0),
      ).animate(outgoing),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.25, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: FadeTransition(opacity: incoming, child: child),
      ),
    );
  }
}
