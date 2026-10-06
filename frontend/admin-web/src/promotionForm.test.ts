import { describe, expect, it } from 'vitest';
import { createPromotionForm, promotionPayload } from './promotionForm';

describe('promotion campaign payload', () => {
  it('starts disabled and sends empty optional limits as null', () => {
    const form = createPromotionForm(null);
    const payload = promotionPayload({ ...form, code: ' care_10 ', terms: ' Điều kiện 1\n\nĐiều kiện 2 ' });
    expect(payload).toMatchObject({ code: 'CARE_10', isActive: false, totalUsageLimit: null, maxDiscountAmount: null, terms: ['Điều kiện 1', 'Điều kiện 2'] });
    expect(payload.startsAt).toMatch(/Z$/);
  });
  it.each([
    { discountValue: '101' }, { discountValue: '1.5' }, { minOrderAmount: '-1' },
    { maxDiscountAmount: '0' }, { totalUsageLimit: '0' }, { perCustomerUsageLimit: '' },
    { minOrderAmount: '9007199254740992' }, { priority: '2147483648' },
  ])('rejects unsafe configuration %j', (invalid) => {
    expect(() => promotionPayload({ ...createPromotionForm(null), ...invalid })).toThrow();
  });
  it('rejects reversed windows and overlong terms', () => {
    const form = createPromotionForm(null);
    expect(() => promotionPayload({ ...form, endsAt: form.startsAt })).toThrow(/kết thúc/);
    expect(() => promotionPayload({ ...form, terms: 'x'.repeat(501) })).toThrow(/điều kiện/);
  });
});
