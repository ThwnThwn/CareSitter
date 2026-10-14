import { createGeminiRecommendation } from "@/features/care-assistant/gemini.server";
import { handleAssistantRequest } from "@/features/care-assistant/server";

export async function POST(request: Request) {
  const apiKey = process.env.GEMINI_API_KEY;
  return handleAssistantRequest(request, apiKey ? createGeminiRecommendation(apiKey) : undefined);
}
