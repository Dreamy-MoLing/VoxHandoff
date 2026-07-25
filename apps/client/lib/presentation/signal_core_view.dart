import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/signal_core.dart';
import 'design/agent_talk_theme.dart';

enum SignalRenderProfile { static, balanced60, highRefresh120 }

typedef SignalShaderLoader = Future<ui.FragmentProgram> Function();

class SignalCoreView extends StatefulWidget {
  const SignalCoreView({
    required this.snapshot,
    required this.dimension,
    this.profile = SignalRenderProfile.balanced60,
    this.shaderLoader,
    super.key,
  });

  final SignalCoreSnapshot snapshot;
  final double dimension;
  final SignalRenderProfile profile;
  final SignalShaderLoader? shaderLoader;

  @override
  State<SignalCoreView> createState() => _SignalCoreViewState();
}

class _SignalCoreViewState extends State<SignalCoreView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  ui.FragmentProgram? _program;
  bool _shaderUnavailable = false;

  bool get _motionDisabled =>
      widget.profile == SignalRenderProfile.static ||
      MediaQuery.maybeDisableAnimationsOf(context) == true;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _loadShader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant SignalCoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  Future<void> _loadShader() async {
    try {
      final loader =
          widget.shaderLoader ??
          () => ui.FragmentProgram.fromAsset('shaders/signal_core.frag');
      final program = await loader();
      if (!mounted) return;
      setState(() => _program = program);
    } on Object {
      if (!mounted) return;
      setState(() => _shaderUnavailable = true);
    }
  }

  void _syncAnimation() {
    if (_motionDisabled) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final staticMode = _motionDisabled;
    final stateColor = switch (widget.snapshot.state) {
      SignalCoreState.approval || SignalCoreState.uncertain => tokens.attention,
      SignalCoreState.failed => tokens.danger,
      _ => tokens.signal,
    };
    return Semantics(
      liveRegion: widget.snapshot.state != SignalCoreState.idle,
      label: widget.snapshot.label,
      value: widget.snapshot.state.name,
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          key: const ValueKey('signal-core-view'),
          dimension: widget.dimension,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => CustomPaint(
              painter: SignalCorePainter(
                snapshot: widget.snapshot,
                phase: staticMode ? 0 : _animation.value,
                signal: tokens.signal,
                attention: tokens.attention,
                danger: tokens.danger,
                structureLine: tokens.structureLine,
                ink: tokens.ink,
                stateColor: stateColor,
                program: _shaderUnavailable ? null : _program,
                reducedMotion: staticMode,
                detail: widget.profile == SignalRenderProfile.highRefresh120
                    ? 1
                    : 0.72,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class SignalCorePainter extends CustomPainter {
  const SignalCorePainter({
    required this.snapshot,
    required this.phase,
    required this.signal,
    required this.attention,
    required this.danger,
    required this.structureLine,
    required this.ink,
    required this.stateColor,
    required this.program,
    required this.reducedMotion,
    required this.detail,
  });

  final SignalCoreSnapshot snapshot;
  final double phase;
  final Color signal;
  final Color attention;
  final Color danger;
  final Color structureLine;
  final Color ink;
  final Color stateColor;
  final ui.FragmentProgram? program;
  final bool reducedMotion;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final shaderProgram = program;
    if (shaderProgram != null) {
      final shader = shaderProgram.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, phase)
        ..setFloat(3, snapshot.state.index.toDouble())
        ..setFloat(4, snapshot.audioLevel)
        ..setFloat(5, snapshot.playbackLevel)
        ..setFloat(6, stateColor.r)
        ..setFloat(7, stateColor.g)
        ..setFloat(8, stateColor.b)
        ..setFloat(9, reducedMotion ? 1 : 0)
        ..setFloat(10, detail);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = shader
          ..isAntiAlias = true,
      );
    }

    final structure = Paint()
      ..color = structureLine.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final active = Paint()
      ..color = stateColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = snapshot.state == SignalCoreState.approval ? 2.6 : 2;
    final dimActive = Paint()
      ..color = stateColor.withValues(
        alpha: snapshot.state == SignalCoreState.idle ? 0.32 : 0.72,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, radius - 10, structure);
    canvas.drawCircle(center, radius - 25, structure);
    final offsetAngle = reducedMotion ? 0.12 : phase * math.pi * 2;
    for (var index = 0; index < 12; index += 1) {
      final angle = offsetAngle + index * math.pi / 6;
      final innerRadius = radius - (index.isEven ? 8 : 11);
      final outerRadius = radius - (index.isEven ? 0 : 4);
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        ),
        index.isEven ? active : structure,
      );
    }

    final expansion = snapshot.state == SignalCoreState.recording
        ? snapshot.audioLevel * radius * 0.08
        : 0.0;
    final arcBounds = Rect.fromCircle(
      center: center,
      radius: radius - 17 + expansion,
    );
    final arcShift = reducedMotion ? 0 : phase * math.pi * 0.35;
    canvas.drawArc(
      arcBounds,
      -0.2 * math.pi + arcShift,
      0.48 * math.pi,
      false,
      active,
    );
    canvas.drawArc(
      arcBounds,
      0.82 * math.pi - arcShift,
      0.34 * math.pi,
      false,
      dimActive,
    );

    if (snapshot.state == SignalCoreState.transcribing) {
      final y = reducedMotion
          ? center.dy
          : center.dy - radius * 0.45 + phase * radius * 0.9;
      canvas.drawLine(
        Offset(center.dx - radius * 0.55, y),
        Offset(center.dx + radius * 0.55, y),
        dimActive,
      );
    }
    if (snapshot.state == SignalCoreState.uncertain) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 35),
        0.18 * math.pi,
        0.68 * math.pi,
        false,
        active,
      );
    }
    if (snapshot.state == SignalCoreState.failed) {
      canvas.drawLine(
        Offset(center.dx - radius * 0.3, center.dy + radius * 0.2),
        Offset(center.dx + radius * 0.32, center.dy - radius * 0.24),
        active,
      );
    }

    final coreOffset = Offset(radius * 0.07, -radius * 0.04);
    final coreCenter = center + coreOffset;
    final coreWidth =
        radius *
        (0.25 + (snapshot.audioLevel * 0.08) + (snapshot.playbackLevel * 0.04));
    final core = Path()
      ..moveTo(coreCenter.dx - coreWidth, coreCenter.dy)
      ..lineTo(coreCenter.dx + coreWidth * 0.3, coreCenter.dy - coreWidth * 0.7)
      ..lineTo(coreCenter.dx + coreWidth, coreCenter.dy + coreWidth * 0.05)
      ..lineTo(
        coreCenter.dx - coreWidth * 0.1,
        coreCenter.dy + coreWidth * 0.62,
      )
      ..close();
    canvas.drawPath(core, Paint()..color = ink.withValues(alpha: 0.88));
    canvas.drawPath(core, active);

    final axisEnd = switch (snapshot.state) {
      SignalCoreState.approval => Offset(center.dx, center.dy + radius * 0.48),
      SignalCoreState.recording || SignalCoreState.transcribing => Offset(
        center.dx - radius * 0.35,
        center.dy + radius * 0.35,
      ),
      _ => Offset(center.dx + radius * 0.48, center.dy - radius * 0.18),
    };
    canvas.drawLine(coreCenter, axisEnd, dimActive);
  }

  @override
  bool shouldRepaint(covariant SignalCorePainter oldDelegate) =>
      oldDelegate.snapshot.state != snapshot.state ||
      oldDelegate.snapshot.audioLevel != snapshot.audioLevel ||
      oldDelegate.snapshot.playbackLevel != snapshot.playbackLevel ||
      oldDelegate.snapshot.sourceIdentity != snapshot.sourceIdentity ||
      oldDelegate.phase != phase ||
      oldDelegate.signal != signal ||
      oldDelegate.attention != attention ||
      oldDelegate.danger != danger ||
      oldDelegate.structureLine != structureLine ||
      oldDelegate.ink != ink ||
      oldDelegate.stateColor != stateColor ||
      oldDelegate.program != program ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.detail != detail;
}
