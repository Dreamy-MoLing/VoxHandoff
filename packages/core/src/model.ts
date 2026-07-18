export const agentEventTypes = [
  "connection.ready",
  "connection.lost",
  "request.accepted",
  "agent.working",
  "message.delta",
  "message.completed",
  "tool.started",
  "tool.completed",
  "approval.required",
  "clarification.required",
  "request.completed",
  "request.failed",
  "request.cancelled",
] as const;

export type AgentEventType = (typeof agentEventTypes)[number];

export interface AgentEvent<T = unknown> {
  connectionId: string;
  sessionId?: string;
  requestId?: string;
  sequence: number;
  serverTime: string;
  type: AgentEventType;
  payload: T;
  final: boolean;
}

export interface AgentCapabilities {
  protocolVersion?: string;
  serverVersion?: string;
  streamingText: boolean;
  eventStream: boolean;
  sessionHistory: boolean;
  createSession: boolean;
  resumeSession: boolean;
  cancel: boolean;
  steer: boolean;
  clarification: boolean;
  approval: boolean;
  toolProgress: boolean;
  fileMessages: boolean;
  idempotencyKey: boolean;
  eventReplay: boolean;
  maxRequestBytes?: number;
  requestTimeoutMs?: number;
}

export type FailureStage =
  | "recording"
  | "stt"
  | "agent"
  | "summary"
  | "tts"
  | "playback"
  | "storage"
  | "configuration";

export interface StageFailure {
  stage: FailureStage;
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
  "completed",
  "cancelled",
  "failed",
  "uncertain",
] as const;

export type SessionState = (typeof sessionStates)[number];

export interface VoiceSessionSnapshot {
  state: SessionState;
  generation: number;
  connectionId?: string;
  sessionId?: string;
  requestId?: string;
  lastSequence: number;
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
      connectionId: string;
      sessionId?: string;
      requestId: string;
    }
  | { type: "agent.event"; event: AgentEvent }
  | { type: "summary.ready"; speechText: string }
  | { type: "summary.failed"; failure: StageFailure }
  | { type: "tts.ready" }
  | { type: "tts.failed"; failure: StageFailure }
  | { type: "playback.completed" }
  | { type: "cancel" }
  | { type: "reset" };

export interface IgnoredEvent {
  reason:
    | "wrong_connection"
    | "wrong_session"
    | "wrong_request"
    | "stale_sequence"
    | "terminal_state";
  event: AgentEvent;
}

export interface TransitionResult {
  snapshot: VoiceSessionSnapshot;
  ignored?: IgnoredEvent;
}
