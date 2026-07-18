import assert from "node:assert/strict";
import test from "node:test";

import type { AgentEvent, VoiceSessionSnapshot } from "./model.js";
import { initialVoiceSession, transition } from "./state-machine.js";

function submitted(): VoiceSessionSnapshot {
  let state = initialVoiceSession();
  state = transition(state, { type: "record.start" }).snapshot;
  state = transition(state, { type: "record.stop" }).snapshot;
  state = transition(state, {
    type: "transcription.succeeded",
    transcript: "检查项目",
  }).snapshot;
  return transition(state, {
    type: "request.submit",
    conversationId: "conversation-1",
    connectionId: "conn-1",
    sessionId: "session-1",
    requestId: "request-1",
    agentId: "agent-1",
    nodeId: "node-1",
    capabilityRevision: "cap-1",
  }).snapshot;
}

function event(
  sequence: number,
  type: AgentEvent["type"],
  payload: unknown = {},
): AgentEvent {
  return {
    eventId: `event-${sequence}`,
    connectionId: "conn-1",
    conversationId: "conversation-1",
    sessionId: "session-1",
    requestId: "request-1",
    sequence,
    occurredAt: new Date(0).toISOString(),
    type,
    payload,
  };
}

test("preserves the complete reply independently from speech", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "request.accepted") }).snapshot;
  state = transition(state, {
    type: "agent.event",
    event: event(2, "message.delta", { delta: "完整" }),
  }).snapshot;
  state = transition(state, {
    type: "agent.event",
    event: event(3, "message.delta", { delta: "回复" }),
  }).snapshot;
  state = transition(state, {
    type: "agent.event",
    event: event(4, "request.completed"),
  }).snapshot;
  state = transition(state, { type: "summary.ready", speechText: "已完成。" }).snapshot;

  assert.equal(state.fullReply, "完整回复");
  assert.equal(state.speechText, "已完成。");
  assert.equal(state.state, "synthesizing");
});

test("rejects stale and cross-request events", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "agent.working") }).snapshot;

  const stale = transition(state, {
    type: "agent.event",
    event: { ...event(1, "message.delta", { delta: "stale" }), eventId: "stale-copy" },
  });
  assert.equal(stale.ignored?.reason, "stale_sequence");
  assert.equal(stale.snapshot.fullReply, "");

  const foreign = transition(state, {
    type: "agent.event",
    event: { ...event(2, "message.delta", { delta: "foreign" }), requestId: "request-2" },
  });
  assert.equal(foreign.ignored?.reason, "wrong_request");
});

test("rejects duplicate event IDs and sequence gaps without mutating state", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "agent.working") }).snapshot;

  const duplicate = transition(state, {
    type: "agent.event",
    event: { ...event(2, "message.delta", { delta: "duplicate" }), eventId: "event-1" },
  });
  assert.equal(duplicate.ignored?.reason, "duplicate_event");
  assert.equal(duplicate.snapshot.fullReply, "");

  const gap = transition(state, {
    type: "agent.event",
    event: event(3, "message.delta", { delta: "gap" }),
  });
  assert.equal(gap.ignored?.reason, "sequence_gap");
  assert.equal(gap.snapshot.lastSequence, 1);
});

test("a disconnect after submission becomes uncertain, never auto-retried", () => {
  const state = transition(submitted(), {
    type: "agent.event",
    event: event(1, "connection.lost"),
  }).snapshot;
  assert.equal(state.state, "uncertain");
});

test("approval is represented as a blocking visible state", () => {
  const state = transition(submitted(), {
    type: "agent.event",
    event: event(1, "approval.required", { command: "rm example" }),
  }).snapshot;
  assert.equal(state.state, "awaiting_approval");
});

test("interrupt confirmation stays distinct from local cancellation", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "request.accepted") }).snapshot;
  state = transition(state, { type: "request.interrupt" }).snapshot;
  assert.equal(state.state, "interrupting");

  const cancelled = transition(state, { type: "cancel" }).snapshot;
  assert.equal(cancelled.state, "interrupting");

  state = transition(state, {
    type: "agent.event",
    event: event(2, "request.interrupted", { reason: "user_requested" }),
  }).snapshot;
  assert.equal(state.state, "interrupted");
});

