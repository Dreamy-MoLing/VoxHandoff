export interface DirectoryNodeRecord {
  nodeId: string;
  displayName: string;
  platform: string;
  version: string;
}

export interface DirectoryAgentRecord {
  agentId: string;
  nodeId: string;
  displayName: string;
  adapter: string;
  version: string;
  capabilityRevision: string;
  capabilities: unknown;
}

export interface DirectoryConversationRecord {
  conversationId: string;
  title: string;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  sessionId: string | null;
  revision: bigint;
  lastSequence: bigint;
}

export interface GatewayDirectoryRecord {
  nodes: readonly DirectoryNodeRecord[];
  agents: readonly DirectoryAgentRecord[];
  conversations: readonly DirectoryConversationRecord[];
}

export interface CreateConversationInput {
  conversationId: string;
  commandId: string;
  idempotencyKey: string;
  deviceId: string;
  title: string;
  nodeId: string;
  agentId: string;
  capabilityRevision: string;
  sessionId: string | null;
  now: Date;
}

export type DirectoryLedgerErrorCode =
  | "conversation_identity_conflict"
  | "command_id_conflict"
  | "idempotency_conflict"
  | "agent_not_found"
  | "capability_revision_changed";

export class DirectoryLedgerError extends Error {
  constructor(readonly code: DirectoryLedgerErrorCode, message: string) {
    super(message);
    this.name = "DirectoryLedgerError";
  }
}

export interface DirectoryLedger {
  listDirectory(): Promise<GatewayDirectoryRecord>;
  createConversation(input: CreateConversationInput): Promise<DirectoryConversationRecord>;
}
