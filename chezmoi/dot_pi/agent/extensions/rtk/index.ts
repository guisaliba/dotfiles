import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (typeof command !== "string" || command.trim() === "") return;
    if (command.startsWith("rtk ")) return;
    if (command.includes("RTK_DISABLED=1")) return;

    try {
      const { stdout } = await execFileAsync("rtk", ["rewrite", command], {
        signal: ctx.signal,
      });

      const rewritten = stdout.trim();

      if (rewritten && rewritten !== command) {
        event.input.command = rewritten;
        ctx.ui.setStatus("rtk", "rtk");
      }
    } catch {
      return;
    }
  });
}
