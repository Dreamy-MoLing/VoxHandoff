import 'dart:convert';

import 'package:cryptography/cryptography.dart';

enum ChatSource { hermes, hermesConversation, directLlm }

sealed class ConfirmedTarget {
  const ConfirmedTarget({required this.conversationId});

  final String conversationId;

  ChatSource get source;

  bool matches(ConfirmedTarget other) => this == other;
}

class DirectTargetSnapshot extends ConfirmedTarget {
  const DirectTargetSnapshot({
    required super.conversationId,
    required this.providerProfileId,
    required this.credentialRevision,
    required this.configurationRevision,
    required this.normalizedOrigin,
    required this.model,
  });

  final String providerProfileId;
  final int credentialRevision;
  final int configurationRevision;
  final String normalizedOrigin;
  final String model;

  @override
  ChatSource get source => ChatSource.directLlm;

  @override
  bool operator ==(Object other) =>
      other is DirectTargetSnapshot &&
      conversationId == other.conversationId &&
      providerProfileId == other.providerProfileId &&
      credentialRevision == other.credentialRevision &&
      configurationRevision == other.configurationRevision &&
      normalizedOrigin == other.normalizedOrigin &&
      model == other.model;

  @override
  int get hashCode => Object.hash(
    conversationId,
    providerProfileId,
    credentialRevision,
    configurationRevision,
    normalizedOrigin,
    model,
  );
}

class HermesTargetSnapshot extends ConfirmedTarget {
  const HermesTargetSnapshot({
    required super.conversationId,
    required this.nodeId,
    required this.agentId,
    required this.capabilityRevision,
    this.sessionId,
  });

  final String nodeId;
  final String agentId;
  final String capabilityRevision;
  final String? sessionId;

  @override
  ChatSource get source => ChatSource.hermes;

  @override
  bool operator ==(Object other) =>
      other is HermesTargetSnapshot &&
      conversationId == other.conversationId &&
      nodeId == other.nodeId &&
      agentId == other.agentId &&
      capabilityRevision == other.capabilityRevision &&
      sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(
    conversationId,
    nodeId,
    agentId,
    capabilityRevision,
    sessionId,
  );
}

class HermesConversationTargetSnapshot extends ConfirmedTarget {
  const HermesConversationTargetSnapshot({
    required super.conversationId,
    required this.providerProfileId,
    required this.credentialRevision,
    required this.configurationRevision,
    required this.normalizedOrigin,
    required this.model,
    required this.sessionId,
    required this.sessionKey,
  });

  final String providerProfileId;
  final int credentialRevision;
  final int configurationRevision;
  final String normalizedOrigin;
  final String model;
  final String sessionId;
  final String sessionKey;

  @override
  ChatSource get source => ChatSource.hermesConversation;

  @override
  bool operator ==(Object other) =>
      other is HermesConversationTargetSnapshot &&
      conversationId == other.conversationId &&
      providerProfileId == other.providerProfileId &&
      credentialRevision == other.credentialRevision &&
      configurationRevision == other.configurationRevision &&
      normalizedOrigin == other.normalizedOrigin &&
      model == other.model &&
      sessionId == other.sessionId &&
      sessionKey == other.sessionKey;

  @override
  int get hashCode => Object.hash(
    conversationId,
    providerProfileId,
    credentialRevision,
    configurationRevision,
    normalizedOrigin,
    model,
    sessionId,
    sessionKey,
  );
}

/// The only object accepted by a send path.  Its text and target are frozen at
/// confirmation time; callers must not rebuild either from mutable UI state.
class ConfirmedDraft {
  ConfirmedDraft({
    required this.draftId,
    required this.draftRevision,
    required String confirmedText,
    required this.assistantId,
    required this.assistantRevision,
    required this.contextSnapshotRevision,
    required this.contextSnapshotHash,
    required this.target,
    DateTime? confirmedAt,
  }) : confirmedText = _normalizeText(confirmedText),
       textHash = sha256Hex(_normalizeText(confirmedText)),
       confirmedAt = (confirmedAt ?? DateTime.now()).toUtc() {
    if (draftId.trim().isEmpty ||
        draftRevision < 0 ||
        this.confirmedText.isEmpty ||
        assistantId.trim().isEmpty ||
        assistantRevision < 0 ||
        contextSnapshotRevision < 0 ||
        !_isSha256(contextSnapshotHash) ||
        target.conversationId.trim().isEmpty) {
      throw const FormatException('The confirmed draft is invalid.');
    }
  }

  final String draftId;
  final int draftRevision;
  final String confirmedText;
  final String textHash;
  final String assistantId;
  final int assistantRevision;
  final int contextSnapshotRevision;
  final String contextSnapshotHash;
  final ConfirmedTarget target;
  final DateTime confirmedAt;

  ChatSource get chatSource => target.source;

  static String contextHash(Iterable<String> canonicalParts) =>
      sha256Hex(canonicalParts.join('\u001f'));
}

String sha256Hex(String value) => Sha256()
    .toSync()
    .hashSync(utf8.encode(value))
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String _normalizeText(String text) => text.trim();

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
