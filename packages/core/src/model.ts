export const agentEventTypes = [
  "connection.ready",
  "connection.lost",
  "request.accepted",
  "agent.working",
  "request.interrupting",
  "message.delta",
  "message.completed",
  "tool.started",
  "tool.completed",
  "tool.failed",
  "approval.required",
  "approval.resolved",
  "approval.expired",
  "approval.cancelled",
  "clarification.required",
  "clarification.resolved",
  "clarification.expired",
  "clarification.cancelled",
  "request.completed",
  "request.failed",
  "request.cancelled",
  "request.interrupted",
] as const;

export type AgentEventType = (typeof agentEventTypes)[number];

export const terminalAgentEventTypes = [
  "request.completed",
  "request.failed",
  "request.cancelled",
  "request.interrupted",
] as const satisfies readonly AgentEventType[];

export type TerminalAgentEventType = (typeof terminalAgentEventTypes)[number];

const terminalAgentEventTypeSet = new Set<AgentEventType>(terminalAgentEventTypes);

export function isTerminalAgentEventType(type: AgentEventType): type is TerminalAgentEventType {
  return terminalAgentEventTypeSet.has(type);
}

export interface AgentEvent<T = unknown> {
  eventId: string;
  connectionId: string;
  conversationId?: string;
  sessionId?: string;
  requestId?: string;
  sequence: number;
  occurredAt: string;
  type: AgentEventType;
  payload: T;
}

export const deltaModes = ["none", "append_only", "revisable"] as const;

export type DeltaMode = (typeof deltaModes)[number];

export interface AgentCapabilities {
  protocolVersion?: string;
  serverVersion?: string;
  deltaMode: DeltaMode;
  eventStream: boolean;
  sessionHistory: boolean;
  createSession: boolean;
  resumeSession: boolean;
  interrupt: boolean;
  steer: boolean;
  clarification: boolean;
  approval: boolean;
  toolEvents: boolean;
  attachments: boolean;
  idempotency: boolean;
  replay: boolean;
  sequenceRecovery: boolean;
  maxRequestBytes?: number;
  requestTimeoutMs?: number;
}

export const failureStages = [
  "recording",
  "stt",
  "connection",
  "authentication",
  "authorization",
  "protocol",
  "agent",
  "summary",
  "tts",
  "playback",
  "storage",
  "sync",
  "configuration",
] as const;

export type FailureStage = (typeof failureStages)[number];

export const failureCategories = [
  "validation",
  "unavailable",
  "authentication",
  "authorization",
  "protocol",
  "timeout",
  "rate_limit",
  "upstream",
  "storage",
  "privacy",
  "unknown",
] as const;

export type FailureCategory = (typeof failureCategories)[number];

export interface StageFailure {
  stage: FailureStage;
  category: FailureCategory;
  code: string;
  message: string;
  retryable: boolean;
  cause?: unknown;
}

export const sessionStates = [
  "idle",
  "recording",
  "transcribing",
  "awaiting_confirmation",
  "sending",
  "agent_working",
  "awaiting_approval",
  "awaiting_clarification",
  "summarizing",
  "synthesizing",
  "playing",
  "interrupting",
  "interrupted",
  "completed",
  "cancelled",
  "failed",
  "uncertain",
] as const;

export type SessionState = (typeof sessionStates)[number];

export interface VoiceSessionSnapshot {
  state: SessionState;
  generation: number;
  conversationId?: string;
  connectionId?: string;
  sessionId?: string;
  requestId?: string;
  agentId?: string;
  nodeId?: string;
  capabilityRevision?: string;
  lastSequence: number;
  recentEventIds: readonly string[];
  transcript: string;
  fullReply: string;
  speechText: string;
  failure?: StageFailure;
}

export type SessionAction =
  | { type: "record.start" }
  | { type: "record.stop" }
  | { type: "transcription.succeeded"; transcript: string }
  | { type: "transcription.failed"; failure: StageFailure }
  | { type: "transcript.update"; transcript: string }
  | {
      type: "request.submit";
      conversationId: string;
      connectionId: string;
      sessionId?: string;
      requestId: string;
      agentId: string;
      nodeId: string;
      capabilityRevision: string;
    }
  | { type: "request.interrupt" }
  | { type: "speech.stop" }
  | { type: "agent.event"; event: AgentEvent }
  | { type: "summary.ready"; speechText: string }
  | { type: "summary.failed"; failure: StageFailure }
  | { type: "tts.ready" }
  | { type: "tts.failed"; failure: StageFailure }
  | { type: "playback.failed"; failure: StageFailure }
  | { type: "playback.completed" }
  | { type: "cancel" }
  | { type: "reset" };

export interface IgnoredEvent {
  reason:
    | "wrong_connection"
    | "wrong_conversation"
    | "wrong_session"
    | "wrong_request"
    | "duplicate_event"
    | "stale_sequence"
    | "sequence_gap"
    | "terminal_state";
  event: AgentEvent;
}

export interface TransitionResult {
  snapshot: VoiceSessionSnapshot;
  ignored?: IgnoredEvent;
}
