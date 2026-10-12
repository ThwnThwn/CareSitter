import 'package:flutter/material.dart';

/// Drifting Circle
class DriftingCircle extends StatefulWidget {
  final double size;
  final Color color;

  const DriftingCircle({super.key, required this.size, required this.color});

  @override
  State<DriftingCircle> createState() => _DriftingCircleState();
}

class _DriftingCircleState extends State<DriftingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 9))
          ..repeat(reverse: true);
    _anim = Tween<Offset>(begin: Offset.zero, end: const Offset(-8, 10))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (context, child) => Transform.translate(
        offset: _anim.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      ),
    );
  }
}
