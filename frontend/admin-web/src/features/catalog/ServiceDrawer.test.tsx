import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import type { CatalogService } from '../../types';
import { ServiceDrawer } from './ServiceDrawer';

const mocks = vi.hoisted(() => ({ savePricingRule: vi.fn() }));

vi.mock('./catalogApi', () => ({
  saveCatalogService: vi.fn(),
  savePricingRule: (...args: unknown[]) => mocks.savePricingRule(...args),
}));

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

it('submits the same minute precision shown in the effective date field', async () => {
  mocks.savePricingRule.mockResolvedValue(undefined);
  render(<ServiceDrawer service={service} onClose={vi.fn()} onChanged={vi.fn()} />);

  const effectiveFrom = screen.getByLabelText('Hiệu lực từ') as HTMLInputElement;
  fireEvent.change(screen.getByLabelText('Tên bảng giá'), {
    target: { value: 'Giá chuẩn' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Thêm bảng giá' }));

  await waitFor(() => expect(mocks.savePricingRule).toHaveBeenCalledOnce());
  const payload = mocks.savePricingRule.mock.calls[0][2] as { effectiveFrom: string };
  expect(new Date(payload.effectiveFrom).getSeconds()).toBe(0);
  expect(new Date(payload.effectiveFrom).getMilliseconds()).toBe(0);
  expect(effectiveFrom.value).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
});
