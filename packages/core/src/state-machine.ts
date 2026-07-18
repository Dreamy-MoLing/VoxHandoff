import type {
  AgentEvent,
  SessionAction,
  TransitionResult,
  VoiceSessionSnapshot,
} from "./model.js";

const requestFinishedStates = new Set([
  "summarizing",
  "synthesizing",
  "playing",
  "completed",
  "cancelled",
  "failed",
  "interrupted",
] as const);
const recentEventLimit = 128;

export function initialVoiceSession(): VoiceSessionSnapshot {
  return {
    state: "idle",
    generation: 0,
    lastSequence: 0,
    recentEventIds: [],
    transcript: "",
    fullReply: "",
    speechText: "",
  };
}

function fail(
  previous: VoiceSessionSnapshot,
  action: Extract<
    SessionAction,
    { type: "transcription.failed" | "summary.failed" | "tts.failed" | "playback.failed" }
  >,
): VoiceSessionSnapshot {
  if (
    action.type === "summary.failed" ||
    action.type === "tts.failed" ||
    action.type === "playback.failed"
  ) {
    return {
      ...previous,
      state: "completed",
      failure: action.failure,
    };
  }

  return { ...previous, state: "failed", failure: action.failure };
}

function ignored(
  snapshot: VoiceSessionSnapshot,
  event: AgentEvent,
  reason: NonNullable<TransitionResult["ignored"]>["reason"],
): TransitionResult {
  return { snapshot, ignored: { reason, event } };
}

function applyAgentEvent(
  previous: VoiceSessionSnapshot,
  event: AgentEvent,
): TransitionResult {
  if (
    requestFinishedStates.has(
      previous.state as
        | "summarizing"
        | "synthesizing"
        | "playing"
        | "completed"
        | "cancelled"
        | "failed"
        | "interrupted",
    )
  ) {
    return ignored(previous, event, "terminal_state");
  }
  if (event.connectionId !== previous.connectionId) {
    return ignored(previous, event, "wrong_connection");
  }
  if (
    previous.conversationId !== undefined &&
    event.conversationId !== undefined &&
    event.conversationId !== previous.conversationId
  ) {
    return ignored(previous, event, "wrong_conversation");
  }
  if (
    previous.sessionId !== undefined &&
    event.sessionId !== undefined &&
    event.sessionId !== previous.sessionId
  ) {
    return ignored(previous, event, "wrong_session");
  }
  if (event.requestId !== undefined && event.requestId !== previous.requestId) {
    return ignored(previous, event, "wrong_request");
  }
  if (previous.recentEventIds.includes(event.eventId)) {
    return ignored(previous, event, "duplicate_event");
  }
  if (event.sequence <= previous.lastSequence) {
    return ignored(previous, event, "stale_sequence");
  }
  if (event.sequence !== previous.lastSequence + 1) {
    return ignored(previous, event, "sequence_gap");
  }

  const next = {
    ...previous,
    lastSequence: event.sequence,
    recentEventIds: [...previous.recentEventIds, event.eventId].slice(-recentEventLimit),
  };
  switch (event.type) {
    case "request.accepted":
      return { snapshot: { ...next, state: "agent_working" } };
    case "agent.working":
    case "tool.started":
    case "tool.completed":
    case "tool.failed":
      return { snapshot: { ...next, state: "agent_working" } };
    case "request.interrupting":
      return { snapshot: { ...next, state: "interrupting" } };
    case "message.delta": {
      const delta = readText(event.payload, "delta");
      return {
        snapshot: {
          ...next,
          state: "agent_working",
          fullReply: next.fullReply + delta,
        },
      };
    }
    case "message.completed": {
      const text = readText(event.payload, "text");
      return {
        snapshot: {
          ...next,
          state: "agent_working",
          fullReply: text || next.fullReply,
        },
      };
    }
    case "approval.required":
      return { snapshot: { ...next, state: "awaiting_approval" } };
    case "approval.resolved":
    case "approval.expired":
    case "approval.cancelled":
      return { snapshot: { ...next, state: "agent_working" } };
    case "clarification.required":
      return { snapshot: { ...next, state: "awaiting_clarification" } };
    case "clarification.resolved":
    case "clarification.expired":
    case "clarification.cancelled":
      return { snapshot: { ...next, state: "agent_working" } };
    case "request.completed":
      return { snapshot: { ...next, state: "summarizing" } };
    case "request.cancelled":
      return { snapshot: { ...next, state: "cancelled" } };
    case "request.interrupted":
      return { snapshot: { ...next, state: "interrupted" } };
    case "request.failed":
      return {
        snapshot: {
          ...next,
          state: "failed",
          failure: {
            stage: "agent",
            category: "upstream",
            code: readText(event.payload, "code") || "agent_failed",
            message: readText(event.payload, "message") || "Agent request failed",
            retryable: false,
          },
        },
      };
    case "connection.lost":
      return { snapshot: { ...next, state: "uncertain" } };
    case "connection.ready":
      return { snapshot: next };
  }
}

