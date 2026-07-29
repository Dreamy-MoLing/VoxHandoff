import { createHash } from "node:crypto";
import process from "node:process";

import type { AgentCapabilities as CoreCapabilities, AgentEvent as CoreEvent } from "@agent-talk/core";
import {
  HermesHttpError,
  type HermesEventStreamOptions,
  type HermesRun,
} from "@agent-talk/adapters";
import { create, type MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import type { Client } from "@connectrpc/connect";
import {
  AgentCapabilitiesSchema,
  AgentEventSchema,
  AgentEventType,
  ApprovalDecision,
  ComponentRole,
  ConnectNodeRequestSchema,
  DeltaMode,
  EventEnvelopeSchema,
  FailureCategory,
  FailureStage,
  GatewayControlService,
  HandshakeOfferSchema,
  type ConnectNodeRequest,
  type ConnectNodeResponse,
  type DispatchApproval,
  type DispatchInterrupt,
  type DispatchRequest,
} from "@agent-talk/protocol";

import { AsyncQueue } from "./async-queue.js";
import {
  MemoryHermesSessionStore,
  type HermesSessionStore,
} from "./session-store.js";

const schemaBuild = "agent-talk-proto-v1.0";
const schemaSha256 =
  "ff60edd0d233123d10f0ede78feb9bc8de3e8eed5608678441918fa574bddac2";

export interface HermesAgentPort {
  health(): Promise<unknown>;
  capabilities(): Promise<CoreCapabilities>;
  createSession(title?: string): Promise<string>;
  startRun(
    input: string,
    options?: { sessionId?: string; requestId?: string },
  ): Promise<HermesRun>;
  streamRunEvents(
    run: HermesRun,
    options?: HermesEventStreamOptions,
  ): AsyncGenerator<CoreEvent>;
  stopRun(runId: string, commandId?: string): Promise<void>;
  resolveApproval(
    runId: string,
    approvalId: string,
    approved: boolean,
    commandId?: string,
  ): Promise<void>;
}

export interface HermesNodeIdentity {
  nodeId: string;
  agentId: string;
  nodeDisplayName: string;
  agentDisplayName: string;
  nodeVersion?: string;
}

interface ActiveRun {
  run: HermesRun;
  conversationId: string;
  routeSessionId: string;
  abortController: AbortController;
  lastSequence: number;
  lastEventId?: string;
  eventIds: Map<number, string>;
  approvals: Map<string, ApprovalFact>;
}

interface ApprovalFact {
  safeSummary: string;
  operationSummarySha256: string;
  expiresAt: string;
}

type DispatchState = "processing" | "accepted" | "rejected" | "uncertain";

export class HermesNodeConnector {
  readonly #runs = new Map<string, ActiveRun>();
  readonly #dispatchStates = new Map<string, DispatchState>();
  readonly #tasks = new Set<Promise<void>>();
  #capabilities: CoreCapabilities | undefined;

  constructor(
    private readonly hermes: HermesAgentPort,
    private readonly identity: HermesNodeIdentity,
    private readonly sessions: HermesSessionStore = new MemoryHermesSessionStore(),
  ) {}

  async initialize(): Promise<void> {
    await this.hermes.health();
    const capabilities = await this.hermes.capabilities();
    if (!capabilities.eventStream || !capabilities.idempotency) {
      throw new Error(
        "Hermes must explicitly advertise run events and idempotent submission",
      );
    }
    this.#capabilities = capabilities;
  }

  initialHandshake(): ConnectNodeRequest {
    this.#requiredCapabilities();
    return create(ConnectNodeRequestSchema, {
      body: {
        case: "handshake",
        value: create(HandshakeOfferSchema, {
          currentProtocol: { major: 1, minor: 0 },
          acceptedProtocols: { major: 1, minimumMinor: 0, maximumMinor: 0 },
          schemaBuild,
          schemaSha256,
          componentVersion: this.identity.nodeVersion ?? "0.1.0",
          componentRole: ComponentRole.NODE,
          capabilityRevision: this.capabilityRevision(),
          capabilities: create(AgentCapabilitiesSchema, {
            deltaMode: DeltaMode.NONE,
            eventStream: true,
            idempotency: true,
            attachments: false,
          }),
          scopes: ["node:connect"],
        }),
      },
    });
  }

  registration(): ConnectNodeRequest {
    const capabilities = this.#requiredCapabilities();
    return create(ConnectNodeRequestSchema, {
      body: {
        case: "registration",
        value: {
          node: {
            nodeId: this.identity.nodeId,
            displayName: this.identity.nodeDisplayName,
            platform: process.platform,
            version: this.identity.nodeVersion ?? "0.1.0",
          },
          agents: [{
            agentId: this.identity.agentId,
            displayName: this.identity.agentDisplayName,
            adapter: "hermes",
            version: capabilities.serverVersion ?? "unknown",
            capabilityRevision: this.capabilityRevision(),
            capabilities: protocolCapabilities(capabilities),
          }],
        },
      },
    });
  }

  capabilityRevision(): string {
    const capabilities = this.#requiredCapabilities();
    const canonical = JSON.stringify(
      Object.fromEntries(
        Object.entries(capabilities).sort(([left], [right]) =>
          left.localeCompare(right)
        ),
      ),
    );
    return `hermes-${createHash("sha256").update(canonical).digest("hex").slice(0, 24)}`;
  }

  async run(
    client: Client<typeof GatewayControlService>,
    gatewayToken: string,
    signal?: AbortSignal,
  ): Promise<void> {
    if (gatewayToken.length === 0) throw new Error("Gateway Node token is required");
    const output = new AsyncQueue<ConnectNodeRequest>();
    output.push(this.initialHandshake());
    const onAbort = () => output.finish();
    signal?.addEventListener("abort", onAbort, { once: true });
    const heartbeat = setInterval(() => {
      try {
        output.push(create(ConnectNodeRequestSchema, {
          body: { case: "heartbeat", value: { lastReceivedSequence: 0n } },
        }));
      } catch {
        clearInterval(heartbeat);
      }
    }, 10_000);
    heartbeat.unref();
    try {
      for await (const response of client.connectNode(output, {
        headers: new Headers({ authorization: `Bearer ${gatewayToken}` }),
        ...(signal === undefined ? {} : { signal }),
      })) {
        this.handle(response, output);
      }
      await Promise.allSettled(this.#tasks);
    } finally {
      clearInterval(heartbeat);
      signal?.removeEventListener("abort", onAbort);
      for (const active of this.#runs.values()) active.abortController.abort();
      output.finish();
    }
  }

  handle(
    response: ConnectNodeResponse,
    output: AsyncQueue<ConnectNodeRequest>,
  ): void {
    const body = response.body;
    switch (body.case) {
      case "handshake":
        if (
          body.value.componentRole !== ComponentRole.GATEWAY ||
          body.value.selectedProtocol?.major !== 1
        ) {
          throw new Error("Gateway returned an incompatible Node handshake");
        }
        output.push(this.registration());
        return;
      case "heartbeat":
        return;
      case "dispatchRequest":
        this.#spawn(this.#send(body.value, output));
        return;
      case "dispatchInterrupt":
        this.#spawn(this.#interrupt(body.value, output));
        return;
      case "dispatchApproval":
        this.#spawn(this.#approval(body.value, output));
        return;
      case "dispatchClarification":
        output.push(rejectedAck(
          body.value.dispatchId,
          body.value.requestId,
          "hermes_clarification_not_supported",
          "Hermes did not advertise clarification support.",
        ));
        return;
      case "protocolError":
        throw new Error(`Gateway protocol error: ${body.value.code}`);
      default:
        throw new Error("Gateway Node response body is missing or unsupported");
    }
  }

  #spawn(task: Promise<void>): void {
    this.#tasks.add(task);
    void task.finally(() => this.#tasks.delete(task));
  }

  async #send(
    dispatch: DispatchRequest,
    output: AsyncQueue<ConnectNodeRequest>,
  ): Promise<void> {
    const prior = this.#dispatchStates.get(dispatch.dispatchId);
    if (prior === "accepted") {
      output.push(acceptedAck(dispatch.dispatchId, dispatch.requestId));
      return;
    }
    if (prior === "rejected" || prior === "uncertain" || prior === "processing") {
      return;
    }
    this.#dispatchStates.set(dispatch.dispatchId, "processing");
    if (
      dispatch.nodeId !== this.identity.nodeId ||
      dispatch.agentId !== this.identity.agentId ||
      dispatch.capabilityRevision !== this.capabilityRevision() ||
      dispatch.confirmedText.trim().length === 0
    ) {
      this.#dispatchStates.set(dispatch.dispatchId, "rejected");
      output.push(rejectedAck(
        dispatch.dispatchId,
        dispatch.requestId,
        "hermes_dispatch_route_invalid",
        "The Hermes dispatch route or confirmed text is invalid.",
      ));
      return;
    }

    let sessionId = dispatch.sessionId;
    try {
      if (sessionId.length === 0) {
        sessionId = await this.sessions.get(dispatch.conversationId) ?? "";
      }
      if (sessionId.length === 0 && this.#requiredCapabilities().createSession) {
        sessionId = await this.hermes.createSession(
          `VoxHandoff ${dispatch.conversationId}`,
        );
        await this.sessions.set(dispatch.conversationId, sessionId);
      }
      const run = await this.hermes.startRun(dispatch.confirmedText, {
        requestId: dispatch.requestId,
        ...(sessionId.length === 0 ? {} : { sessionId }),
      });
      const active: ActiveRun = {
        run,
        conversationId: dispatch.conversationId,
        routeSessionId: dispatch.sessionId,
        abortController: new AbortController(),
        lastSequence: 0,
        eventIds: new Map(),
        approvals: new Map(),
      };
      this.#runs.set(dispatch.requestId, active);
      this.#dispatchStates.set(dispatch.dispatchId, "accepted");
      output.push(acceptedAck(dispatch.dispatchId, dispatch.requestId));
      await this.#stream(active, output);
    } catch (error) {
      if (this.#dispatchStates.get(dispatch.dispatchId) !== "accepted") {
        if (error instanceof HermesHttpError) {
          this.#dispatchStates.set(dispatch.dispatchId, "rejected");
          output.push(rejectedAck(
            dispatch.dispatchId,
            dispatch.requestId,
            `hermes_http_${error.status}`,
            "Hermes rejected the request before acceptance.",
          ));
          return;
        }
        this.#dispatchStates.set(dispatch.dispatchId, "uncertain");
        output.push(acceptanceUncertainEvent(dispatch));
      } else {
        const active = this.#runs.get(dispatch.requestId);
        if (active !== undefined && !active.abortController.signal.aborted) {
          output.push(streamLostEvent(active));
        }
      }
    }
  }

  async #stream(
    active: ActiveRun,
    output: AsyncQueue<ConnectNodeRequest>,
  ): Promise<void> {
    let consecutiveResumeAttempts = 0;
    while (!active.abortController.signal.aborted) {
      let disconnected = false;
      let observedNativeProgress = false;
      for await (const event of this.hermes.streamRunEvents(active.run, {
        signal: active.abortController.signal,
        ...(active.lastEventId === undefined
          ? {}
          : { lastEventId: active.lastEventId }),
        previousSequence: active.lastSequence,
        previousEventIds: active.eventIds,
        onResumeCursor: (eventId) => {
          active.lastEventId = eventId;
        },
      })) {
        const priorEventId = active.eventIds.get(event.sequence);
        if (priorEventId !== undefined) {
          if (priorEventId === event.eventId) continue;
          throw new Error("Hermes replay changed an accepted event identity");
        }
        if (event.sequence <= active.lastSequence) {
          throw new Error("Hermes replay did not advance the accepted sequence");
        }
        active.lastSequence = event.sequence;
        active.eventIds.set(event.sequence, event.eventId);
        if (active.eventIds.size > 1_024) {
          active.eventIds.delete(active.eventIds.keys().next().value as number);
        }
        disconnected = event.type === "connection.lost";
        observedNativeProgress = observedNativeProgress || !disconnected;
        const approval = approvalFact(event);
        if (approval !== undefined) {
          active.approvals.set(approval.approvalId, approval.fact);
        }
        output.push(mapEvent(active, event));
        if (terminal(event)) {
          this.#runs.delete(active.run.requestId);
          return;
        }
      }
      if (!disconnected || active.abortController.signal.aborted) return;
      const capabilities = this.#requiredCapabilities();
      if (
        !capabilities.replay ||
        !capabilities.sequenceRecovery ||
        active.lastEventId === undefined
      ) {
        return;
      }
      consecutiveResumeAttempts = observedNativeProgress
        ? 1
        : consecutiveResumeAttempts + 1;
      if (consecutiveResumeAttempts > 3) return;
      await waitForResume(
        100 * 2 ** (consecutiveResumeAttempts - 1),
        active.abortController.signal,
      );
    }
  }

  async #interrupt(
    dispatch: DispatchInterrupt,
    output: AsyncQueue<ConnectNodeRequest>,
  ): Promise<void> {
    const active = this.#runs.get(dispatch.requestId);
    if (active === undefined || !this.#requiredCapabilities().interrupt) {
      output.push(rejectedAck(
        dispatch.dispatchId,
        dispatch.requestId,
        "hermes_interrupt_unavailable",
        "The Hermes run is unavailable for an explicit stop.",
      ));
      return;
    }
    try {
      await this.hermes.stopRun(active.run.runId, dispatch.idempotencyKey);
      output.push(acceptedAck(dispatch.dispatchId, dispatch.requestId));
    } catch {
      output.push(rejectedAck(
        dispatch.dispatchId,
        dispatch.requestId,
        "hermes_interrupt_failed",
        "Hermes did not confirm the explicit stop.",
      ));
    }
  }

  async #approval(
    dispatch: DispatchApproval,
    output: AsyncQueue<ConnectNodeRequest>,
  ): Promise<void> {
    const active = this.#runs.get(dispatch.requestId);
    const approval = active?.approvals.get(dispatch.approvalId);
    if (
      active === undefined ||
      approval === undefined ||
      approval.operationSummarySha256 !== dispatch.operationSummarySha256 ||
      new Date(approval.expiresAt).getTime() <= Date.now() ||
      !this.#requiredCapabilities().approval ||
      dispatch.decision === ApprovalDecision.UNSPECIFIED
    ) {
      output.push(rejectedAck(
        dispatch.dispatchId,
        dispatch.requestId,
        "hermes_approval_identity_invalid",
        "The Hermes approval identity or capability is invalid.",
      ));
      return;
    }
    try {
      await this.hermes.resolveApproval(
        active.run.runId,
        dispatch.approvalId,
        dispatch.decision === ApprovalDecision.APPROVE,
        dispatch.idempotencyKey,
      );
      output.push(acceptedAck(dispatch.dispatchId, dispatch.requestId));
    } catch {
      output.push(rejectedAck(
        dispatch.dispatchId,
        dispatch.requestId,
        "hermes_approval_failed",
        "Hermes did not confirm the approval decision.",
      ));
    }
  }

  #requiredCapabilities(): CoreCapabilities {
    if (this.#capabilities === undefined) {
      throw new Error("Hermes Node Connector must be initialized first");
    }
    return this.#capabilities;
  }
}

