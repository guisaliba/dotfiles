import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { execFile } from "node:child_process";
import { readdir, realpath } from "node:fs/promises";
import { dirname, join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

type TransportCommand = {
  command: string;
  args: string[];
};

let cachedTransportCommand: Promise<TransportCommand> | undefined;

async function resolveCavememTransportCommand(): Promise<TransportCommand> {
  const { stdout } = await execFileAsync("which", ["cavemem"]);
  const cavememBin = stdout.trim().split("\n")[0];
  const realBin = await realpath(cavememBin);
  const distDir = dirname(realBin);
  const entries = await readdir(distDir);
  const serverEntry = entries.find((entry) => /^server-.*\.js$/.test(entry));

  if (!serverEntry) {
    return { command: "cavemem", args: ["mcp"] };
  }

  // cavemem@0.1.3's `cavemem mcp` command imports the server module but does
  // not start it. Executing the bundled server file directly starts MCP stdio.
  return { command: process.execPath, args: [join(distDir, serverEntry)] };
}

async function callCavememTool(name: string, args: Record<string, JsonValue>, signal?: AbortSignal) {
  const transportCommand = await (cachedTransportCommand ??= resolveCavememTransportCommand());
  const transport = new StdioClientTransport(transportCommand);

  const client = new Client(
    { name: "pi-cavemem-bridge", version: "0.1.0" },
    { capabilities: {} },
  );

  try {
    if (signal?.aborted) throw new Error("aborted");
    await client.connect(transport);
    return await client.callTool({ name, arguments: args });
  } finally {
    await client.close().catch(() => undefined);
  }
}

function stringifyResult(result: unknown): string {
  return JSON.stringify(result, null, 2);
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "cavemem_search",
    label: "Cavemem Search",
    description: "Search cavemem memory using compact progressive-disclosure results.",
    parameters: Type.Object({
      query: Type.String({ description: "Natural-language search query." }),
      limit: Type.Optional(Type.Number({ description: "Maximum number of results." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("search", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "search" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_list_sessions",
    label: "Cavemem List Sessions",
    description: "List recent cavemem sessions in reverse chronological order.",
    parameters: Type.Object({
      limit: Type.Optional(Type.Number({ description: "Maximum number of sessions." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("list_sessions", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "list_sessions" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_timeline",
    label: "Cavemem Timeline",
    description: "Get chronological observation identifiers for a cavemem session.",
    parameters: Type.Object({
      session_id: Type.String({ description: "Cavemem session id." }),
      around_id: Type.Optional(Type.Number({ description: "Observation id to center around." })),
      limit: Type.Optional(Type.Number({ description: "Maximum number of observations." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("timeline", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "timeline" },
      };
    },
  });

  pi.registerTool({
    name: "cavemem_get_observations",
    label: "Cavemem Get Observations",
    description: "Fetch full cavemem observation bodies by id.",
    parameters: Type.Object({
      ids: Type.Array(Type.Number(), { description: "Observation ids." }),
      expand: Type.Optional(Type.Boolean({ description: "Return expanded human-readable content." })),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await callCavememTool("get_observations", params as Record<string, JsonValue>, signal);
      return {
        content: [{ type: "text", text: stringifyResult(result) }],
        details: { tool: "get_observations" },
      };
    },
  });

  pi.registerCommand("cavemem-status", {
    description: "Show cavemem status.",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Run `cavemem status` in a shell for the full wiring dashboard.", "info");
    },
  });
}
