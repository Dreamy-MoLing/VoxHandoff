import { createHash } from "node:crypto";

import type { AgentCapabilities as CoreCapabilities, AgentEvent as CoreEvent } from "@agent-talk/core";
import { create, type MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  AgentCapabilitiesSchema,
  AgentEventSchema,
  AgentEventType,
  ComponentRole,
  ConnectNodeRequestSchema,
  DeltaMode,
  EventEnvelopeSchema,
  FailureCategory,
  FailureStage,
  ProtocolVersionSchema,
  type ConnectNodeRequest,
  type DispatchRequest,
  type EventEnvelope,
} from "@agent-talk/protocol";

import type { ActiveRun, ApprovalFact } from "./hermes-node-connector.js";

export function protocolCapabilities(capabilities: CoreCapabilities) {
  return create(AgentCapabilitiesSchema, {
    deltaMode: capabilities.deltaMode === "append_only"
      ? DeltaMode.APPEND_ONLY
      : capabilities.deltaMode === "revisable"
        ? DeltaMode.REVISABLE
        : DeltaMode.NONE,
    eventStream: capabilities.eventStream,
    sessionHistory: capabilities.sessionHistory,
    createSession: capabilities.createSession,
    resumeSession: capabilities.resumeSession,
    interrupt: capabilities.interrupt,
    steer: false,
    clarification: false,
    approval: capabilities.approval,
    toolEvents: capabilities.toolEvents,
    attachments: false,
    idempotency: capabilities.idempotency,
    replay: capabilities.replay,
    sequenceRecovery: capabilities.sequenceRecovery,
    ...(capabilities.maxRequestBytes === undefined
      ? {}
      : { maxRequestBytes: BigInt(capabilities.maxRequestBytes) }),
    ...(capabilities.requestTimeoutMs === undefined
      ? {}
      : { requestTimeoutMs: BigInt(capabilities.requestTimeoutMs) }),
  });
}

export function acceptedAck(dispatchId: string, requestId: string): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "dispatchAck",
      value: { dispatchId, requestId, accepted: true },
    },
  });
}

export function rejectedAck(
  dispatchId: string,
  requestId: string,
  code: string,
  safeMessage: string,
): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "dispatchAck",
      value: {
        dispatchId,
        requestId,
        accepted: false,
        failure: {
          stage: FailureStage.AGENT,
          category: FailureCategory.UPSTREAM,
          code,
          safeMessage,
          retryable: false,
        },
      },
    },
  });
}

export function acceptanceUncertainEvent(
  dispatch: DispatchRequest,
  protocolMinor: number,
): ConnectNodeRequest {
  return eventFrame({
    eventId: stableId(`acceptance-uncertain:${dispatch.dispatchId}`),
    connectionId: "hermes-acceptance-uncertain",
    conversationId: dispatch.conversationId,
    sessionId: dispatch.sessionId,
    requestId: dispatch.requestId,
    sequence: 1,
    type: AgentEventType.CONNECTION_LOST,
    protocolMinor,
    payload: {
      case: "connection",
      value: {
        safeMessage:
          "Hermes submission acceptance is uncertain. VoxHandoff did not resubmit it.",
      },
    },
  });
}

export function streamLostEvent(active: ActiveRun, protocolMinor: number): ConnectNodeRequest {
  return eventFrame({
    eventId: stableId(
      `stream-lost:${active.run.runId}:${active.lastSequence + 1}`,
    ),
    connectionId: "hermes-stream-lost",
    conversationId: active.conversationId,
    sessionId: active.routeSessionId,
    requestId: active.run.requestId,
    sequence: active.lastSequence + 1,
    type: AgentEventType.CONNECTION_LOST,
    protocolMinor,
    payload: {
      case: "connection",
      value: {
        safeMessage:
          "Hermes event processing stopped. The accepted run was not resubmitted.",
      },
    },
  });
}

