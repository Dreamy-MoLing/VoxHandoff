import { readFileSync } from "node:fs";
import { createServer, type Server } from "node:https";
import type { IncomingMessage, ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

import type { BridgeConfig } from "./config.js";
import { healthSnapshot, readinessSnapshot, type BridgeReadinessCheck } from "./health.js";
import { HttpRequestError, writeError, writeJson } from "./http.js";

export interface BridgeApplicationOptions {
  readinessChecks?: readonly BridgeReadinessCheck[];
}

export class CompanionBridgeApplication {
  readonly #config: BridgeConfig;
  readonly #readinessChecks: readonly BridgeReadinessCheck[];

  constructor(config: BridgeConfig, options: BridgeApplicationOptions = {}) {
    this.#config = config;
    this.#readinessChecks = options.readinessChecks ?? [{ name: "tls", ready: () => true }];
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
      writeError(response, 404, "not_found", "The requested bridge endpoint was not found.");
    } catch (error) {
      if (error instanceof HttpRequestError) {
        writeError(response, error.status, error.code, error.message);
        return;
      }
      writeError(response, 500, "bridge_internal_error", "The bridge could not complete the request.");
    }
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
