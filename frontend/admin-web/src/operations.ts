import type { PricingRule } from './types';

// Preserve the browser's local wall clock instead of slicing an ISO UTC value.
export function toDateTimeInput(value: string | Date) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '';
  const pad = (part: number) => String(part).padStart(2, '0');
  const fraction = date.getMilliseconds() ? `.${String(date.getMilliseconds()).padStart(3, '0')}` : '';
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}${fraction}`;
}

export function fromDateTimeInput(value: string) {
  if (!value) throw new Error('Vui lòng nhập thời điểm hiệu lực.');
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) throw new Error('Thời điểm hiệu lực không hợp lệ.');
  return date.toISOString();
}

export function currentPricingRule(rules: PricingRule[], now = Date.now()) {
  return rules.filter((rule) => rule.isActive && Date.parse(rule.effectiveFrom) <= now
    && (!rule.effectiveTo || Date.parse(rule.effectiveTo) > now))
    .sort((a, b) => Date.parse(b.effectiveFrom) - Date.parse(a.effectiveFrom))[0];
}

export function disputeAllocation(escrow: number, platformFee: number, decision: string, refundInput: number, penaltyInput: number) {
  if (![escrow, platformFee, refundInput, penaltyInput].every(Number.isSafeInteger)
    || escrow <= 0 || platformFee < 0 || platformFee > escrow || penaltyInput < 0 || refundInput < 0) {
    throw new Error('Số tiền phải là số nguyên VND hợp lệ, không âm.');
  }
  if (!['CUSTOMER_WINS', 'CAREGIVER_WINS', 'PARTIAL_REFUND'].includes(decision)) {
    throw new Error('Vui lòng chọn phán quyết.');
  }
  const refund = decision === 'CUSTOMER_WINS' ? escrow : decision === 'CAREGIVER_WINS' ? 0 : refundInput;
  if (decision === 'PARTIAL_REFUND' && (refund <= 0 || refund >= escrow)) {
    throw new Error('Hoàn một phần phải lớn hơn 0 và nhỏ hơn tiền giữ chờ.');
  }
  const fee = Math.min(platformFee, escrow - refund);
  const penalty = decision === 'PARTIAL_REFUND' ? penaltyInput : 0;
  const earning = escrow - refund - fee - penalty;
  if (earning < 0) throw new Error('Chế tài vượt quá thu nhập caregiver còn lại.');
  return { refund, fee, penalty, earning };
}
