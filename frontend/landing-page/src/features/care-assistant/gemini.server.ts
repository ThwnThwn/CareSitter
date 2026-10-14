import { GoogleGenAI } from "@google/genai";
import { serviceCategories } from "./contract";
import type { GenerateRecommendation } from "./server";

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

export function createGeminiRecommendation(apiKey: string): GenerateRecommendation {
  return async (message, signal) => {
    const ai = new GoogleGenAI({ apiKey });
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: message,
      config: {
        abortSignal: signal,
        systemInstruction: instructions,
        responseMimeType: "application/json",
        responseSchema: recommendationSchema,
      }
    });

    const text = response.text;
    if (!text) {
      throw new Error("Empty response from Gemini");
    }
    return JSON.parse(text) as unknown;
  };
}
