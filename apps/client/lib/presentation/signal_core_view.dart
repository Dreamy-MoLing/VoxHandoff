import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/signal_core.dart';
import 'design/agent_talk_theme.dart';

enum SignalRenderProfile { static, balanced60, highRefresh120 }

SignalRenderProfile signalRenderProfileForRefreshRate(double refreshRate) =>
    refreshRate >= 100
    ? SignalRenderProfile.highRefresh120
    : SignalRenderProfile.balanced60;

typedef SignalShaderLoader = Future<ui.FragmentProgram> Function();

class SignalCoreView extends StatefulWidget {
  const SignalCoreView({
    required this.snapshot,
    required this.dimension,
    this.profile,
    this.shaderLoader,
    this.mobileVisual = false,
    super.key,
  });

  final SignalCoreSnapshot snapshot;
  final double dimension;
  final SignalRenderProfile? profile;
  final SignalShaderLoader? shaderLoader;
  final bool mobileVisual;

  @override
  State<SignalCoreView> createState() => _SignalCoreViewState();
}

class _SignalCoreViewState extends State<SignalCoreView>
    with TickerProviderStateMixin {
  late final AnimationController _animation;
  late final AnimationController _faultPulse;
  ui.FragmentProgram? _program;
  bool _shaderUnavailable = false;

  SignalRenderProfile get _profile =>
      widget.profile ??
      signalRenderProfileForRefreshRate(View.of(context).display.refreshRate);

  bool get _motionDisabled =>
      _profile == SignalRenderProfile.static ||
      MediaQuery.maybeDisableAnimationsOf(context) == true;

  bool get _stateAnimates => switch (widget.snapshot.state) {
    SignalCoreState.recording ||
    SignalCoreState.transcribing ||
    SignalCoreState.awaitingConfirmation ||
    SignalCoreState.submitting ||
    SignalCoreState.working ||
    SignalCoreState.speaking ||
    SignalCoreState.approval ||
    SignalCoreState.uncertain => true,
    SignalCoreState.idle when widget.mobileVisual => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _faultPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.snapshot.state == SignalCoreState.failed) {
      _faultPulse.forward();
    }
    if (!widget.mobileVisual) {
      _loadShader();
    }
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
    if (oldWidget.snapshot.state != widget.snapshot.state &&
        widget.snapshot.state == SignalCoreState.failed &&
        !_motionDisabled) {
      _faultPulse.forward(from: 0);
    }
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
    if (widget.mobileVisual) {
      final duration = widget.snapshot.state == SignalCoreState.recording
          ? const Duration(milliseconds: 2200)
          : const Duration(milliseconds: 3800);
      if (_animation.duration != duration) {
        _animation.duration = duration;
      }
    }
    if (_motionDisabled) {
      _animation.stop();
      _animation.value = 0;
      _faultPulse.stop();
      _faultPulse.value = 0;
    } else if (_stateAnimates && !_animation.isAnimating) {
      _animation.repeat();
    } else if (!_stateAnimates) {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _faultPulse.dispose();
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_animation, _faultPulse]),
                builder: (context, _) => CustomPaint(
                  painter: SignalCorePainter(
                    snapshot: widget.snapshot,
                    phase: staticMode ? 0 : _animation.value,
                    signal: tokens.signal,
                    signalStrong: tokens.signalStrong,
                    signalDeep: tokens.signalDeep,
                    signalWarm: tokens.signalWarm,
                    attention: tokens.attention,
                    danger: tokens.danger,
                    structureLine: tokens.structureLine,
                    structureLineStrong: tokens.structureLineStrong,
                    ink: tokens.ink,
                    shadow: tokens.shadow,
                    stateColor: stateColor,
                    program: _shaderUnavailable ? null : _program,
                    reducedMotion: staticMode,
                    mobileVisual: widget.mobileVisual,
                    faultPulse: math.sin(math.pi * _faultPulse.value),
                    detail: _profile == SignalRenderProfile.highRefresh120
                        ? 1
                        : 0.72,
                  ),
                ),
              ),
              if (!widget.mobileVisual)
                Positioned(
                  left: widget.dimension * 0.16,
                  right: widget.dimension * 0.16,
                  bottom: widget.dimension * 0.08,
                  child: ExcludeSemantics(
                    child: Text(
                      _displayLabel(widget.snapshot.state),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: stateColor.withValues(alpha: 0.92),
                        fontSize: math.max(9, widget.dimension * 0.05),
                        fontWeight: FontWeight.w800,
                        letterSpacing: widget.dimension * 0.006,
                      ),
                    ),
                  ),
                ),
            ],
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
    required this.signalStrong,
    required this.signalDeep,
    required this.signalWarm,
    required this.attention,
    required this.danger,
    required this.structureLine,
    required this.structureLineStrong,
    required this.ink,
    required this.shadow,
    required this.stateColor,
    required this.program,
    required this.reducedMotion,
    required this.mobileVisual,
    required this.faultPulse,
    required this.detail,
  });

  final SignalCoreSnapshot snapshot;
  final double phase;
  final Color signal;
  final Color signalStrong;
  final Color signalDeep;
  final Color signalWarm;
  final Color attention;
  final Color danger;
  final Color structureLine;
  final Color structureLineStrong;
  final Color ink;
  final Color shadow;
  final Color stateColor;
  final ui.FragmentProgram? program;
  final bool reducedMotion;
  final bool mobileVisual;
  final double faultPulse;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (mobileVisual) {
      _paintPrototypeCore(canvas, center, radius);
      return;
    }
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
        ..setFloat(10, detail)
        ..setFloat(11, faultPulse);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = shader
          ..isAntiAlias = true,
      );
    }

    final activity = math.max(snapshot.audioLevel, snapshot.playbackLevel);
    final energyRadius = radius * (0.76 + activity * 0.08);
    canvas.drawCircle(
      center,
      energyRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          energyRadius,
          [
            stateColor.withValues(
              alpha: snapshot.state == SignalCoreState.idle ? 0.035 : 0.12,
            ),
            stateColor.withValues(alpha: 0),
          ],
          const [0, 1],
        ),
    );

    final structure = Paint()
      ..color = structureLine.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final active = Paint()
      ..color = stateColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = snapshot.state == SignalCoreState.approval ? 2.8 : 2.1;
    final dimActive = Paint()
      ..color = stateColor.withValues(
        alpha: snapshot.state == SignalCoreState.idle ? 0.32 : 0.72,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, radius - 8, structure);
    canvas.drawCircle(
      center,
      radius * (snapshot.state == SignalCoreState.approval ? 0.68 : 0.75),
      structure,
    );
    final offsetAngle = reducedMotion ? 0.12 : phase * math.pi * 2;
    final segmentCount = snapshot.state == SignalCoreState.speaking ? 18 : 12;
    for (var index = 0; index < segmentCount; index += 1) {
      final angle = offsetAngle + index * math.pi * 2 / segmentCount;
      final gap =
          snapshot.state == SignalCoreState.uncertain &&
          (index == 2 || index == 3 || index == 8);
      if (gap) continue;
      final segmentBounds = Rect.fromCircle(
        center: center,
        radius: radius - (index.isEven ? 4 : 7),
      );
      canvas.drawArc(
        segmentBounds,
        angle,
        math.pi / segmentCount * (index.isEven ? 0.9 : 0.52),
        false,
        index.isEven ? active : structure,
      );
    }

    final expansion =
        (snapshot.state == SignalCoreState.recording ||
            snapshot.state == SignalCoreState.speaking)
        ? activity * radius * 0.1
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

    if (snapshot.state == SignalCoreState.transcribing ||
        snapshot.state == SignalCoreState.submitting) {
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
      final split = radius * (0.24 + faultPulse * 0.04);
      canvas.drawLine(
        Offset(center.dx - split, center.dy + split * 0.8),
        Offset(center.dx + split, center.dy - split),
        active,
      );
    }

    if (snapshot.state == SignalCoreState.recording ||
        snapshot.state == SignalCoreState.speaking) {
      final spokeCount = snapshot.state == SignalCoreState.recording ? 8 : 12;
      for (var index = 0; index < spokeCount; index += 1) {
        final angle = index * math.pi * 2 / spokeCount;
        final pulse = 0.08 + activity * (index.isEven ? 0.12 : 0.06);
        final inner = radius * 0.31;
        final outer = radius * (0.38 + pulse);
        canvas.drawLine(
          center + Offset(math.cos(angle), math.sin(angle)) * inner,
          center + Offset(math.cos(angle), math.sin(angle)) * outer,
          index.isEven ? active : dimActive,
        );
      }
    }

    if (snapshot.state == SignalCoreState.working) {
      for (var index = 0; index < 3; index += 1) {
        final angle = offsetAngle + index * math.pi * 2 / 3;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.42),
          radius * 0.025,
          Paint()..color = stateColor,
        );
      }
    }

    if (snapshot.state == SignalCoreState.approval) {
      final shield = Rect.fromCenter(
        center: center,
        width: radius * 0.92,
        height: radius * 0.92,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shield, Radius.circular(radius * 0.12)),
        active,
      );
    }

    final coreWidth = radius * (0.31 + activity * 0.08);
    final core = _corePath(center, coreWidth);
    canvas.drawPath(
      core,
      Paint()
        ..color = ink.withValues(alpha: 0.78)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(core, active);
    canvas.drawCircle(
      center,
      radius * (0.055 + activity * 0.025),
      Paint()..color = stateColor.withValues(alpha: 0.9),
    );
  }

  void _paintPrototypeCore(Canvas canvas, Offset center, double radius) {
    final activity = math.max(snapshot.audioLevel, snapshot.playbackLevel);
    final listening = snapshot.state == SignalCoreState.recording;
    final motion = reducedMotion ? 0.5 : phase;
    final pulse = math.sin(motion * math.pi * 2);
    final outerScale = reducedMotion ? 1.0 : 0.9975 + pulse * 0.0375;
    final innerScale = reducedMotion ? 1.0 : 1.005 + pulse * 0.055;
    final outerRotation = reducedMotion
        ? -17 * math.pi / 180
        : (-17 + (pulse + 1) * 8.5) * math.pi / 180;
    final innerRotation = reducedMotion
        ? 26 * math.pi / 180
        : (26 + (pulse + 1) * 13) * math.pi / 180;

    _paintBrokenHalo(
      canvas,
      center,
      radius * 0.84 * outerScale,
      outerRotation,
      signal.withValues(alpha: reducedMotion ? 0.82 : 0.82 + pulse * 0.09),
      outer: true,
    );
    _paintBrokenHalo(
      canvas,
      center,
      radius * 0.64 * innerScale,
      innerRotation,
      signalWarm.withValues(alpha: reducedMotion ? 0.72 : 0.72 + pulse * 0.14),
      outer: false,
    );

    final orbRadius = radius * 0.84;
    final glowColor = listening ? signalWarm : signal;
    canvas.drawCircle(
      center,
      orbRadius + radius * 0.04,
      Paint()
        ..color = glowColor.withValues(alpha: listening ? 0.26 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    if (listening) {
      canvas.drawCircle(
        center,
        orbRadius + radius * 0.08,
        Paint()
          ..color = signalWarm.withValues(alpha: 0.24 + activity * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52),
      );
      canvas.drawCircle(
        center,
        orbRadius + radius * 0.12,
        Paint()
          ..color = signalStrong.withValues(alpha: 0.12 + activity * 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
      );
    }

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: orbRadius)),
    );
    final beamPhase = reducedMotion ? 0.0 : pulse * 0.12;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(beamPhase);
    _paintBeam(
      canvas,
      Rect.fromCenter(
        center: Offset(-radius * 0.23, 0),
        width: radius * 0.17,
        height: radius * 2.25,
      ),
      Colors.white.withValues(alpha: 0.45),
      7,
      math.pi * 42 / 180,
    );
    _paintBeam(
      canvas,
      Rect.fromCenter(
        center: Offset(radius * 0.25, radius * 0.06),
        width: radius * 0.1,
        height: radius * 1.65,
      ),
      Colors.white.withValues(alpha: 0.36),
      7,
      -math.pi * 41 / 180,
    );
    _paintBeam(
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.2,
        height: radius * 0.12,
      ),
      Colors.white.withValues(alpha: 0.19),
      5,
      -math.pi * 18 / 180,
    );
    canvas.restore();

    final orbGradient = Paint()
      ..shader = ui.Gradient.radial(
        center - Offset(radius * 0.12, radius * 0.16),
        orbRadius * 1.55,
        [
          signalWarm.withValues(alpha: 0.88),
          signalStrong.withValues(alpha: 0.86),
          stateColor.withValues(alpha: 0.92),
          signalDeep.withValues(alpha: 0.98),
        ],
        const [0, 0.28, 0.68, 1],
      );
    canvas.drawCircle(center, orbRadius, orbGradient);
    canvas.drawCircle(
      center + Offset(0, radius * 0.035),
      orbRadius,
      Paint()
        ..color = shadow.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final orbHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(43 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 1.9,
        height: radius * 1.25,
      ),
      orbHighlight,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-29 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 1.72,
        height: radius * 1.08,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.04,
    );
    canvas.restore();
    canvas.drawCircle(
      center - Offset(radius * 0.13, radius * 0.17),
      orbRadius * 0.17,
      Paint()..color = Colors.white.withValues(alpha: 0.72),
    );
    canvas.restore();

    final glintCenter = center + Offset(-radius * 0.34, -radius * 0.47);
    canvas.drawCircle(
      glintCenter,
      radius * 0.13,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    if (listening) {
      _paintPrototypeWaveform(canvas, center, radius, activity);
    }
  }

  void _paintBrokenHalo(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Color color, {
    required bool outer,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35);
    final start = rotation + (outer ? -0.12 : 0.22);
    final firstSweep = outer ? 1.42 * math.pi : 0.92 * math.pi;
    final secondStart = start + (outer ? 1.78 : 1.32) * math.pi;
    final secondSweep = outer ? 0.92 * math.pi : 1.35 * math.pi;
    canvas.drawArc(rect, start, firstSweep, false, paint);
    canvas.drawArc(rect, secondStart, secondSweep, false, paint);

    final accent = Paint()
      ..color = color.withValues(alpha: color.a * 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * (outer ? 1.11 : 1.14)),
      start + math.pi * 0.3,
      outer ? 0.92 * math.pi : 1.12 * math.pi,
      false,
      accent,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * (outer ? 0.88 : 0.84)),
      secondStart - math.pi * 0.2,
      outer ? 0.72 * math.pi : 0.86 * math.pi,
      false,
      accent,
    );
  }

  void _paintBeam(
    Canvas canvas,
    Rect rect,
    Color color,
    double blur,
    double rotation,
  ) {
    canvas.save();
    canvas.rotate(rotation);
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.restore();
  }

  void _paintPrototypeWaveform(
    Canvas canvas,
    Offset center,
    double radius,
    double activity,
  ) {
    const shape = <double>[
      0.28,
      0.42,
      0.62,
      0.86,
      0.56,
      0.34,
      0.72,
      0.48,
      0.9,
      0.64,
      0.38,
      0.78,
      0.52,
      0.3,
      0.68,
      0.46,
      0.76,
      0.32,
    ];
    final barWidth = math.max(2.0, radius * 0.018);
    final gap = math.max(2.0, radius * 0.022);
    final totalWidth = shape.length * barWidth + (shape.length - 1) * gap;
    final startX = center.dx - totalWidth / 2;
    for (var index = 0; index < shape.length; index += 1) {
      final modulation = reducedMotion
          ? 1.0
          : 0.82 + 0.18 * math.sin(phase * math.pi * 2 + index * 0.7);
      final height =
          radius *
          (0.035 + shape[index] * (0.08 + activity * 0.32)) *
          modulation;
      final x = startX + index * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, center.dy - height / 2, barWidth, height),
          Radius.circular(barWidth),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  Path _corePath(Offset center, double width) {
    final points = switch (snapshot.state) {
      SignalCoreState.idle => <Offset>[
        const Offset(0, -1),
        const Offset(0.72, 0),
        const Offset(0, 1),
        const Offset(-0.72, 0),
      ],
      SignalCoreState.recording => <Offset>[
        const Offset(0, -1.22),
        const Offset(0.58, -0.36),
        const Offset(0.86, 0),
        const Offset(0.55, 0.42),
        const Offset(0, 1.22),
        const Offset(-0.55, 0.42),
        const Offset(-0.86, 0),
        const Offset(-0.58, -0.36),
      ],
      SignalCoreState.transcribing => _regularPoints(6, rotation: -math.pi / 2),
      SignalCoreState.awaitingConfirmation => <Offset>[
        const Offset(0, -1),
        const Offset(1, -0.22),
        const Offset(0.48, 0.82),
        const Offset(-0.48, 0.82),
        const Offset(-1, -0.22),
      ],
      SignalCoreState.submitting => <Offset>[
        const Offset(-0.9, -0.72),
        const Offset(1.08, 0),
        const Offset(-0.9, 0.72),
        const Offset(-0.48, 0),
      ],
      SignalCoreState.working => _regularPoints(7, rotation: -math.pi / 2),
      SignalCoreState.speaking => _starPoints(8, 1, 0.58),
      SignalCoreState.approval => <Offset>[
        const Offset(0, -1),
        const Offset(0.88, -0.5),
        const Offset(0.72, 0.62),
        const Offset(0, 1.08),
        const Offset(-0.72, 0.62),
        const Offset(-0.88, -0.5),
      ],
      SignalCoreState.completed => <Offset>[
        const Offset(0, -0.88),
        const Offset(0.95, -0.25),
        const Offset(0.35, 0.95),
        const Offset(-0.35, 0.95),
        const Offset(-0.95, -0.25),
      ],
      SignalCoreState.failed => <Offset>[
        const Offset(-0.9, -0.72),
        const Offset(-0.15, -0.92),
        const Offset(0.05, -0.18),
        const Offset(0.92, -0.55),
        const Offset(0.55, 0.92),
        const Offset(-0.72, 0.62),
      ],
      SignalCoreState.uncertain => <Offset>[
        const Offset(-0.75, -0.72),
        const Offset(0.28, -1),
        const Offset(0.92, -0.28),
        const Offset(0.46, 0.25),
        const Offset(0.72, 0.9),
        const Offset(-0.48, 0.72),
        const Offset(-0.92, 0),
      ],
    };
    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final point = center + points[index] * width;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  List<Offset> _regularPoints(int count, {double rotation = 0}) => [
    for (var index = 0; index < count; index += 1)
      Offset(
        math.cos(rotation + index * math.pi * 2 / count),
        math.sin(rotation + index * math.pi * 2 / count),
      ),
  ];

  List<Offset> _starPoints(int count, double outer, double inner) => [
    for (var index = 0; index < count * 2; index += 1)
      Offset(
        math.cos(-math.pi / 2 + index * math.pi / count) *
            (index.isEven ? outer : inner),
        math.sin(-math.pi / 2 + index * math.pi / count) *
            (index.isEven ? outer : inner),
      ),
  ];

  @override
  bool shouldRepaint(covariant SignalCorePainter oldDelegate) =>
      oldDelegate.snapshot.state != snapshot.state ||
      oldDelegate.snapshot.audioLevel != snapshot.audioLevel ||
      oldDelegate.snapshot.playbackLevel != snapshot.playbackLevel ||
      oldDelegate.snapshot.sourceIdentity != snapshot.sourceIdentity ||
      oldDelegate.phase != phase ||
      oldDelegate.signal != signal ||
      oldDelegate.signalStrong != signalStrong ||
      oldDelegate.signalDeep != signalDeep ||
      oldDelegate.signalWarm != signalWarm ||
      oldDelegate.attention != attention ||
      oldDelegate.danger != danger ||
      oldDelegate.structureLine != structureLine ||
      oldDelegate.structureLineStrong != structureLineStrong ||
      oldDelegate.ink != ink ||
      oldDelegate.shadow != shadow ||
      oldDelegate.stateColor != stateColor ||
      oldDelegate.program != program ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.mobileVisual != mobileVisual ||
      oldDelegate.faultPulse != faultPulse ||
      oldDelegate.detail != detail;
}

String _displayLabel(SignalCoreState state) => switch (state) {
  SignalCoreState.idle => 'HERMES READY',
  SignalCoreState.recording => 'LISTENING',
  SignalCoreState.transcribing => 'TRANSCRIBING',
  SignalCoreState.awaitingConfirmation => 'REVIEW',
  SignalCoreState.submitting => 'HANDOFF',
  SignalCoreState.working => 'HERMES ACTIVE',
  SignalCoreState.speaking => 'VOICE',
  SignalCoreState.approval => 'DECISION',
  SignalCoreState.completed => 'COMPLETE',
  SignalCoreState.failed => 'FAULT',
  SignalCoreState.uncertain => 'VERIFY',
};
