import type {
  AgentEvent,
  SessionAction,
  TransitionResult,
  VoiceSessionSnapshot,
} from "./model.js";

const terminalStates = new Set(["completed", "cancelled", "failed"] as const);

export function initialVoiceSession(): VoiceSessionSnapshot {
  return {
    state: "idle",
    generation: 0,
    lastSequence: -1,
    transcript: "",
    fullReply: "",
    speechText: "",
  };
}

function fail(
  previous: VoiceSessionSnapshot,
  action: Extract<
    SessionAction,
    { type: "transcription.failed" | "summary.failed" | "tts.failed" }
  >,
): VoiceSessionSnapshot {
  if (action.type === "summary.failed" || action.type === "tts.failed") {
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
  if (terminalStates.has(previous.state as "completed" | "cancelled" | "failed")) {
    return ignored(previous, event, "terminal_state");
  }
  if (event.connectionId !== previous.connectionId) {
    return ignored(previous, event, "wrong_connection");
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
  if (event.sequence <= previous.lastSequence) {
    return ignored(previous, event, "stale_sequence");
  }

  const next = { ...previous, lastSequence: event.sequence };
  switch (event.type) {
    case "request.accepted":
      return { snapshot: { ...next, state: "agent_working" } };
    case "agent.working":
    case "tool.started":
    case "tool.completed":
      return { snapshot: { ...next, state: "agent_working" } };
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
    case "clarification.required":
      return { snapshot: { ...next, state: "awaiting_clarification" } };
    case "request.completed":
      return { snapshot: { ...next, state: "summarizing" } };
    case "request.cancelled":
      return { snapshot: { ...next, state: "cancelled" } };
    case "request.failed":
      return {
        snapshot: {
          ...next,
          state: "failed",
          failure: {
            stage: "agent",
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
      if (!["idle", "completed", "cancelled", "failed"].includes(previous.state)) {
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
          connectionId: action.connectionId,
          requestId: action.requestId,
          ...(action.sessionId === undefined ? {} : { sessionId: action.sessionId }),
          lastSequence: -1,
          fullReply: "",
          speechText: "",
        },
      };
    }
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
        snapshot:
          previous.state === "idle"
            ? previous
            : { ...previous, state: "cancelled" },
      };
  }
}
