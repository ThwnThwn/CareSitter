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
