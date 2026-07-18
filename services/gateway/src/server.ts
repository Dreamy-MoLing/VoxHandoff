import { createServer, createSecureServer, type Http2SecureServer, type Http2Server, type SecureServerOptions } from "node:http2";
import type { AddressInfo } from "node:net";

import type { ServiceImpl } from "@connectrpc/connect";
import { connectNodeAdapter } from "@connectrpc/connect-node";
import { GatewayControlService } from "@agent-talk/protocol";

export interface GatewayServerOptions {
  controlService: ServiceImpl<typeof GatewayControlService>;
  host: string;
  port: number;
  tls?: SecureServerOptions;
  allowInsecureLoopbackForTests?: boolean;
}

export interface RunningGatewayServer {
  address: AddressInfo;
  close(): Promise<void>;
}

function isLiteralLoopback(host: string): boolean {
  return host === "127.0.0.1" || host === "::1";
}

function validateServerOptions(options: GatewayServerOptions): void {
  if (!Number.isInteger(options.port) || options.port < 0 || options.port > 65_535) {
    throw new Error("Gateway port must be an integer between 0 and 65535");
  }
  if (options.tls === undefined) {
    if (!options.allowInsecureLoopbackForTests || !isLiteralLoopback(options.host)) {
      throw new Error("Insecure Gateway transport is restricted to explicit literal loopback test mode");
    }
    return;
  }
  if (options.tls.key === undefined || options.tls.cert === undefined) {
    throw new Error("Gateway TLS requires both key and certificate");
  }
}

export async function startGatewayServer(options: GatewayServerOptions): Promise<RunningGatewayServer> {
  validateServerOptions(options);
  const handler = connectNodeAdapter({
    routes: (router) => router.service(GatewayControlService, options.controlService),
  });
  const server: Http2Server | Http2SecureServer =
    options.tls === undefined ? createServer(handler) : createSecureServer(options.tls, handler);

  await new Promise<void>((resolve, reject) => {
    const onError = (error: Error) => reject(error);
    server.once("error", onError);
    server.listen(options.port, options.host, () => {
      server.off("error", onError);
      resolve();
    });
  });

  const address = server.address();
  if (address === null || typeof address === "string") {
    await closeServer(server);
    throw new Error("Gateway did not bind a TCP address");
  }
  return {
    address,
    close: () => closeServer(server),
  };
}

function closeServer(server: Http2Server | Http2SecureServer): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error === undefined) {
        resolve();
      } else {
        reject(error);
      }
    });
  });
}
