import 'package:flutter/material.dart';

/// Bell Ringing Animation
class RingingBell extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const RingingBell(
      {super.key,
      required this.child,
      this.delay = const Duration(milliseconds: 550)});

  @override
  State<RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<RingingBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _rotation = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.174), weight: 15), // -10 deg
      TweenSequenceItem(
          tween: Tween(begin: -0.174, end: 0.174), weight: 15), // 10 deg
      TweenSequenceItem(tween: Tween(begin: 0.174, end: -0.174), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.174, end: 0.174), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.174, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 25), // rest
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

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
      builder: (context, child) => Transform.rotate(
        angle: _rotation.value,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: widget.child,
    );
  }
}
