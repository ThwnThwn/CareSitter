import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, expect, it, vi } from 'vitest';
import type { CatalogService } from '../../types';
import { ServiceDrawer } from './ServiceDrawer';

const mocks = vi.hoisted(() => ({
  createServiceBundle: vi.fn(),
  saveCatalogService: vi.fn(),
  savePricingRule: vi.fn(),
  saveChecklistTemplate: vi.fn(),
  uploadCatalogServiceImage: vi.fn(),
}));

vi.mock('./catalogApi', () => ({
  createServiceBundle: (...args: unknown[]) => mocks.createServiceBundle(...args),
  saveCatalogService: (...args: unknown[]) => mocks.saveCatalogService(...args),
  savePricingRule: (...args: unknown[]) => mocks.savePricingRule(...args),
  saveChecklistTemplate: (...args: unknown[]) => mocks.saveChecklistTemplate(...args),
  uploadCatalogServiceImage: (...args: unknown[]) => mocks.uploadCatalogServiceImage(...args),
}));

vi.mock('../../adminMetadata', () => ({
  useAdminMetadata: () => ({
    statusDefinitions: {},
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
      checklist: {
        isRequired: true,
        requiresPhoto: false,
        firstSortOrder: 1,
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

beforeEach(() => {
  vi.clearAllMocks();
  Object.defineProperty(URL, 'createObjectURL', {
    configurable: true,
    value: vi.fn(() => 'blob:service-image-preview'),
  });
  Object.defineProperty(URL, 'revokeObjectURL', {
    configurable: true,
    value: vi.fn(),
  });
});

it('creates a service, its initial pricing rule and caregiver checklist in one submission', async () => {
  const onChanged = vi.fn();
  render(<ServiceDrawer service={null} onClose={vi.fn()} onChanged={onChanged} />);

  fireEvent.change(screen.getByLabelText('Mã dịch vụ'), { target: { value: 'COMPANION' } });
  fireEvent.change(screen.getByLabelText('Tên dịch vụ'), {
    target: { value: 'Đồng hành tại nhà' },
  });
  fireEvent.change(screen.getByLabelText('Tên bảng giá'), { target: { value: 'Giá chuẩn' } });
  fireEvent.change(screen.getByLabelText('Giá theo giờ'), { target: { value: '120000' } });
  fireEvent.change(screen.getByLabelText('Tên công việc 1'), {
    target: { value: 'Kiểm tra bữa ăn' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Tạo dịch vụ, giá và checklist' }));

  await waitFor(() => expect(onChanged).toHaveBeenCalledOnce());
  expect(mocks.createServiceBundle).toHaveBeenCalledWith(expect.any(String),
    expect.objectContaining({ code: 'COMPANION', name: 'Đồng hành tại nhà' }),
    expect.objectContaining({ name: 'Giá chuẩn', baseHourlyPrice: 120000 }),
    [expect.objectContaining({ name: 'Kiểm tra bữa ăn', sortOrder: 1 })]);
  expect(mocks.saveCatalogService).not.toHaveBeenCalled();
});

it('uploads the selected image before creating the service', async () => {
  mocks.uploadCatalogServiceImage.mockResolvedValue('https://cdn.example.test/service.webp');
  render(<ServiceDrawer service={null} onClose={vi.fn()} onChanged={vi.fn()} />);

  fireEvent.change(screen.getByLabelText('Mã dịch vụ'), { target: { value: 'COMPANION' } });
  fireEvent.change(screen.getByLabelText('Tên dịch vụ'), {
    target: { value: 'Đồng hành tại nhà' },
  });
  fireEvent.change(screen.getByLabelText('Tên bảng giá'), { target: { value: 'Giá chuẩn' } });
  fireEvent.change(screen.getByLabelText('Tên công việc 1'), {
    target: { value: 'Kiểm tra bữa ăn' },
  });
  const image = new File(['service-image'], 'service.webp', { type: 'image/webp' });
  fireEvent.change(screen.getByLabelText('Chọn ảnh gói dịch vụ'), {
    target: { files: [image] },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Tạo dịch vụ, giá và checklist' }));

  await waitFor(() => expect(mocks.createServiceBundle).toHaveBeenCalledOnce());
  expect(mocks.createServiceBundle.mock.calls[0][1].imageUrl).toBe('https://cdn.example.test/service.webp');
  expect(mocks.uploadCatalogServiceImage.mock.invocationCallOrder[0]).toBeLessThan(
    mocks.createServiceBundle.mock.invocationCallOrder[0]);
});

it('retries the same atomic submission after an uncertain response', async () => {
  mocks.createServiceBundle.mockRejectedValueOnce(new Error('Chưa nhận được phản hồi.'));
  const onChanged = vi.fn();
  render(<ServiceDrawer service={null} onClose={vi.fn()} onChanged={onChanged} />);

  fireEvent.change(screen.getByLabelText('Mã dịch vụ'), { target: { value: 'COMPANION' } });
  fireEvent.change(screen.getByLabelText('Tên dịch vụ'), {
    target: { value: 'Đồng hành tại nhà' },
  });
  fireEvent.change(screen.getByLabelText('Tên bảng giá'), { target: { value: 'Giá chuẩn' } });
  fireEvent.change(screen.getByLabelText('Tên công việc 1'), {
    target: { value: 'Kiểm tra bữa ăn' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Tạo dịch vụ, giá và checklist' }));

  await screen.findByText('Chưa nhận được phản hồi.');
  fireEvent.click(screen.getByRole('button', { name: 'Tạo dịch vụ, giá và checklist' }));
  await waitFor(() => expect(onChanged).toHaveBeenCalledOnce());
  expect(mocks.createServiceBundle.mock.calls[1]).toEqual(mocks.createServiceBundle.mock.calls[0]);
});

it('preserves both original timestamps when only the price name changes', async () => {
  const rule = {
    id: 'rule-1', serviceTypeId: service.id, name: 'Giá gốc', baseHourlyPrice: 120000,
    nightMultiplier: 1, holidayMultiplier: 1, platformFeePercent: 15, disputeWindowHours: 24,
    effectiveFrom: '2026-10-12T01:00:20.123456Z', effectiveTo: '2026-10-12T01:00:42.765432Z', isActive: true,
  };
  render(<ServiceDrawer service={{ ...service, pricingRules: [rule] }} onClose={vi.fn()} onChanged={vi.fn()} />);
  fireEvent.click(screen.getByRole('button', { name: 'Sửa' }));
  fireEvent.change(screen.getByLabelText('Tên bảng giá'), { target: { value: 'Giá mới' } });
  fireEvent.click(screen.getByRole('button', { name: 'Lưu bảng giá' }));
  await waitFor(() => expect(mocks.savePricingRule).toHaveBeenCalledWith(service.id, rule.id,
    expect.objectContaining({ name: 'Giá mới', effectiveFrom: rule.effectiveFrom, effectiveTo: rule.effectiveTo })));
});

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
