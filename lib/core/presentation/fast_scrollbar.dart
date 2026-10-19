import 'package:flutter/material.dart';

/// Large draggable thumb for jumping through long lists. Shows while
/// scrolling and fades out when idle.
class FastScrollbar extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const FastScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RawScrollbar(
      controller: controller,
      interactive: true,
      thickness: 10,
      radius: const Radius.circular(5),
      minThumbLength: 72,
      crossAxisMargin: 4,
      mainAxisMargin: 8,
      thumbColor: scheme.primary.withValues(alpha: 0.85),
      fadeDuration: const Duration(milliseconds: 300),
      timeToFade: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}
