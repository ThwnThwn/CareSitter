import { forwardConsultation } from "@/features/consultation/server";

export async function POST(request: Request) {
  return forwardConsultation(request, process.env.CARESITTER_API_BASE_URL);
}
