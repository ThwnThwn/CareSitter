import { parseAssistantResponse, parseMessage, type Recommendation } from "./contract.ts";

export async function requestRecommendation(
  message: string, signal: AbortSignal, fetcher: typeof fetch = fetch,
): Promise<Recommendation> {
  const normalized = parseMessage({ message });
  if (!normalized) throw new Error("Bạn hãy mô tả nhu cầu trong khoảng 8–1200 ký tự.");
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
