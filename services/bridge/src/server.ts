import { readFileSync } from "node:fs";
import { timingSafeEqual } from "node:crypto";
import { createServer, type Server } from "node:https";
import type { IncomingMessage, ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

import type { BridgeConfig } from "./config.js";
import { healthSnapshot, readinessSnapshot, type BridgeReadinessCheck } from "./health.js";
import { HttpRequestError, isRecord, readJsonBody, stringField, writeError, writeJson } from "./http.js";
import { PairingError, PairingService } from "./pairing.js";
import { CredentialError, DeviceCredentialService } from "./credentials.js";

export interface BridgeApplicationOptions {
  readinessChecks?: readonly BridgeReadinessCheck[];
  pairing?: PairingService;
  credentials?: DeviceCredentialService;
}

export class CompanionBridgeApplication {
  readonly #config: BridgeConfig;
  readonly #readinessChecks: readonly BridgeReadinessCheck[];
  readonly #pairing: PairingService | undefined;
  readonly #credentials: DeviceCredentialService | undefined;

  constructor(config: BridgeConfig, options: BridgeApplicationOptions = {}) {
    this.#config = config;
    this.#readinessChecks = options.readinessChecks ?? [{ name: "tls", ready: () => true }];
    this.#pairing = options.pairing;
    this.#credentials = options.credentials;
  }

  async handle(request: IncomingMessage, response: ServerResponse): Promise<void> {
    const method = request.method ?? "GET";
    const path = new URL(request.url ?? "/", "https://bridge.invalid").pathname;
    try {
      if (method === "GET" && path === "/healthz") {
        writeJson(response, 200, healthSnapshot(this.#config.version));
        return;
      }
      if (method === "GET" && path === "/readyz") {
        const snapshot = readinessSnapshot(this.#config.version, this.#readinessChecks);
        writeJson(response, snapshot.status === "ready" ? 200 : 503, snapshot);
        return;
      }
      if (this.#pairing !== undefined && method === "POST" && path === "/v1/pairing/sessions") {
        authorizeHost(request, this.#config);
        writeJson(response, 201, await this.#pairing.createQr());
        return;
      }
      if (this.#pairing !== undefined && method === "POST" && path === "/v1/pairing/exchange") {
        const body = await readJsonBody(request, this.#config.maxRequestBytes);
        if (!isRecord(body)) throw new HttpRequestError(400, "request_invalid", "The request body is invalid.");
        writeJson(response, 200, await this.#pairing.exchange({
          serverId: stringField(body, "server_id") ?? "",
          pairingSessionId: stringField(body, "pairing_session_id") ?? "",
          pairingToken: stringField(body, "pairing_token") ?? "",
          deviceName: stringField(body, "device_name") ?? "",
          devicePublicKeySpki: stringField(body, "device_public_key_spki") ?? "",
        }));
        return;
      }
      const requestComplete = path.match(/^\/v1\/pairing\/requests\/([^/]+)\/complete$/u);
      if (this.#pairing !== undefined && method === "POST" && requestComplete?.[1] !== undefined) {
        const body = await readJsonBody(request, this.#config.maxRequestBytes);
        if (!isRecord(body)) throw new HttpRequestError(400, "request_invalid", "The request body is invalid.");
        writeJson(response, 201, await this.#pairing.complete(
          decodePathPart(requestComplete[1]),
          stringField(body, "device_signature") ?? "",
        ));
        return;
      }
      if (this.#pairing !== undefined && method === "GET" && path === "/v1/pairing/requests") {
        authorizeHost(request, this.#config);
        writeJson(response, 200, { requests: await this.#pairing.pendingRequests() });
        return;
      }
      const sessionCancel = path.match(/^\/v1\/pairing\/sessions\/([^/]+)\/cancel$/u);
      if (this.#pairing !== undefined && method === "POST" && sessionCancel?.[1] !== undefined) {
        authorizeHost(request, this.#config);
        await this.#pairing.cancelSession(decodePathPart(sessionCancel[1]));
        writeJson(response, 200, { cancelled: true });
        return;
      }
      const requestCancel = path.match(/^\/v1\/pairing\/requests\/([^/]+)\/cancel$/u);
      if (this.#pairing !== undefined && method === "POST" && requestCancel?.[1] !== undefined) {
        authorizeHost(request, this.#config);
        await this.#pairing.cancelRequest(decodePathPart(requestCancel[1]));
        writeJson(response, 200, { cancelled: true });
        return;
      }
      const requestConfirm = path.match(/^\/v1\/pairing\/requests\/([^/]+)\/confirm$/u);
      if (this.#pairing !== undefined && method === "POST" && requestConfirm?.[1] !== undefined) {
        authorizeHost(request, this.#config);
        const body = await readJsonBody(request, this.#config.maxRequestBytes);
        if (!isRecord(body)) throw new HttpRequestError(400, "request_invalid", "The request body is invalid.");
        writeJson(response, 200, await this.#pairing.confirm(
          decodePathPart(requestConfirm[1]),
          stringField(body, "device_name") ?? "",
          stringField(body, "confirmation_code") ?? "",
        ));
        return;
      }
      if (this.#credentials !== undefined && method === "GET" && path === "/v1/devices") {
        authorizeHost(request, this.#config);
        writeJson(response, 200, { devices: await this.#credentials.listDevices() });
        return;
      }
      const deviceRevoke = path.match(/^\/v1\/devices\/([^/]+)\/revoke$/u);
      if (this.#credentials !== undefined && method === "POST" && deviceRevoke?.[1] !== undefined) {
        authorizeHost(request, this.#config);
        const revoked = await this.#credentials.revokeDevice(decodePathPart(deviceRevoke[1]));
        writeJson(response, 200, { revoked });
        return;
      }
      writeError(response, 404, "not_found", "The requested bridge endpoint was not found.");
    } catch (error) {
      if (error instanceof HttpRequestError) {
        writeError(response, error.status, error.code, error.message);
        return;
      }
      if (error instanceof PairingError) {
        writeError(response, error.status, error.code, error.message);
        return;
      }
      if (error instanceof CredentialError) {
        writeError(response, error.status, error.code, error.message);
        return;
      }
      writeError(response, 500, "bridge_internal_error", "The bridge could not complete the request.");
    }
  }
}

function authorizeHost(request: IncomingMessage, config: BridgeConfig): void {
  if (config.hostAdminToken !== undefined) {
    const header = request.headers["x-bridge-host-authorization"];
    const expected = `Bearer ${config.hostAdminToken}`;
    if (typeof header !== "string" || !constantTimeHeaderEqual(header, expected)) {
      throw new HttpRequestError(401, "host_authentication_required", "Host authentication is required.");
    }
    return;
  }
  const remoteAddress = request.socket.remoteAddress;
  if (remoteAddress !== undefined && !isLoopback(remoteAddress)) {
    throw new HttpRequestError(403, "host_access_denied", "Host control endpoints are local-only.");
  }
}

function constantTimeHeaderEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left, "utf8");
  const rightBytes = Buffer.from(right, "utf8");
  if (leftBytes.byteLength !== rightBytes.byteLength) return false;
  return timingSafeEqual(leftBytes, rightBytes);
}

function isLoopback(address: string): boolean {
  return address === "127.0.0.1" || address === "::1" || address === "::ffff:127.0.0.1";
}

function decodePathPart(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    throw new HttpRequestError(400, "request_invalid", "The request path is invalid.");
  }
}

export function createBridgeServer(config: BridgeConfig, application = new CompanionBridgeApplication(config)): Server {
  const server = createServer(
    {
      key: readFileSync(config.tlsKeyFile),
      cert: readFileSync(config.tlsCertFile),
      minVersion: "TLSv1.2",
      maxVersion: "TLSv1.3",
    },
    (request, response) => {
      void application.handle(request, response);
    },
  );
  server.headersTimeout = 10_000;
  server.requestTimeout = 30_000;
  server.maxHeadersCount = 64;
  return server;
}

export async function listenBridgeServer(server: Server, config: BridgeConfig): Promise<AddressInfo> {
  await new Promise<void>((resolve, reject) => {
    const onError = (error: Error) => {
      server.off("listening", onListening);
      reject(error);
    };
    const onListening = () => {
      server.off("error", onError);
      resolve();
    };
    server.once("error", onError);
    server.once("listening", onListening);
    server.listen(config.listenPort, config.listenHost);
  });
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("The bridge listener did not expose a socket address");
  return address;
}

export function closeBridgeServer(server: { close(callback: (error?: Error) => void): void }): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error) => (error === undefined ? resolve() : reject(error)));
  });
}
