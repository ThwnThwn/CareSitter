export 'package:caresitter_customer/core/widgets/fade_slide_staggered_presentation_helpers.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered_presentation_helpers.dart';
import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────────
// List entry transition — content is visible without a stagger timer.
// ────────────────────────────────────────────────────────────────────────────────

class FadeSlideStaggered extends StatefulWidget {
  final Widget child;

  /// Items after the initial viewport skip entry animation.
  final int index;

  /// Hướng slide vào: dưới lên (mặc định) hoặc từ trên xuống (header)
  final bool slideFromTop;

  const FadeSlideStaggered({
    super.key,
    required this.child,
    required this.index,
    this.slideFromTop = false,
  });

  @override
  State<FadeSlideStaggered> createState() => _FadeSlideStaggeredState();
}

class _FadeSlideStaggeredState extends State<FadeSlideStaggered>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Keep text visible even on the first animation frame.
  late final Animation<double> _fade;

  /// Slide: 6% chiều cao widget từ dưới lên (hoặc trên xuống)
  late final Animation<Offset> _slide;

  /// Scale: 0.97 → 1.0 — micro-scale tạo cảm giác "bật" như Grab
  late final Animation<double> _scale;

  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: staggeredItemDuration);

    // Fade: nhanh ở đầu (80% đầu của animation)
    _fade = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.75, curve: staggeredSpring),
      ),
    );

    // Slide: 6% → 0 với spring curve
    final dy = widget.slideFromTop ? -0.06 : 0.06;
    _slide = Tween<Offset>(
      begin: Offset(0, dy),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: staggeredSpring));

    // Scale: nhỏ nhẹ → bình thường
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.85, curve: staggeredSpring),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Tôn trọng accessibility: không animate nếu user tắt animation
    if (widget.index >= 4 ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _ctrl.value = 1.0;
      _scheduled = true;
      return;
    }

    if (_scheduled) return;
    _scheduled = true;

    // Data is visible immediately; only the first screen gets a brief transition.
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