export function mapEvent(
  active: ActiveRun,
  event: CoreEvent,
  protocolMinor: number,
): ConnectNodeRequest {
  const payload = asRecord(event.payload);
  const mapped = (() => {
    switch (event.type) {
      case "connection.ready":
        return progress(AgentEventType.CONNECTION_READY, "connection", safeText(payload.safeMessage, "Hermes connected."));
      case "connection.lost":
        return progress(
          AgentEventType.CONNECTION_LOST,
          "connection",
          "Hermes event stream disconnected; the run was not resubmitted.",
        );
      case "request.accepted":
      case "agent.working":
        return progress(AgentEventType.AGENT_WORKING, "requestProgress", "Hermes is working.");
      case "request.interrupting":
        return progress(
          AgentEventType.REQUEST_INTERRUPTING,
          "requestProgress",
          "Hermes is stopping the run.",
        );
      case "message.delta":
        return message(
          AgentEventType.MESSAGE_DELTA,
          safeText(payload.delta, ""),
          event.sequence,
        );
      case "message.completed":
        return message(
          AgentEventType.MESSAGE_COMPLETED,
          safeText(payload.text, ""),
          event.sequence,
        );
      case "tool.started":
      case "tool.completed":
      case "tool.failed":
        return {
          type: event.type === "tool.started"
            ? AgentEventType.TOOL_STARTED
            : event.type === "tool.completed"
              ? AgentEventType.TOOL_COMPLETED
              : AgentEventType.TOOL_FAILED,
          payload: {
            case: "tool" as const,
            value: {
              toolName: safeText(payload.toolName, "Hermes tool"),
              stage: event.type.slice("tool.".length),
              safeSummary: safeText(payload.safeSummary, "Hermes tool activity."),
            },
          },
        };
      case "approval.required":
      case "approval.resolved":
      case "approval.expired":
      case "approval.cancelled": {
        const stored = active.approvals.get(safeText(payload.approvalId, ""));
        return {
          type: event.type === "approval.required"
            ? AgentEventType.APPROVAL_REQUIRED
            : event.type === "approval.resolved"
              ? AgentEventType.APPROVAL_RESOLVED
              : event.type === "approval.expired"
                ? AgentEventType.APPROVAL_EXPIRED
                : AgentEventType.APPROVAL_CANCELLED,
          payload: {
            case: "approval" as const,
            value: {
              approvalId: safeText(payload.approvalId, ""),
              safeSummary: stored?.safeSummary ?? safeText(payload.safeSummary, ""),
              operationSummarySha256:
                stored?.operationSummarySha256 ??
                safeText(payload.operationSummarySha256, ""),
              expiresAt: timestampFromDate(
                new Date(stored?.expiresAt ?? safeText(payload.expiresAt, "")),
              ),
            },
          },
        };
      }
      case "request.completed":
      case "request.cancelled":
      case "request.interrupted":
        return {
          type: event.type === "request.completed"
            ? AgentEventType.REQUEST_COMPLETED
            : event.type === "request.cancelled"
              ? AgentEventType.REQUEST_CANCELLED
              : AgentEventType.REQUEST_INTERRUPTED,
          payload: {
            case: "requestTerminal" as const,
            value: {},
          },
        };
      case "request.failed":
        return {
          type: AgentEventType.REQUEST_FAILED,
          payload: {
            case: "requestTerminal" as const,
            value: {
              failure: {
                stage: FailureStage.AGENT,
                category: FailureCategory.UPSTREAM,
                code: safeText(payload.code, "hermes_run_failed"),
                safeMessage: safeText(payload.message, "Hermes run failed."),
                retryable: false,
              },
            },
          },
        };
      default:
        return progress(AgentEventType.AGENT_WORKING, "requestProgress", "Hermes is working.");
    }
  })();
  return eventFrame({
    eventId: event.eventId,
    connectionId: event.connectionId,
    conversationId: active.conversationId,
    sessionId: active.routeSessionId,
    requestId: active.run.requestId,
    sequence: event.sequence,
    type: mapped.type,
    payload: mapped.payload,
    occurredAt: new Date(event.occurredAt),
    protocolMinor,
  });
}

