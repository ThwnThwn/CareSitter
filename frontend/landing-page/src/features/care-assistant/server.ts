import { parseAssistantReply, parseMessage } from "./contract.ts";

export type GenerateAssistantReply = (message: string, signal: AbortSignal) => Promise<unknown>;
const json = (body: unknown, status: number) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

export async function handleAssistantRequest(
  request: Request,
  generate: GenerateAssistantReply | undefined,
): Promise<Response> {
  let message: string | null;
  try { message = parseMessage(await request.json()); }
  catch { message = null; }
  if (!message)
    return json({ error: "Bạn hãy nhập câu hỏi từ 3–1200 ký tự." }, 400);
  if (!generate)
    return json({ error: "Trợ lý chưa sẵn sàng. Bạn có thể gửi nhu cầu qua form đặt ca." }, 503);
  try {
    const signal = AbortSignal.any([request.signal, AbortSignal.timeout(20000)]);
    const reply = parseAssistantReply(await generate(message, signal));
    if (!reply) throw new Error("Invalid assistant reply");
    return json({ reply }, 200);
  } catch {
    return json({ error: "Trợ lý đang bận một chút. Bạn có thể gửi nhu cầu qua form đặt ca." }, 502);
  }
}
