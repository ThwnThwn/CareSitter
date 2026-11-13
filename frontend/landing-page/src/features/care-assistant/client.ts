import { parseAssistantResponse, parseMessage, type AssistantReply } from "./contract.ts";

export async function requestRecommendation(
  message: string, signal: AbortSignal, fetcher: typeof fetch = fetch,
): Promise<AssistantReply> {
  const normalized = parseMessage({ message });
  if (!normalized) throw new Error("Bạn hãy nhập câu hỏi từ 3–1200 ký tự.");
  const response = await fetcher("/api/care-assistant", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: normalized }),
    signal,
  });
  const payload: unknown = await response.json().catch(() => null);
  const result = parseAssistantResponse(payload);
  if (!response.ok || !result) throw new Error("Không thể nhận gợi ý lúc này. Vui lòng thử lại.");
  return result;
}
