import { GoogleGenAI } from "@google/genai";
import { serviceCategories } from "./contract.ts";
import type { GenerateRecommendation } from "./server.ts";

const recommendationSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    serviceCategory: {
      type: "string",
      enum: [...serviceCategories],
    },
    hours: { type: "integer", minimum: 2, maximum: 12 },
    summary: { type: "string", minLength: 1, maxLength: 2000 },
    nextStep: { type: "string", minLength: 1, maxLength: 1000 },
  },
  required: ["serviceCategory", "hours", "summary", "nextStep"],
};

const instructions = `Bạn là trợ lý CareSitter trên landing page. CareSitter kết nối gia đình với người chăm sóc tại nhà cho các nhu cầu phi y tế: chăm sóc người cao tuổi, đồng hành sinh hoạt và hỗ trợ đi lại.

Nhiệm vụ: đọc mô tả nhu cầu bằng tiếng Việt, chọn đúng một loại hỗ trợ và ước lượng số giờ ban đầu từ 2 đến 12. Trả lời ngắn, ấm áp, thực tế. Không chẩn đoán bệnh, không đưa lời khuyên y khoa, không hứa caregiver cụ thể, không tự xác nhận booking. Nếu người dùng mô tả tình huống khẩn cấp hoặc cần can thiệp y tế, hướng dẫn họ gọi dịch vụ khẩn cấp hoặc cơ sở y tế phù hợp và vẫn trả về lựa chọn thận trọng nhất.

Quy tắc chọn dịch vụ:
- Chăm sóc người cao tuổi: hỗ trợ sinh hoạt, ăn uống, nhắc lịch, trò chuyện, theo dõi trong ngày.
- Đồng hành sinh hoạt: ở bên, trò chuyện, hoạt động nhẹ và hỗ trợ sinh hoạt thường ngày.
- Hỗ trợ đi lại: đưa đón, đi khám hoặc hỗ trợ di chuyển an toàn.

Không lặp lại dữ liệu nhạy cảm trong câu trả lời. Chỉ dùng thông tin người dùng vừa nhập.`;

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

export function createGeminiRecommendation(apiKey: string): GenerateRecommendation {
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
          responseSchema: recommendationSchema,
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