export function progress(
  type: AgentEventType,
  payloadCase: "connection" | "requestProgress",
  safeMessage: string,
) {
  return {
    type,
    payload: {
      case: payloadCase,
      value: { safeMessage },
    },
  } as const;
}

export function message(
  type: AgentEventType,
  text: string,
  revision: number,
) {
  return {
    type,
    payload: {
      case: "message" as const,
      value: { text, revision: BigInt(revision) },
    },
  };
}

interface EventFrameInput {
  eventId: string;
  connectionId: string;
  conversationId: string;
  sessionId: string;
  requestId: string;
  sequence: number;
  type: AgentEventType;
  payload: NonNullable<MessageInitShape<typeof AgentEventSchema>["payload"]>;
  protocolMinor: number;
  occurredAt?: Date;
}

export function eventFrame(input: EventFrameInput): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "event",
      value: create(EventEnvelopeSchema, {
        protocol: { major: 1, minor: input.protocolMinor },
        eventId: input.eventId,
        connectionId: input.connectionId,
        conversationId: input.conversationId,
        sessionId: input.sessionId,
        requestId: input.requestId,
        sequence: BigInt(input.sequence),
        occurredAt: timestampFromDate(input.occurredAt ?? new Date()),
        event: create(AgentEventSchema, {
          type: input.type,
          payload: input.payload,
        }),
      }),
    },
  });
}

export function eventEnvelope(frame: ConnectNodeRequest): EventEnvelope | undefined {
  return frame.body.case === "event" ? frame.body.value : undefined;
}

export function withEventProtocolMinor(
  frame: ConnectNodeRequest,
  protocolMinor: number,
): ConnectNodeRequest {
  const envelope = eventEnvelope(frame);
  if (envelope === undefined || envelope.protocol?.minor === protocolMinor) return frame;
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "event",
      value: create(EventEnvelopeSchema, {
        ...envelope,
        protocol: create(ProtocolVersionSchema, { major: 1, minor: protocolMinor }),
      }),
    },
  });
}

export function approvalFact(
  event: CoreEvent,
): { approvalId: string; fact: ApprovalFact } | undefined {
  if (event.type !== "approval.required") return undefined;
  const payload = asRecord(event.payload);
  const approvalId = safeText(payload.approvalId, "");
  const safeSummary = safeText(payload.safeSummary, "");
  const operationSummarySha256 = safeText(payload.operationSummarySha256, "");
  const expiresAt = safeText(payload.expiresAt, "");
  if (
    approvalId.length === 0 ||
    safeSummary.length === 0 ||
    !/^[0-9a-f]{64}$/u.test(operationSummarySha256) ||
    Number.isNaN(new Date(expiresAt).getTime())
  ) {
    throw new Error("Hermes approval event is missing its verified display identity");
  }
  return {
    approvalId,
    fact: { safeSummary, operationSummarySha256, expiresAt },
  };
}

export function terminal(event: CoreEvent): boolean {
  return [
    "request.completed",
    "request.failed",
    "request.cancelled",
    "request.interrupted",
  ].includes(event.type);
}

export function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function safeText(value: unknown, fallback: string): string {
  return typeof value === "string" ? value.slice(0, 4096) : fallback;
}

export function stableId(value: string): string {
  return createHash("sha256")
    .update("voxhandoff:hermes-node:v1\0")
    .update(value)
    .digest("hex");
}

export function waitForResume(milliseconds: number, signal: AbortSignal): Promise<void> {
  if (signal.aborted) return Promise.resolve();
  return new Promise((resolve) => {
    const timer = setTimeout(finish, milliseconds);
    const onAbort = () => finish();
    function finish() {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
      resolve();
    }
    signal.addEventListener("abort", onAbort, { once: true });
  });
}
