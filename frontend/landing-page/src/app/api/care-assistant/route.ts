import { GoogleGenAI } from "@google/genai";

const recommendationSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    serviceCategory: {
      type: "string",
      enum: [
        "Chăm sóc người cao tuổi",
        "Đồng hành sinh hoạt",
        "Hỗ trợ đi lại",
      ],
    },
    hours: { type: "integer", minimum: 2, maximum: 12 },
    summary: { type: "string" },
    nextStep: { type: "string" },
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

export async function POST(request: Request) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: "AI chưa được cấu hình (Thiếu GEMINI_API_KEY). Vui lòng dùng form đặt ca để tiếp tục." },
      { status: 503 },
    );
  }

  let body: { message?: unknown };
  try {
    body = (await request.json()) as { message?: unknown };
  } catch {
    return Response.json({ error: "Nội dung gửi lên không hợp lệ." }, { status: 400 });
  }

  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (message.length < 8 || message.length > 1200) {
    return Response.json(
      { error: "Bạn hãy mô tả nhu cầu trong khoảng 8–1200 ký tự." },
      { status: 400 },
    );
  }

  try {
    const ai = new GoogleGenAI({ apiKey });
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: message,
      config: {
        systemInstruction: instructions,
        responseMimeType: "application/json",
        responseSchema: recommendationSchema,
      }
    });

    const text = response.text;
    if (!text) {
      throw new Error("Empty response from Gemini");
    }
    const recommendation = JSON.parse(text);
    return Response.json({ recommendation });
  } catch (error) {
    console.error("Care assistant request failed", error);
    return Response.json(
      { error: "Trợ lý đang bận một chút. Bạn có thể gửi nhu cầu qua form đặt ca." },
      { status: 502 },
    );
  }
}
