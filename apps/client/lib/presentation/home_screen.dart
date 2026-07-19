import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_session_controller.dart';
import '../domain/client_session.dart';
import 'design/agent_talk_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _composer;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _confirmDraft() {
    ref.read(clientSessionProvider.notifier).confirmDraft();
    final confirmedText = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: confirmedText,
      selection: TextSelection.collapsed(offset: confirmedText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final controller = ref.read(clientSessionProvider.notifier);
    final compactAppBar = MediaQuery.sizeOf(context).width < 480;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: 'Agent Talk',
          child: const Text(
            'AGENT / TALK',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2.2),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: compactAppBar
                ? _ConnectionStatusIcon(phase: session.connectionPhase)
                : _ConnectionChip(phase: session.connectionPhase),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showNavigation = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (showNavigation) const _NavigationPane(),
              Expanded(
                child: Column(
                  children: [
                    const _LocalOnlyBanner(),
                    const Expanded(child: _EmptyConversation()),
                    _Composer(
                      textController: _composer,
                      session: session,
                      onChanged: controller.editDraft,
                      onConfirm: _confirmDraft,
                      onReopen: controller.reopenDraft,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionStatusIcon extends StatelessWidget {
  const _ConnectionStatusIcon({required this.phase});

  final GatewayConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final connected = phase == GatewayConnectionPhase.connected;
    final tokens = context.visualTokens;
    return Tooltip(
      message: connected ? 'Connected' : 'Not connected',
      child: Icon(
        connected ? Icons.verified_user_outlined : Icons.link_off,
        color: connected ? tokens.signal : tokens.textMuted,
        semanticLabel: connected ? 'Connected' : 'Not connected',
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.phase});

  final GatewayConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final label = switch (phase) {
      GatewayConnectionPhase.unpaired => 'Not paired',
      GatewayConnectionPhase.connecting => 'Connecting',
      GatewayConnectionPhase.connected => 'Connected',
      GatewayConnectionPhase.reconnecting => 'Reconnecting',
      GatewayConnectionPhase.offline => 'Offline',
      GatewayConnectionPhase.failed => 'Connection failed',
    };
    return Chip(
      avatar: Icon(
        phase == GatewayConnectionPhase.connected
            ? Icons.verified_user_outlined
            : Icons.link_off,
        size: 18,
        color: phase == GatewayConnectionPhase.connected
            ? tokens.signal
            : tokens.textMuted,
      ),
      label: Text(label),
    );
  }
}

class _NavigationPane extends StatelessWidget {
  const _NavigationPane();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AGENTS',
                style: TextStyle(
                  color: context.visualTokens.signal,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text('No Agent available'),
              const SizedBox(height: 28),
              Text(
                'CONVERSATIONS',
                style: TextStyle(
                  color: context.visualTokens.signal,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text('No conversation selected'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalOnlyBanner extends StatelessWidget {
  const _LocalOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return ColoredBox(
      color: Color.alphaBlend(
        tokens.attention.withValues(alpha: 0.08),
        tokens.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final message = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: tokens.attention),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Not paired. Draft text stays on this device and cannot be sent.',
                  ),
                ),
              ],
            );
            const pairButton = FilledButton(
              onPressed: null,
              child: Text('Pair Gateway'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: pairButton,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: message),
                const SizedBox(width: 16),
                const FilledButton(
                  onPressed: null,
                  child: Text('Pair Gateway'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LOCAL RELAY  /  STANDBY',
              style: TextStyle(
                color: tokens.signal,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
            const SizedBox(height: 20),
            const _StaticSignalLens(),
            const SizedBox(height: 24),
            const Text(
              'Pair a Gateway, then choose an Agent and conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Agent replies will remain complete text. Speech and visuals are optional views.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticSignalLens extends StatelessWidget {
  const _StaticSignalLens();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Semantics(
      label: 'Agent Talk idle status',
      child: SizedBox.square(
        dimension: 124,
        child: CustomPaint(
          painter: _SignalLensPainter(
            signal: tokens.signal,
            structureLine: tokens.structureLine,
            ink: tokens.ink,
          ),
        ),
      ),
    );
  }
}

class _SignalLensPainter extends CustomPainter {
  const _SignalLensPainter({
    required this.signal,
    required this.structureLine,
    required this.ink,
  });

  final Color signal;
  final Color structureLine;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final structure = Paint()
      ..color = structureLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final active = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 10, structure);
    canvas.drawCircle(center, radius - 25, structure);
    for (var index = 0; index < 12; index += 1) {
      final angle = index * math.pi / 6;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 7),
        center.dy + math.sin(angle) * (radius - 7),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - (index.isEven ? 0 : 3)),
        center.dy + math.sin(angle) * (radius - (index.isEven ? 0 : 3)),
      );
      canvas.drawLine(inner, outer, index.isEven ? active : structure);
    }

    final arcBounds = Rect.fromCircle(center: center, radius: radius - 16);
    canvas.drawArc(arcBounds, -0.18 * math.pi, 0.52 * math.pi, false, active);
    canvas.drawArc(arcBounds, 0.82 * math.pi, 0.38 * math.pi, false, active);

    final core = Path()
      ..moveTo(center.dx, center.dy - 14)
      ..lineTo(center.dx + 18, center.dy)
      ..lineTo(center.dx, center.dy + 14)
      ..lineTo(center.dx - 18, center.dy)
      ..close();
    canvas.drawPath(core, Paint()..color = ink);
    canvas.drawPath(core, active);
    canvas.drawLine(
      Offset(center.dx - 28, center.dy),
      Offset(center.dx - 10, center.dy),
      active,
    );
    canvas.drawLine(
      Offset(center.dx + 10, center.dy),
      Offset(center.dx + 28, center.dy),
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _SignalLensPainter oldDelegate) =>
      oldDelegate.signal != signal ||
      oldDelegate.structureLine != structureLine ||
      oldDelegate.ink != ink;
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.textController,
    required this.session,
    required this.onChanged,
    required this.onConfirm,
    required this.onReopen,
  });

  final TextEditingController textController;
  final ClientSessionState session;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final confirmed = session.draftPhase == DraftPhase.confirmed;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final editor = TextField(
                controller: textController,
                enabled: session.canEditDraft && !confirmed,
                minLines: 1,
                maxLines: 6,
                onChanged: onChanged,
                decoration: InputDecoration(
                  labelText: confirmed ? 'Confirmed locally' : 'Editable draft',
                  hintText: 'Type text to review before sending',
                ),
              );
              final primaryAction = confirmed
                  ? OutlinedButton(
                      onPressed: onReopen,
                      child: const Text('Edit'),
                    )
                  : FilledButton(
                      onPressed: session.canConfirmDraft ? onConfirm : null,
                      child: const Text('Confirm'),
                    );
              const sendAction = FilledButton.tonal(
                onPressed: null,
                child: Text('Send unavailable'),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    editor,
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [primaryAction, sendAction],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: editor),
                  const SizedBox(width: 12),
                  primaryAction,
                  const SizedBox(width: 8),
                  sendAction,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
