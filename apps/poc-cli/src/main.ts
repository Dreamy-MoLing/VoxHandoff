#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import process from "node:process";

import {
  CodexAppServerClient,
  HermesApiClient,
  type CodexServerRequest,
} from "@agent-talk/adapters";
import {
  createSpeechSummaryForOutcome,
  isTerminalAgentEventType,
  redact,
  type AgentEvent,
  type TerminalAgentEventType,
} from "@agent-talk/core";

import {
  optionalPositiveInteger,
  parseArgs,
  required,
  type ParsedArgs,
} from "./args.js";

function print(value: unknown): void {
  process.stdout.write(`${JSON.stringify(redact(value))}\n`);
}

function commandVersion(command: string, args: string[]): string | undefined {
  const result = spawnSync(command, args, { encoding: "utf8" });
  // Some managed sandboxes annotate an otherwise successful spawn with EPERM.
  // A zero exit status plus version output is still an affirmative check.
  if (result.status !== 0) return undefined;
  return (result.stdout || result.stderr).trim().split("\n")[0];
}

function doctor(): void {
  const checks = [
    ["node", commandVersion("node", ["--version"])],
    ["codex", commandVersion("codex", ["--version"])],
    ["hermes", commandVersion("hermes", ["--version"])],
    ["ffmpeg", commandVersion("ffmpeg", ["-version"])],
  ];
  for (const [name, version] of checks) {
    print({ component: name, available: version !== undefined, version: version ?? null });
  }
}

async function codex(args: ParsedArgs): Promise<void> {
  const prompt = required(args, "prompt");
  const interruptAfterMs = optionalPositiveInteger(args, "interrupt-after-ms");
  const approvalProbe = args.flags.has("approval-probe");
  const failureProbe = args.flags.has("failure-probe");
  if (approvalProbe && failureProbe) {
    throw new Error("Options --approval-probe and --failure-probe cannot be combined");
  }
  if (failureProbe && interruptAfterMs !== undefined) {
    throw new Error("Options --failure-probe and --interrupt-after-ms cannot be combined");
  }
  const client = new CodexAppServerClient({ cwd: args.values.get("cwd") ?? process.cwd() });
  let finalText = "";
  let activeThreadId: string | undefined;
  let activeTurnId: string | undefined;
  let terminal = false;
  let outcome: TerminalAgentEventType | undefined;
  let blockedUserAction = false;
  let sawApproval = false;
  let interruptTimer: ReturnType<typeof setTimeout> | undefined;
  let interruptAttempt: Promise<void> | undefined;
  let resolveFinal: (() => void) | undefined;
  let rejectFinal: ((error: Error) => void) | undefined;
  const final = new Promise<void>((resolve, reject) => {
    resolveFinal = resolve;
    rejectFinal = reject;
  });

  const requestInterrupt = (reason: "timer" | "user_action_required"): void => {
    if (interruptAttempt || !activeThreadId || !activeTurnId) return;
    print({ kind: "interrupt_requested", reason });
    interruptAttempt = client.interruptTurn(activeThreadId, activeTurnId).then(
      () => print({ kind: "interrupt_acknowledged" }),
      (error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        rejectFinal?.(new Error(`Codex interrupt failed: ${message}`));
      },
    );
  };

  client.on("diagnostic", (value) => print({ kind: "diagnostic", value }));
  client.on("serverRequest", (request: CodexServerRequest) => {
    blockedUserAction = true;
    print({ kind: "blocked", reason: "user_action_required", request });
    if (activeThreadId && activeTurnId) {
      requestInterrupt("user_action_required");
    } else {
      rejectFinal?.(new Error("Codex requested user action before the turn was ready"));
    }
  });
  client.on("agentEvent", (event: AgentEvent) => {
    print({ kind: "agent_event", event });
    if (event.type === "message.delta") {
      const payload = event.payload as { delta?: unknown };
      if (typeof payload.delta === "string") finalText += payload.delta;
    } else if (event.type === "message.completed") {
      const payload = event.payload as { text?: unknown };
      if (typeof payload.text === "string" && payload.text) finalText = payload.text;
    } else if (isTerminalAgentEventType(event.type)) {
      terminal = true;
      outcome = event.type;
      if (interruptTimer) clearTimeout(interruptTimer);
      if (
        event.type === "request.completed" ||
        event.type === "request.cancelled" ||
        event.type === "request.interrupted" ||
        (failureProbe && event.type === "request.failed")
      ) {
        resolveFinal?.();
      } else {
        rejectFinal?.(new Error("Codex request failed"));
      }
    } else if (event.type === "approval.required") {
      sawApproval = true;
    }
  });
  client.on("disconnect", (value) => {
    if (activeTurnId) {
      rejectFinal?.(new Error(`Codex disconnected: ${JSON.stringify(value)}`));
    }
  });

  try {
    await client.start();
    activeThreadId = args.values.get("thread");
    if (activeThreadId) await client.resumeThread(activeThreadId);
    else activeThreadId = await client.startThread({ cwd: args.values.get("cwd") ?? process.cwd() });
    const handle = await client.startTurn(activeThreadId, prompt, {
      ...(approvalProbe
        ? { approvalPolicy: "untrusted" as const, approvalsReviewer: "user" as const }
        : {}),
      ...(failureProbe ? { model: "agent-talk-invalid-model" } : {}),
    });
    activeTurnId = handle.turnId;
    print({ kind: "turn_started", handle });
    if (interruptAfterMs !== undefined) {
      interruptTimer = setTimeout(() => {
        if (terminal || !activeThreadId || !activeTurnId) return;
        print({ kind: "interrupt_timer_elapsed", afterMs: interruptAfterMs });
        requestInterrupt("timer");
      }, interruptAfterMs);
    }
    await final;
    if (interruptAttempt) await interruptAttempt;
    print({
      kind: "result",
      threadId: activeThreadId,
      turnId: activeTurnId,
      outcome: outcome ?? "unknown",
      blockedUserAction,
      fullText: finalText,
      speechText: createSpeechSummaryForOutcome(outcome, finalText) ?? null,
    });
    if (approvalProbe && (!sawApproval || !blockedUserAction)) {
      throw new Error("Codex approval probe completed without a blocking approval request");
    }
    if (blockedUserAction && !approvalProbe) {
      throw new Error("Codex requested interactive approval or clarification");
    }
    if (failureProbe && outcome !== "request.failed") {
      throw new Error("Codex failure probe did not produce request.failed");
    }
  } finally {
    if (interruptTimer) clearTimeout(interruptTimer);
    await client.close();
  }
}

