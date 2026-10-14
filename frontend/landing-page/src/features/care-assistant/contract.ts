export const serviceCategories = [
  "Chăm sóc người cao tuổi",
  "Đồng hành sinh hoạt",
  "Hỗ trợ đi lại",
] as const;

export interface Recommendation {
  serviceCategory: (typeof serviceCategories)[number];
  hours: number;
  summary: string;
  nextStep: string;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseMessage(value: unknown): string | null {
  if (!isObject(value) || typeof value.message !== "string") return null;
  const message = value.message.trim();
  return message.length >= 8 && message.length <= 1200 ? message : null;
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

export function parseAssistantResponse(value: unknown): Recommendation | null {
  return isObject(value) ? parseRecommendation(value.recommendation) : null;
}
