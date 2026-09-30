import 'package:flutter/material.dart';

/// An interactive greeting wave that stays still for reduced-motion users.
class WavingHand extends StatefulWidget {
  const WavingHand({super.key});

  @override
  State<WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _scale;
  bool _started = false;
  bool _motionDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.42)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.42, end: -0.34)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.34, end: 0.28)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.28, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 36),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 46),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionDisabled = MediaQuery.of(context).disableAnimations;
    if (_motionDisabled) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_motionDisabled) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _waveAgain() {
    if (_motionDisabled) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vẫy tay chào',
      onTap: _waveAgain,
      child: GestureDetector(
        onTap: _waveAgain,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _controller,
                child: const Text('👋', style: TextStyle(fontSize: 20)),
                builder: (context, child) => Transform.scale(
                  scale: _motionDisabled ? 1 : _scale.value,
                  child: Transform.rotate(
                    key: const ValueKey('home-greeting-wave'),
                    angle: _motionDisabled ? 0 : _rotation.value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Pulsing Badge Animation
class PulsingBadge extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const PulsingBadge(
      {super.key,
      required this.child,
      this.delay = const Duration(milliseconds: 550)});

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

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

/// Bouncing Card
class BouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncingCard({super.key, required this.child, this.onTap});

  @override
  State<BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<BouncingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
