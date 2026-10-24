import { render, screen } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import type { CatalogService } from '../../types';
import { ServiceDrawer } from './ServiceDrawer';

vi.mock('../../adminMetadata', () => ({
  useAdminMetadata: () => ({
    defaults: {
      service: { defaultDurationMinutes: 240, isActive: true },
      pricingRule: {
        name: '',
        baseHourlyPrice: 0,
        nightMultiplier: 1,
        holidayMultiplier: 1,
        platformFeePercent: 15,
        disputeWindowHours: 48,
        isActive: true,
      },
    },
    constraints: {
      serviceDurationMinutes: { min: 30, max: 1440 },
      priceMultiplier: { min: 1, max: 10, step: 0.1 },
      platformFeePercent: { min: 0, max: 100, step: 0.1 },
      disputeWindowHours: { min: 0, max: 720 },
    },
  }),
}));

const service: CatalogService = {
  id: 'service-1',
  code: 'NONMED_COMPANION',
  name: 'Đồng hành linh hoạt',
  description: 'Hỗ trợ sinh hoạt phi y tế.',
  defaultDurationMinutes: 240,
  isActive: true,
  allowAdHocTasks: false,
  pricingRules: [],
};

it('keeps pricing effective date pickers at minute precision', () => {
  render(<ServiceDrawer service={service} onClose={vi.fn()} onChanged={vi.fn()} />);

  const effectiveFrom = screen.getByLabelText('Hiệu lực từ') as HTMLInputElement;
  const effectiveTo = screen.getByLabelText('Hiệu lực đến') as HTMLInputElement;

  expect(effectiveFrom.type).toBe('datetime-local');
  expect(effectiveFrom.step).toBe('60');
  expect(effectiveFrom.value).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
  expect(effectiveTo.step).toBe('60');
});
