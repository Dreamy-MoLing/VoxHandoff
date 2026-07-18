const fencedCode = /```[\s\S]*?```/g;
const markdownTableLine = /^\s*\|.*\|\s*$/gm;
const likelySecret = /\b(?:sk-[A-Za-z0-9_-]{12,}|Bearer\s+[A-Za-z0-9._~-]{12,}|(?:api[_-]?key|token|secret)\s*[:=]\s*\S+)/gi;
const longPath = /(?:[A-Za-z]:\\|\/)[^\s，。！？]{28,}/g;

export interface SpeechSummaryOptions {
  maxCharacters?: number;
}

export function createDeterministicSpeechSummary(
  fullReply: string,
  options: SpeechSummaryOptions = {},
): string {
  const maxCharacters = options.maxCharacters ?? 120;
  const cleaned = fullReply
    .replace(fencedCode, " ")
    .replace(markdownTableLine, " ")
    .replace(likelySecret, "[敏感信息已隐藏]")
    .replace(longPath, "[路径已省略]")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/[*_`>~-]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (!cleaned) return "任务已结束，请查看文字结果。";

  const sentences = cleaned.match(/[^。！？.!?]+[。！？.!?]?/g) ?? [cleaned];
  const preferred = sentences.slice(-3).join("").trim();
  if (preferred.length <= maxCharacters) return preferred;

  const clipped = preferred.slice(0, Math.max(1, maxCharacters - 1)).trimEnd();
  return `${clipped}…`;
}

export function createSpeechSummaryForOutcome(
  outcome: TerminalAgentEventType | undefined,
  fullReply: string,
  options: SpeechSummaryOptions = {},
): string | undefined {
  if (outcome !== "request.completed") return undefined;
  return createDeterministicSpeechSummary(fullReply, options);
}
import type { TerminalAgentEventType } from "./model.js";
