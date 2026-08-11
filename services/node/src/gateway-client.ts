import { createClient, type Client } from "@connectrpc/connect";
import { createGrpcTransport } from "@connectrpc/connect-node";
import { GatewayControlService } from "@agent-talk/protocol";

export interface GatewayControlClientOptions {
  idleConnectionTimeoutMs?: number;
}

/**
 * Creates the production Gateway client. The Connector explicitly disables the
 * RPC deadline for its long-lived stream; the finite default remains available
 * to any future short-lived call that shares this transport configuration.
 */
export function createGatewayControlClient(
  gatewayUrl: string,
  options: GatewayControlClientOptions = {},
): Client<typeof GatewayControlService> {
  const transport = createGrpcTransport({
    baseUrl: gatewayUrl,
    defaultTimeoutMs: 30_000,
    pingIntervalMs: 20_000,
    pingIdleConnection: true,
    pingTimeoutMs: 10_000,
    ...(options.idleConnectionTimeoutMs === undefined
      ? {}
      : { idleConnectionTimeoutMs: options.idleConnectionTimeoutMs }),
  });
  return createClient(GatewayControlService, transport);
}
