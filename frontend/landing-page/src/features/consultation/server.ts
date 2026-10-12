import { isConsultationReceipt, parseConsultation, requestKeyPattern } from "./contract.ts";

const json = (body: unknown, status: number) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

export async function forwardConsultation(
  request: Request, apiBase: string | undefined, fetchBackend: typeof fetch = fetch,
): Promise<Response> {
  if (request.headers.get("origin") !== new URL(request.url).origin)
    return json({ error: "Nguồn gửi yêu cầu không hợp lệ." }, 403);
  const key = request.headers.get("Idempotency-Key") ?? "";
  if (!requestKeyPattern.test(key))
    return json({ error: "Mã yêu cầu không hợp lệ. Vui lòng tải lại trang." }, 400);
  if (!apiBase) return json({ error: "Kênh tư vấn chưa sẵn sàng. Vui lòng thử lại sau." }, 503);
  let raw: string;
  try { raw = await request.text(); } catch { return json({ error: "Không đọc được yêu cầu." }, 400); }
  if (new TextEncoder().encode(raw).length > 8192)
    return json({ error: "Nội dung yêu cầu quá dài." }, 413);
  let draft;
  try { draft = parseConsultation(JSON.parse(raw)); } catch { draft = null; }
  if (!draft) return json({ error: "Vui lòng kiểm tra họ tên, điện thoại, ngày và nội dung tư vấn." }, 400);
  try {
    const endpoint = new URL("/api/v1/consultation-requests", apiBase);
    if (!["http:", "https:"].includes(endpoint.protocol)) throw new Error("Invalid backend URL");
    const response = await fetchBackend(endpoint, {
      method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": key },
      body: JSON.stringify(draft), cache: "no-store", redirect: "error",
      signal: AbortSignal.timeout(12000),
    });
    const payload: unknown = await response.json().catch(() => null);
    if (response.status === 429) return json({ error: "Bạn gửi yêu cầu quá nhanh. Vui lòng thử lại sau ít phút." }, 429);
    if (response.status === 409) return json({ error: "Mã yêu cầu đã dùng cho nội dung khác. Vui lòng tải lại trang và thử lại." }, 409);
    if (response.status === 400 || response.status === 422)
      return json({ error: "Thông tin chưa hợp lệ hoặc ngày đã qua. Vui lòng kiểm tra lại." }, 400);
    if (!response.ok || !isConsultationReceipt(payload) || payload.id !== key)
      return json({ error: "Chưa xác nhận được yêu cầu đã lưu. Vui lòng thử gửi lại." }, 502);
    return json({ id: payload.id, createdAt: payload.createdAt }, 200);
  } catch {
    return json({ error: "Chưa kết nối được máy chủ. Vui lòng thử gửi lại để xác nhận yêu cầu." }, 502);
  }
}
