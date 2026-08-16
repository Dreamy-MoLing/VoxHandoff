part of 'pairing_dialog.dart';

class _PairingHeader extends StatelessWidget {
  const _PairingHeader({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, color: context.visualTokens.signal),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'GATEWAY 配对 / 手动连接',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.4),
            ),
          ),
          Text(
            _pairingPhaseLabel(phase),
            style: TextStyle(
              color: context.visualTokens.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            tooltip: '关闭配对面板',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _PairingProgressRail extends StatelessWidget {
  const _PairingProgressRail({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final activeStep = switch (phase) {
      PairingPhase.idle || PairingPhase.beginning => 0,
      PairingPhase.awaitingOwnerApproval || PairingPhase.completing => 1,
      PairingPhase.awaitingConfirmation || PairingPhase.confirming => 2,
      PairingPhase.paired => 3,
      PairingPhase.failed || PairingPhase.uncertain => -1,
    };
    return Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 24),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(right: BorderSide(color: tokens.structureLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连接流程',
            style: TextStyle(color: tokens.signal, letterSpacing: 1.8),
          ),
          const SizedBox(height: 24),
          for (final step in const [
            ('01', '建立'),
            ('02', '验证'),
            ('03', '证明'),
            ('04', '已封存'),
          ]) ...[
            _RailStep(
              number: step.$1,
              label: step.$2,
              active: int.parse(step.$1) - 1 == activeStep,
              complete: int.parse(step.$1) - 1 < activeStep,
            ),
            if (step.$1 != '04')
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.only(left: 9),
                color: tokens.structureLine,
              ),
          ],
          const Spacer(),
          Text(
            '不自动批准\n不静默重试',
            style: TextStyle(
              color: tokens.attention,
              fontSize: 10,
              height: 1.5,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailStep extends StatelessWidget {
  const _RailStep({
    required this.number,
    required this.label,
    required this.active,
    required this.complete,
  });

  final String number;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final color = active || complete ? tokens.signal : tokens.textMuted;
    return Row(
      children: [
        Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: complete ? tokens.signal : Colors.transparent,
            border: Border.all(color: color),
          ),
          child: complete
              ? Icon(Icons.check, size: 13, color: tokens.ink)
              : Text(number, style: TextStyle(color: color, fontSize: 9)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: active ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseTitle extends StatelessWidget {
  const _PhaseTitle({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: context.visualTokens.signal,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(color: context.visualTokens.textMuted, height: 1.45),
        ),
      ],
    );
  }
}

class _BusyPairingPhase extends StatelessWidget {
  const _BusyPairingPhase({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      PairingPhase.beginning => '正在准备本地设备密钥',
      PairingPhase.completing => '正在验证所有者决定',
      PairingPhase.confirming => '正在读取凭据',
      _ => '处理中',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhaseTitle(
          eyebrow: '连接 / 进行中',
          title: label,
          body: '这是一次有界请求。响应丢失时会停在未决状态。',
        ),
        const SizedBox(height: 28),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _UserCode extends StatelessWidget {
  const _UserCode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(left: BorderSide(color: tokens.attention, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '一次性代码',
            style: TextStyle(color: tokens.textMuted, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

String _pairingPhaseLabel(PairingPhase phase) => switch (phase) {
  PairingPhase.idle => '待开始',
  PairingPhase.beginning => '建立中',
  PairingPhase.awaitingOwnerApproval => '等待所有者审批',
  PairingPhase.completing => '完成中',
  PairingPhase.awaitingConfirmation => '等待确认',
  PairingPhase.confirming => '确认中',
  PairingPhase.paired => '已配对',
  PairingPhase.failed => '失败',
  PairingPhase.uncertain => '未决',
};

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.visualTokens.textMuted,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          context.visualTokens.panel,
        ),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