function protocolCapabilities(capabilities: CoreCapabilities) {
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

function acceptedAck(dispatchId: string, requestId: string): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "dispatchAck",
      value: { dispatchId, requestId, accepted: true },
    },
  });
}

function rejectedAck(
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

function acceptanceUncertainEvent(dispatch: DispatchRequest): ConnectNodeRequest {
  return eventFrame({
    eventId: stableId(`acceptance-uncertain:${dispatch.dispatchId}`),
    connectionId: "hermes-acceptance-uncertain",
    conversationId: dispatch.conversationId,
    sessionId: dispatch.sessionId,
    requestId: dispatch.requestId,
    sequence: 1,
    type: AgentEventType.CONNECTION_LOST,
    payload: {
      case: "connection",
      value: {
        safeMessage:
          "Hermes submission acceptance is uncertain. VoxHandoff did not resubmit it.",
      },
    },
  });
}

function streamLostEvent(active: ActiveRun): ConnectNodeRequest {
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
    payload: {
      case: "connection",
      value: {
        safeMessage:
          "Hermes event processing stopped. The accepted run was not resubmitted.",
      },
    },
  });
}

function mapEvent(active: ActiveRun, event: CoreEvent): ConnectNodeRequest {
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
  });
}

function progress(
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

function message(
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
  occurredAt?: Date;
}

function eventFrame(input: EventFrameInput): ConnectNodeRequest {
  return create(ConnectNodeRequestSchema, {
    body: {
      case: "event",
      value: create(EventEnvelopeSchema, {
        protocol: { major: 1, minor: 0 },
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

function approvalFact(
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

function terminal(event: CoreEvent): boolean {
  return [
    "request.completed",
    "request.failed",
    "request.cancelled",
    "request.interrupted",
  ].includes(event.type);
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function safeText(value: unknown, fallback: string): string {
  return typeof value === "string" ? value.slice(0, 4096) : fallback;
}

function stableId(value: string): string {
  return createHash("sha256")
    .update("voxhandoff:hermes-node:v1\0")
    .update(value)
    .digest("hex");
}

function waitForResume(milliseconds: number, signal: AbortSignal): Promise<void> {
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
