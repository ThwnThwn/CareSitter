import { isConsultationReceipt, requestKeyPattern, type ConsultationDraft, type ConsultationReceipt } from "./contract.ts";

const storageKey = "caresitter:consultation-retry";
const uncertainMessage = "Chưa xác nhận được yêu cầu đã lưu. Bạn có thể bấm gửi lại để kiểm tra, hệ thống sẽ tránh tạo trùng.";

export class ConsultationSubmission {
  private pending: Promise<ConsultationReceipt> | null = null;
  private attempt: { fingerprint: string; key: string } | null = null;
  private readonly request: typeof fetch;
  private readonly storage?: Pick<Storage, "getItem" | "setItem">;

  constructor(request: typeof fetch = fetch, storage?: Pick<Storage, "getItem" | "setItem">) {
    this.request = request;
    this.storage = storage;
  }

  submit(draft: ConsultationDraft): Promise<ConsultationReceipt> {
    if (this.pending) return this.pending;
    const operation = this.send(draft);
    this.pending = operation;
    void operation.finally(() => { this.pending = null; }).catch(() => {});
    return operation;
  }

  private async send(draft: ConsultationDraft): Promise<ConsultationReceipt> {
    const body = JSON.stringify(draft);
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body));
    const fingerprint = Array.from(new Uint8Array(digest), (value) => value.toString(16).padStart(2, "0")).join("");
    if (!this.attempt) {
      try {
        const stored = JSON.parse(this.storage?.getItem(storageKey) ?? "null");
        if (stored && typeof stored.fingerprint === "string" && typeof stored.key === "string" && requestKeyPattern.test(stored.key))
          this.attempt = stored;
      } catch { /* Private browsing may disable session storage. */ }
    }
    if (this.attempt?.fingerprint !== fingerprint) {
      this.attempt = { fingerprint, key: crypto.randomUUID() };
      try { this.storage?.setItem(storageKey, JSON.stringify(this.attempt)); } catch { /* Memory retry remains available. */ }
    }
    let response: Response;
    try {
      response = await this.request("/api/consultation-requests", {
        method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": this.attempt.key },
        body, signal: AbortSignal.timeout(15000),
      });
    } catch { throw new Error(uncertainMessage); }
    const result: unknown = await response.json().catch(() => null);
    if (!response.ok) {
      const message = result && typeof result === "object" && "error" in result &&
          typeof result.error === "string" ? result.error : uncertainMessage;
      throw new Error(message);
    }
    if (!isConsultationReceipt(result) || result.id !== this.attempt.key)
      throw new Error(uncertainMessage);
    return result;
  }
}
