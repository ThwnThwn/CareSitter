import { parseMessage, parseRecommendation } from "./contract.ts";

export type GenerateRecommendation = (message: string, signal: AbortSignal) => Promise<unknown>;
const json = (body: unknown, status: number) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

export async function handleAssistantRequest(
  request: Request,
  generate: GenerateRecommendation | undefined,
): Promise<Response> {
  let message: string | null;
  try { message = parseMessage(await request.json()); }
  catch { message = null; }
  if (!message)
    return json({ error: "Bạn hãy mô tả nhu cầu trong khoảng 8–1200 ký tự." }, 400);
  if (!generate)
    return json({ error: "Trợ lý chưa sẵn sàng. Bạn có thể gửi nhu cầu qua form đặt ca." }, 503);
  try {
    const signal = AbortSignal.any([request.signal, AbortSignal.timeout(20000)]);
    const recommendation = parseRecommendation(await generate(message, signal));
    if (!recommendation) throw new Error("Invalid recommendation");
    return json({ recommendation }, 200);
  } catch {
    return json({ error: "Trợ lý đang bận một chút. Bạn có thể gửi nhu cầu qua form đặt ca." }, 502);
  }
}
