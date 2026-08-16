enum InteractionMode { call, command }

const InteractionMode defaultInteractionMode = InteractionMode.command;

/// Simple keyword heuristic that forces Command-level confirmation even in
/// Call mode for work-type instructions (approval, publish, delete, payment,
/// authorization, sudo, and close variants). Deliberately small, covers the
/// primary Chinese and English charge words, and can be enhanced later without
/// touching the voice state machine.
const List<String> sensitiveInstructionKeywords = <String>[
  '审批',
  '批准',
  '授权',
  '发布',
  '上线',
  '删除',
  '移除',
  '付款',
  '支付',
  '转账',
  'sudo',
  'approve',
  'approval',
  'authorize',
  'authorization',
  'authorisation',
  'publish',
  'delete',
  'remove',
  'erase',
  'pay',
  'payment',
  'transfer',
];

bool containsSensitiveInstruction(String text) {
  final normalized = text.toLowerCase();
  for (final keyword in sensitiveInstructionKeywords) {
    if (normalized.contains(keyword.toLowerCase())) return true;
  }
  return false;
}
