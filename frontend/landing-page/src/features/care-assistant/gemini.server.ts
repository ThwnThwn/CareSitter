import { GoogleGenAI } from "@google/genai";
import { serviceCategories } from "./contract.ts";
import type { GenerateAssistantReply } from "./server.ts";

const assistantReplySchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    intent: {
      type: "string",
      enum: ["recommendation", "explanation", "clarification"],
    },
    title: { type: "string", minLength: 1, maxLength: 160 },
    serviceCategory: {
      type: "string",
      enum: [...serviceCategories],
      nullable: true,
    },
    hours: { type: "integer", minimum: 2, maximum: 12, nullable: true },
    summary: { type: "string", minLength: 1, maxLength: 2000 },
    nextStep: { type: "string", minLength: 1, maxLength: 1000 },
  },
  required: ["intent", "title", "serviceCategory", "hours", "summary", "nextStep"],
};

const instructions = `Bạn là trợ lý giới thiệu CareSitter trên landing page. Mục tiêu chính là giúp gia đình hiểu CareSitter hoạt động thế nào và xác định bước tiếp theo phù hợp, không ép mọi câu hỏi thành một đề xuất dịch vụ.

Thông tin được phép giải thích:
- CareSitter là nền tảng kết nối gia đình với caregiver đã xác minh cho nhu cầu hỗ trợ phi y tế tại nhà.
- Quy trình cơ bản: gia đình mô tả nhu cầu; xem hồ sơ, kỹ năng, mức phí và lựa chọn caregiver; đặt ca; theo dõi các mốc quan trọng và cập nhật trong ứng dụng; liên hệ hỗ trợ khi cần.
- Ba nhóm hỗ trợ hiện có: chăm sóc người cao tuổi, đồng hành sinh hoạt và hỗ trợ đi lại.
- CareSitter không phải cơ sở y tế, không chẩn đoán, kê đơn hoặc thay thế dịch vụ cấp cứu.

Chọn đúng một intent:
1. "explanation": người dùng hỏi CareSitter là gì, hoạt động ra sao, caregiver được chọn thế nào, quy trình đặt/theo dõi ca hoặc các câu hỏi tương tự. Giải thích trực tiếp, dễ hiểu. serviceCategory và hours phải là null.
2. "clarification": nội dung không rõ nghĩa, đùa, quá mơ hồ hoặc không đủ dữ kiện. Không tự đoán. Nói lịch sự rằng bạn chưa hiểu và đưa 2–3 ví dụ cụ thể người dùng có thể hỏi. serviceCategory và hours phải là null.
3. "recommendation": người dùng mô tả một nhu cầu chăm sóc đủ rõ. Chọn một serviceCategory và ước lượng hours từ 2 đến 12.

Quy tắc chọn dịch vụ khi intent là recommendation:
- Chăm sóc người cao tuổi: hỗ trợ sinh hoạt, ăn uống, nhắc lịch, trò chuyện, theo dõi trong ngày.
- Đồng hành sinh hoạt: ở bên, trò chuyện, hoạt động nhẹ và hỗ trợ sinh hoạt thường ngày.
- Hỗ trợ đi lại: đưa đón, đi khám hoặc hỗ trợ di chuyển an toàn.

Luôn trả lời ngắn, ấm áp và thực tế bằng tiếng Việt. Không hứa caregiver cụ thể, không tự xác nhận booking, không bịa chính sách hoặc giá. Nếu là tình huống khẩn cấp hoặc cần can thiệp y tế, hướng dẫn liên hệ cấp cứu/cơ sở y tế; không đưa lời khuyên y khoa. Không lặp lại dữ liệu nhạy cảm trong câu trả lời.`;

const defaultModels = ["gemini-3.8-flash", "gemini-3.5-flash-lite"] as const;
const transientStatuses = new Set([408, 429, 500, 502, 503, 504]);

type GenerateForModel<T> = (model: string, signal: AbortSignal) => Promise<T>;

interface FallbackOptions {
  models?: readonly string[];
  retryDelayMs?: number;
  attemptTimeoutMs?: number;
}

function errorStatus(error: unknown): number | null {
  if (typeof error !== "object" || error === null) return null;
  const status = "status" in error ? error.status : "code" in error ? error.code : null;
  return typeof status === "number" ? status : null;
}

function isTransient(error: unknown): boolean {
  const status = errorStatus(error);
  if (status !== null) return transientStatuses.has(status);
  return error instanceof TypeError ||
    (error instanceof DOMException && error.name === "AbortError");
}

function waitForRetry(delayMs: number, signal: AbortSignal): Promise<void> {
  if (delayMs <= 0) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, delayMs);
    signal.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(signal.reason);
    }, { once: true });
  });
}

export async function generateWithGeminiFallback<T>(
  generate: GenerateForModel<T>,
  signal: AbortSignal,
  options: FallbackOptions = {},
): Promise<T> {
  const models = options.models ?? defaultModels;
  const retryDelayMs = options.retryDelayMs ?? 250;
  const attemptTimeoutMs = options.attemptTimeoutMs ?? 6_000;
  let lastError: unknown = new Error("No Gemini model configured");

  for (const [modelIndex, model] of models.entries()) {
    const maxAttempts = modelIndex === 0 ? 2 : 1;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const attemptSignal = AbortSignal.any([
          signal,
          AbortSignal.timeout(attemptTimeoutMs),
        ]);
        return await generate(model, attemptSignal);
      } catch (error) {
        lastError = error;
        const status = errorStatus(error);
        if (signal.aborted || status === 401 || status === 403) throw error;
        if (attempt + 1 < maxAttempts && isTransient(error)) {
          await waitForRetry(retryDelayMs, signal);
          continue;
        }
        break;
      }
    }
  }

  throw lastError;
}

export function createGeminiRecommendation(apiKey: string): GenerateAssistantReply {
  return async (message, signal) => {
    const ai = new GoogleGenAI({ apiKey });
    return generateWithGeminiFallback(async (model, attemptSignal) => {
      const response = await ai.models.generateContent({
        model,
        contents: message,
        config: {
          abortSignal: attemptSignal,
          systemInstruction: instructions,
          responseMimeType: "application/json",
          responseSchema: assistantReplySchema,
        },
      });

      const text = response.text;
      if (!text) {
        throw new Error("Empty response from Gemini");
      }
      return JSON.parse(text) as unknown;
    }, signal);
  };
}
