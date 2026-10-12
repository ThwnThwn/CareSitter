export const consultationServices = [
  { value: "elderly_care", label: "Chăm sóc người cao tuổi" },
  { value: "daily_companionship", label: "Đồng hành sinh hoạt" },
  { value: "mobility_support", label: "Hỗ trợ đi lại" },
] as const;

export interface ConsultationDraft {
  contactName: string;
  phone: string;
  serviceCategory: string;
  preferredDate: string;
  hours: number;
  caregiverPreference: string;
  note: string;
  consent: boolean;
}

export interface ConsultationReceipt { id: string; createdAt: string }
export const requestKeyPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function vietnamToday(now = new Date()): string {
  return new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

export function parseConsultation(value: unknown): ConsultationDraft | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  const text = (key: string) => typeof item[key] === "string" ? item[key].trim() : "";
  const phone = text("phone").replace(/[\s().-]/g, "").replace(/^\+84/, "0");
  const date = text("preferredDate");
  if (text("contactName").length < 2 || text("contactName").length > 120 ||
      !/^0[35789][0-9]{8}$/.test(phone) ||
      !consultationServices.some((service) => service.value === item.serviceCategory) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      !Number.isFinite(Date.parse(date)) || new Date(date).toISOString().slice(0, 10) !== date ||
      ![2, 4, 8, 12].includes(Number(item.hours)) ||
      typeof item.hours !== "number" || item.consent !== true ||
      text("caregiverPreference").length > 120 || text("note").length > 1000) return null;
  return { contactName: text("contactName"), phone,
    serviceCategory: text("serviceCategory"), preferredDate: date,
    hours: item.hours, caregiverPreference: text("caregiverPreference"),
    note: text("note"), consent: true };
}

export function isConsultationReceipt(value: unknown): value is ConsultationReceipt {
  if (!value || typeof value !== "object") return false;
  const item = value as Record<string, unknown>;
  return typeof item.id === "string" && requestKeyPattern.test(item.id) &&
      typeof item.createdAt === "string" && Number.isFinite(Date.parse(item.createdAt));
}
