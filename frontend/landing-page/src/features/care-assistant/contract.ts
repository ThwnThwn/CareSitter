export const serviceCategories = [
  "Chăm sóc người cao tuổi",
  "Đồng hành sinh hoạt",
  "Hỗ trợ đi lại",
] as const;

export const assistantIntents = ["recommendation", "explanation", "clarification"] as const;

export interface Recommendation {
  serviceCategory: (typeof serviceCategories)[number];
  hours: number;
  summary: string;
  nextStep: string;
}

interface AssistantReplyBase {
  intent: (typeof assistantIntents)[number];
  title: string;
  summary: string;
  nextStep: string;
}

export interface RecommendationReply extends AssistantReplyBase, Recommendation {
  intent: "recommendation";
}

export interface InformationalReply extends AssistantReplyBase {
  intent: "explanation" | "clarification";
  serviceCategory: null;
  hours: null;
}

export type AssistantReply = RecommendationReply | InformationalReply;

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseMessage(value: unknown): string | null {
  if (!isObject(value) || typeof value.message !== "string") return null;
  const message = value.message.trim();
  return message.length >= 3 && message.length <= 1200 ? message : null;
}

export function parseRecommendation(value: unknown): Recommendation | null {
  if (!isObject(value)) return null;
  const { serviceCategory, hours, summary, nextStep } = value;
  const category = serviceCategories.find((item) => item === serviceCategory);
  if (!category || typeof hours !== "number" || !Number.isInteger(hours) || hours < 2 || hours > 12)
    return null;
  if (typeof summary !== "string" || !summary.trim() || summary.length > 2000 ||
      typeof nextStep !== "string" || !nextStep.trim() || nextStep.length > 1000) return null;
  return { serviceCategory: category, hours, summary: summary.trim(), nextStep: nextStep.trim() };
}

function parseText(value: unknown, maximum: number): string | null {
  return typeof value === "string" && value.trim() && value.length <= maximum ? value.trim() : null;
}

export function parseAssistantReply(value: unknown): AssistantReply | null {
  if (!isObject(value)) return null;
  const intent = assistantIntents.find((item) => item === value.intent);
  const title = parseText(value.title, 160);
  const summary = parseText(value.summary, 2000);
  const nextStep = parseText(value.nextStep, 1000);
  if (!intent || !title || !summary || !nextStep) return null;

  if (intent === "recommendation") {
    const recommendation = parseRecommendation(value);
    return recommendation ? { intent, title, ...recommendation } : null;
  }

  if (value.serviceCategory !== null || value.hours !== null) return null;
  return { intent, title, summary, nextStep, serviceCategory: null, hours: null };
}

export function parseAssistantResponse(value: unknown): AssistantReply | null {
  if (!isObject(value)) return null;
  return parseAssistantReply(value.reply);
}