function readText(payload: unknown, key: string): string {
  if (typeof payload === "string") return payload;
  if (payload === null || typeof payload !== "object") return "";
  const value = (payload as Record<string, unknown>)[key];
  return typeof value === "string" ? value : "";
}

export function transition(
  previous: VoiceSessionSnapshot,
  action: SessionAction,
): TransitionResult {
  switch (action.type) {
    case "reset":
      return {
        snapshot: { ...initialVoiceSession(), generation: previous.generation + 1 },
      };
    case "record.start":
      if (!["idle", "completed", "cancelled", "failed", "interrupted"].includes(previous.state)) {
        return { snapshot: previous };
      }
      return {
        snapshot: {
          ...initialVoiceSession(),
          state: "recording",
          generation: previous.generation + 1,
        },
      };
    case "record.stop":
      return {
        snapshot:
          previous.state === "recording"
            ? { ...previous, state: "transcribing" }
            : previous,
      };
    case "transcription.succeeded":
      return {
        snapshot:
          previous.state === "transcribing"
            ? {
                ...previous,
                state: "awaiting_confirmation",
                transcript: action.transcript,
              }
            : previous,
      };
    case "transcription.failed":
    case "summary.failed":
    case "tts.failed":
    case "playback.failed":
      return { snapshot: fail(previous, action) };
    case "transcript.update":
      return {
        snapshot:
          previous.state === "awaiting_confirmation"
            ? { ...previous, transcript: action.transcript }
            : previous,
      };
    case "request.submit": {
      if (previous.state !== "awaiting_confirmation" || !previous.transcript.trim()) {
        return { snapshot: previous };
      }
      const { failure: _previousFailure, ...withoutFailure } = previous;
      return {
        snapshot: {
          ...withoutFailure,
          state: "sending",
          conversationId: action.conversationId,
          connectionId: action.connectionId,
          requestId: action.requestId,
          agentId: action.agentId,
          nodeId: action.nodeId,
          capabilityRevision: action.capabilityRevision,
          ...(action.sessionId === undefined ? {} : { sessionId: action.sessionId }),
          lastSequence: 0,
          recentEventIds: [],
          fullReply: "",
          speechText: "",
        },
      };
    }
    case "request.interrupt":
      return {
        snapshot: ["agent_working", "awaiting_approval", "awaiting_clarification"].includes(
          previous.state,
        )
          ? { ...previous, state: "interrupting" }
          : previous,
      };
    case "speech.stop":
      return {
        snapshot: ["synthesizing", "playing"].includes(previous.state)
          ? { ...previous, state: "completed" }
          : previous,
      };
    case "agent.event":
      return applyAgentEvent(previous, action.event);
    case "summary.ready":
      return {
        snapshot:
          previous.state === "summarizing"
            ? { ...previous, state: "synthesizing", speechText: action.speechText }
            : previous,
      };
    case "tts.ready":
      return {
        snapshot:
          previous.state === "synthesizing"
            ? { ...previous, state: "playing" }
            : previous,
      };
    case "playback.completed":
      return {
        snapshot:
          previous.state === "playing"
            ? { ...previous, state: "completed" }
            : previous,
      };
    case "cancel":
      return {
        snapshot: ["recording", "transcribing", "awaiting_confirmation"].includes(previous.state)
          ? { ...previous, state: "cancelled" }
          : previous,
      };
  }
}