test("summary failures preserve the complete reply", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "request.accepted") }).snapshot;
  state = transition(state, {
    type: "agent.event",
    event: event(2, "message.completed", { text: "完整文字" }),
  }).snapshot;
  state = transition(state, { type: "agent.event", event: event(3, "request.completed") }).snapshot;
  state = transition(state, {
    type: "summary.failed",
    failure: {
      stage: "summary",
      category: "upstream",
      code: "summary_unavailable",
      message: "摘要不可用",
      retryable: false,
    },
  }).snapshot;

  assert.equal(state.state, "completed");
  assert.equal(state.fullReply, "完整文字");
});

test("speech stop never interrupts an active Agent request", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "request.accepted") }).snapshot;
  state = transition(state, { type: "speech.stop" }).snapshot;
  assert.equal(state.state, "agent_working");
});

test("all identity dimensions are checked before applying an event", () => {
  const state = submitted();
  const cases = [
    [{ ...event(1, "agent.working"), connectionId: "other" }, "wrong_connection"],
    [{ ...event(1, "agent.working"), conversationId: "other" }, "wrong_conversation"],
    [{ ...event(1, "agent.working"), sessionId: "other" }, "wrong_session"],
    [{ ...event(1, "agent.working"), requestId: "other" }, "wrong_request"],
  ] as const;

  for (const [foreignEvent, reason] of cases) {
    const result = transition(state, { type: "agent.event", event: foreignEvent });
    assert.equal(result.ignored?.reason, reason);
    assert.equal(result.snapshot, state);
  }
});

test("recent event deduplication memory remains bounded", () => {
  let state = submitted();
  for (let sequence = 1; sequence <= 140; sequence += 1) {
    state = transition(state, {
      type: "agent.event",
      event: event(sequence, "agent.working"),
    }).snapshot;
  }

  assert.equal(state.recentEventIds.length, 128);
  assert.equal(state.recentEventIds[0], "event-13");
  assert.equal(state.recentEventIds.at(-1), "event-140");
});

test("request terminal events remain distinct and reject later mutation", () => {
  const cases = [
    ["request.completed", "summarizing"],
    ["request.failed", "failed"],
    ["request.cancelled", "cancelled"],
    ["request.interrupted", "interrupted"],
  ] as const;

  for (const [terminalEvent, expectedState] of cases) {
    const terminal = transition(submitted(), {
      type: "agent.event",
      event: event(1, terminalEvent),
    }).snapshot;
    assert.equal(terminal.state, expectedState);

    const late = transition(terminal, {
      type: "agent.event",
      event: event(2, "message.delta", { delta: "late" }),
    });
    assert.equal(late.ignored?.reason, "terminal_state");
    assert.equal(late.snapshot.fullReply, "");
  }
});

test("local cancellation and interrupt are unavailable before acceptance", () => {
  const sending = submitted();
  assert.equal(transition(sending, { type: "cancel" }).snapshot.state, "sending");
  assert.equal(transition(sending, { type: "request.interrupt" }).snapshot.state, "sending");
});

test("playback failure preserves the complete reply and terminal request state", () => {
  let state = submitted();
  state = transition(state, { type: "agent.event", event: event(1, "request.accepted") }).snapshot;
  state = transition(state, {
    type: "agent.event",
    event: event(2, "message.completed", { text: "完整文字" }),
  }).snapshot;
  state = transition(state, { type: "agent.event", event: event(3, "request.completed") }).snapshot;
  state = transition(state, { type: "summary.ready", speechText: "短播报" }).snapshot;
  state = transition(state, { type: "tts.ready" }).snapshot;
  state = transition(state, {
    type: "playback.failed",
    failure: {
      stage: "playback",
      category: "unavailable",
      code: "playback_device_lost",
      message: "播放设备不可用",
      retryable: false,
    },
  }).snapshot;

  assert.equal(state.state, "completed");
  assert.equal(state.fullReply, "完整文字");
  assert.equal(state.failure?.stage, "playback");
});
