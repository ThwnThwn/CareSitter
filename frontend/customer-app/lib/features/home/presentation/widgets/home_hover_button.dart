import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pointer, keyboard and touch feedback without changing the child's layout.
class HomeHoverButton extends StatefulWidget {
  const HomeHoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<HomeHoverButton> createState() => _HomeHoverButtonState();
}

class _HomeHoverButtonState extends State<HomeHoverButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final active = enabled && (_hovered || _focused);
    final pressed = enabled && _pressed;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 160);

    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onFocusChange: (value) {
        if (!value) setState(() => _pressed = false);
      },
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          button: true,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: reduceMotion ? 1 : (pressed ? 0.98 : (active ? 1.015 : 1)),
              duration: duration,
              curve: Curves.easeOutQuart,
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutQuart,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    color: Colors.black.withValues(
                      alpha: pressed ? 0.09 : (active ? 0.045 : 0),
                    ),
                    border: Border.all(
                      color: enabled && _focused
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
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
