import { fromDateTimeInput, toDateTimeInput } from './operations';
import type { AdminPromotion } from './types';

export function createPromotionForm(promotion: AdminPromotion | null) {
  const now = new Date();
  return {
    code: promotion?.code ?? '', title: promotion?.title ?? '', summary: promotion?.summary ?? '',
    description: promotion?.description ?? '', badgeText: promotion?.badgeText ?? '',
    terms: promotion?.terms.join('\n') ?? '', discountType: promotion?.discountType ?? 'percentage',
    discountValue: String(promotion?.discountValue ?? 10),
    maxDiscountAmount: promotion?.maxDiscountAmount?.toString() ?? '',
    minOrderAmount: String(promotion?.minOrderAmount ?? 0),
    startsAt: toDateTimeInput(promotion?.startsAt ?? now),
    endsAt: toDateTimeInput(promotion?.endsAt ?? new Date(now.getTime() + 7 * 86_400_000)),
    isActive: promotion?.isActive ?? false, firstPaidBookingOnly: promotion?.firstPaidBookingOnly ?? false,
    totalUsageLimit: promotion?.totalUsageLimit?.toString() ?? '',
    perCustomerUsageLimit: String(promotion?.perCustomerUsageLimit ?? 1),
    priority: String(promotion?.priority ?? 0), isFeatured: promotion?.isFeatured ?? false,
    eligibleServiceIds: promotion?.eligibleServiceIds ?? [],
  };
}

export type PromotionForm = ReturnType<typeof createPromotionForm>;

function integer(value: string, label: string, min = 0, max = Number.MAX_SAFE_INTEGER) {
  if (!value.trim()) throw new Error(`Vui lòng nhập ${label.toLowerCase()}.`);
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < min || number > max)
    throw new Error(`${label} phải là số nguyên từ ${min} đến ${max}.`);
  return number;
}

export function promotionPayload(form: PromotionForm, expectedUpdatedAt?: string) {
  const startsAt = fromDateTimeInput(form.startsAt);
  const endsAt = fromDateTimeInput(form.endsAt);
  if (Date.parse(endsAt) <= Date.parse(startsAt)) throw new Error('Thời điểm kết thúc phải sau thời điểm bắt đầu.');
  const terms = form.terms.split('\n').map((term) => term.trim()).filter(Boolean);
  if (terms.length > 20 || terms.some((term) => term.length > 500))
    throw new Error('Tối đa 20 điều kiện, mỗi điều kiện không quá 500 ký tự.');
  return {
    ...form, code: form.code.trim().toUpperCase(), title: form.title.trim(), summary: form.summary.trim(),
    description: form.description.trim() || null, badgeText: form.badgeText.trim(), terms, startsAt, endsAt,
    discountValue: integer(form.discountValue, 'Mức giảm', 1, form.discountType === 'percentage' ? 100 : Number.MAX_SAFE_INTEGER),
    maxDiscountAmount: form.maxDiscountAmount === '' ? null : integer(form.maxDiscountAmount, 'Giảm tối đa', 1),
    minOrderAmount: integer(form.minOrderAmount, 'Đơn tối thiểu'),
    totalUsageLimit: form.totalUsageLimit === '' ? null : integer(form.totalUsageLimit, 'Tổng lượt', 1, 2_147_483_647),
    perCustomerUsageLimit: integer(form.perCustomerUsageLimit, 'Lượt mỗi khách', 1, 2_147_483_647),
    priority: integer(form.priority, 'Độ ưu tiên', 0, 2_147_483_647), expectedUpdatedAt,
  };
}