async function hermes(args: ParsedArgs): Promise<void> {
  const prompt = required(args, "prompt");
  const rounds = optionalPositiveInteger(args, "rounds") ?? 1;
  const stopAfterMs = optionalPositiveInteger(args, "stop-after-ms");
  const approvalProbe = args.flags.has("approval-probe");
  const disconnectProbe = args.flags.has("disconnect-probe");
  if (rounds > 100) throw new Error("Option --rounds cannot exceed 100");
  if (rounds > 1 && stopAfterMs !== undefined) {
    throw new Error("Option --stop-after-ms requires --rounds 1");
  }
  if (approvalProbe && (rounds > 1 || stopAfterMs !== undefined)) {
    throw new Error("Option --approval-probe requires one round without --stop-after-ms");
  }
  if (disconnectProbe && (rounds > 1 || stopAfterMs !== undefined || approvalProbe)) {
    throw new Error(
      "Option --disconnect-probe requires one round without stop or approval probes",
    );
  }
  const tokenEnv = args.values.get("token-env") ?? "HERMES_API_KEY";
  const token = process.env[tokenEnv];
  if (!token) throw new Error(`Environment variable ${tokenEnv} is not set`);
  const client = new HermesApiClient({
    baseUrl: args.values.get("base-url") ?? "http://127.0.0.1:8642",
    token,
  });
  print({ kind: "health", value: await client.health() });
  print({ kind: "capabilities", value: await client.capabilities() });
  let sessionId = args.values.get("session");
  if (args.flags.has("create-session")) {
    if (sessionId) throw new Error("Options --session and --create-session cannot be combined");
    sessionId = await client.createSession("Agent Talk protocol PoC");
    print({ kind: "session_created", sessionId });
  }

  for (let round = 1; round <= rounds; round += 1) {
    const run = await client.startRun(prompt, {
      ...(sessionId === undefined ? {} : { sessionId }),
    });
    print({ kind: "run_started", round, rounds, run });
    let fullText = "";
    let outcome: TerminalAgentEventType | undefined;
    let lastSequence = 0;
    let blockedUserAction = false;
    let connectionLost = false;
    let stopAttempt: Promise<void> | undefined;
    let stopError: Error | undefined;
    let stopTimer: ReturnType<typeof setTimeout> | undefined;
    const controller = new AbortController();
    const requestStop = (reason: "timer" | "user_action_required"): void => {
      if (stopAttempt) return;
      print({ kind: "stop_requested", round, reason });
      stopAttempt = client.stopRun(run.runId).then(
        () => print({ kind: "stop_acknowledged", round }),
        (error: unknown) => {
          const message = error instanceof Error ? error.message : String(error);
          stopError = new Error(`Hermes stop failed: ${message}`);
          controller.abort();
        },
      );
    };
    if (stopAfterMs !== undefined) {
      stopTimer = setTimeout(() => requestStop("timer"), stopAfterMs);
    }

    try {
      for await (const event of client.streamRunEvents(run, controller.signal)) {
        print({ kind: "agent_event", round, event });
        if (event.requestId !== run.requestId) {
          throw new Error(`Hermes round ${round} returned the wrong request identity`);
        }
        if (event.sequence !== lastSequence + 1) {
          throw new Error(`Hermes round ${round} returned a non-contiguous sequence`);
        }
        lastSequence = event.sequence;
        if (event.type === "approval.required" || event.type === "clarification.required") {
          blockedUserAction = true;
          print({ kind: "blocked", round, reason: "user_action_required" });
          requestStop("user_action_required");
        }
        if (event.type === "connection.lost") connectionLost = true;
        if (event.type === "message.delta") {
          const payload = event.payload as { delta?: unknown };
          if (typeof payload.delta === "string") fullText += payload.delta;
        }
        if (event.type === "message.completed") {
          const payload = event.payload as { text?: unknown };
          if (typeof payload.text === "string" && payload.text) fullText = payload.text;
        }
        if (isTerminalAgentEventType(event.type)) outcome = event.type;
      }
    } catch (error) {
      if (stopError) throw stopError;
      throw error;
    } finally {
      if (stopTimer) clearTimeout(stopTimer);
    }
    if (stopAttempt) await stopAttempt;
    print({
      kind: "result",
      round,
      rounds,
      outcome: outcome ?? (connectionLost ? "uncertain" : "unknown"),
      blockedUserAction,
      connectionLost,
      fullText,
      speechText: createSpeechSummaryForOutcome(outcome, fullText) ?? null,
    });
    if (disconnectProbe) {
      if (!connectionLost || outcome !== undefined) {
        throw new Error("Hermes disconnect probe did not produce an uncertain connection loss");
      }
      continue;
    }
    if (outcome === undefined) {
      throw new Error(`Hermes round ${round} ended without a terminal event`);
    }
    if (approvalProbe && !blockedUserAction) {
      throw new Error("Hermes approval probe completed without a blocking approval request");
    }
    if (blockedUserAction && !approvalProbe) {
      throw new Error("Hermes requested interactive user action; run stopped without approval");
    }
    if (stopAfterMs !== undefined || approvalProbe) {
      if (outcome !== "request.cancelled" && outcome !== "request.interrupted") {
        throw new Error(`Hermes stop/approval probe ended as ${outcome}`);
      }
    } else if (outcome !== "request.completed") {
      throw new Error(`Hermes request ended as ${outcome}`);
    }
  }
  print({ kind: "summary", roundsCompleted: rounds, sessionId: sessionId ?? null });
}

function usage(): void {
  process.stdout.write(`Agent Talk protocol PoC\n\n`);
  process.stdout.write(`  doctor\n`);
  process.stdout.write(
    `  codex --prompt TEXT [--cwd PATH] [--thread ID] [--interrupt-after-ms N] [--approval-probe|--failure-probe]\n`,
  );
  process.stdout.write(
    `  hermes --prompt TEXT [--base-url URL] [--token-env NAME] [--session ID|--create-session] [--rounds N] [--stop-after-ms N] [--approval-probe|--disconnect-probe]\n`,
  );
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (args.command === "doctor") doctor();
  else if (args.command === "codex") await codex(args);
  else if (args.command === "hermes") await hermes(args);
  else usage();
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  print({ kind: "fatal", message });
  process.exitCode = 1;
});
