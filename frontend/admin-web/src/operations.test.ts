import { describe, expect, it } from 'vitest';
import { currentPricingRule, fromDateTimeInput, toDateTimeInput, toMinuteDateTimeInput } from './operations';
import type { PricingRule } from './types';

describe('pricing time round-trip', () => {
  it.each(['2026-10-03T02:15:31.123Z', '2026-12-31T23:45:00.000Z'])('preserves the instant when editing %s', (instant) => {
    const local = toDateTimeInput(instant);
    expect(Number(local.slice(11, 13))).toBe(new Date(instant).getHours());
    expect(fromDateTimeInput(local)).toBe(instant);
  });
  it('rejects missing/invalid effective dates', () => {
    expect(() => fromDateTimeInput('')).toThrow();
    expect(() => fromDateTimeInput('not-a-date')).toThrow();
  });
  it('normalizes minute input without hidden seconds', () => {
    expect(toMinuteDateTimeInput('2026-10-24T09:50:24.825+07:00')).toMatch(
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/,
    );
  });
  it('selects the latest eligible rule, excluding future, expired and disabled rules', () => {
    const rule = (id: string, from: string, to?: string, active = true) => ({ id, effectiveFrom: from, effectiveTo: to, isActive: active } as PricingRule);
    const rules = [rule('future', '2026-11-01Z'), rule('old', '2026-01-01Z'), rule('expired', '2026-09-01Z', '2026-10-03Z'),
      rule('inactive', '2026-10-03Z', undefined, false), rule('current', '2026-10-03Z')];
    expect(currentPricingRule(rules, Date.parse('2026-10-03Z'))?.id).toBe('current');
    expect(currentPricingRule([rules[0]], Date.parse('2026-10-03Z'))).toBeUndefined();
  });
});
