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
    connectionId: "conn-1",
    sessionId: "session-1",
    requestId: "request-1",
  }).snapshot;
}

function event(
  sequence: number,
  type: AgentEvent["type"],
  payload: unknown = {},
): AgentEvent {
  return {
    connectionId: "conn-1",
    sessionId: "session-1",
    requestId: "request-1",
    sequence,
    serverTime: new Date(0).toISOString(),
    type,
    payload,
    final: type.startsWith("request.") && !type.endsWith("accepted"),
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
  state = transition(state, { type: "agent.event", event: event(5, "agent.working") }).snapshot;

  const stale = transition(state, {
    type: "agent.event",
    event: event(4, "message.delta", { delta: "stale" }),
  });
  assert.equal(stale.ignored?.reason, "stale_sequence");
  assert.equal(stale.snapshot.fullReply, "");

  const foreign = transition(state, {
    type: "agent.event",
    event: { ...event(6, "message.delta", { delta: "foreign" }), requestId: "request-2" },
  });
  assert.equal(foreign.ignored?.reason, "wrong_request");
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
