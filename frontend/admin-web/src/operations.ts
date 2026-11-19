import type { PricingRule } from './types';

// Preserve the browser's local wall clock instead of slicing an ISO UTC value.
export function toDateTimeInput(value: string | Date) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '';
  const pad = (part: number) => String(part).padStart(2, '0');
  const fraction = date.getMilliseconds() ? `.${String(date.getMilliseconds()).padStart(3, '0')}` : '';
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}${fraction}`;
}

export function toMinuteDateTimeInput(value: string | Date) {
  return toDateTimeInput(value).slice(0, 16);
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
