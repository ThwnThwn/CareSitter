import 'package:flutter/material.dart';

/// Count up text
class CountUpText extends StatefulWidget {
  final int target;
  final TextStyle? style;
  final Duration delay;
  final Duration duration;

  const CountUpText(
      {super.key,
      required this.target,
      this.style,
      this.delay = const Duration(milliseconds: 420),
      this.duration = const Duration(milliseconds: 700)});

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = IntTween(begin: 0, end: widget.target)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) =>
          Text(_anim.value.toString(), style: widget.style),
    );
  }
}
