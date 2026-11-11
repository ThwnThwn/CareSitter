import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, expect, it, vi } from 'vitest';
import type { CatalogService } from '../../types';
import { ServiceDrawer } from './ServiceDrawer';

const mocks = vi.hoisted(() => ({
  saveCatalogService: vi.fn(),
  savePricingRule: vi.fn(),
  saveChecklistTemplate: vi.fn(),
  uploadCatalogServiceImage: vi.fn(),
}));

vi.mock('./catalogApi', () => ({
  saveCatalogService: (...args: unknown[]) => mocks.saveCatalogService(...args),
  savePricingRule: (...args: unknown[]) => mocks.savePricingRule(...args),
  saveChecklistTemplate: (...args: unknown[]) => mocks.saveChecklistTemplate(...args),
  uploadCatalogServiceImage: (...args: unknown[]) => mocks.uploadCatalogServiceImage(...args),
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
  mocks.saveCatalogService.mockResolvedValue({ ...service, id: 'service-new' });
  mocks.savePricingRule.mockResolvedValue(undefined);
  mocks.saveChecklistTemplate.mockResolvedValue(undefined);
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

  await waitFor(() => expect(mocks.saveChecklistTemplate).toHaveBeenCalledOnce());
  expect(mocks.saveCatalogService).toHaveBeenCalledWith(
    undefined,
    expect.objectContaining({ code: 'COMPANION', name: 'Đồng hành tại nhà' }),
  );
  expect(mocks.savePricingRule).toHaveBeenCalledWith(
    'service-new',
    undefined,
    expect.objectContaining({ name: 'Giá chuẩn', baseHourlyPrice: 120000 }),
  );
  expect(mocks.saveChecklistTemplate).toHaveBeenCalledWith(
    'service-new',
    undefined,
    expect.objectContaining({ name: 'Kiểm tra bữa ăn', isRequired: true, sortOrder: 1 }),
  );
  expect(onChanged).toHaveBeenCalledOnce();
});

it('uploads the selected image before creating the service', async () => {
  mocks.uploadCatalogServiceImage.mockResolvedValue('https://cdn.example.test/service.webp');
  mocks.saveCatalogService.mockResolvedValue({ ...service, id: 'service-new' });
  mocks.savePricingRule.mockResolvedValue(undefined);
  mocks.saveChecklistTemplate.mockResolvedValue(undefined);
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

  await waitFor(() => expect(mocks.saveCatalogService).toHaveBeenCalledOnce());
  expect(mocks.uploadCatalogServiceImage).toHaveBeenCalledWith(image);
  expect(mocks.saveCatalogService).toHaveBeenCalledWith(
    undefined,
    expect.objectContaining({ imageUrl: 'https://cdn.example.test/service.webp' }),
  );
  expect(mocks.uploadCatalogServiceImage.mock.invocationCallOrder[0]).toBeLessThan(
    mocks.saveCatalogService.mock.invocationCallOrder[0],
  );
});

it('retries pricing without creating a duplicate service', async () => {
  mocks.saveCatalogService.mockResolvedValue({ ...service, id: 'service-new' });
  mocks.savePricingRule.mockRejectedValueOnce(new Error('Không thể lưu bảng giá.'));
  mocks.savePricingRule.mockResolvedValueOnce(undefined);
  mocks.saveChecklistTemplate.mockResolvedValue(undefined);
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

  expect(
    await screen.findByText(/Dịch vụ đã được tạo nhưng giá hoặc checklist chưa hoàn tất/),
  ).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Hoàn tất giá và checklist' }));

  await waitFor(() => expect(onChanged).toHaveBeenCalledOnce());
  expect(mocks.saveCatalogService).toHaveBeenCalledTimes(2);
  expect(mocks.saveCatalogService.mock.calls[0][0]).toBeUndefined();
  expect(mocks.saveCatalogService.mock.calls[1][0]).toBe('service-new');
  expect(mocks.savePricingRule).toHaveBeenCalledTimes(2);
  expect(mocks.saveChecklistTemplate).toHaveBeenCalledOnce();
});

it('resumes from the first unsaved checklist item without duplicating price or saved tasks', async () => {
  mocks.saveCatalogService.mockResolvedValue({ ...service, id: 'service-new' });
  mocks.savePricingRule.mockResolvedValue(undefined);
  mocks.saveChecklistTemplate
    .mockResolvedValueOnce(undefined)
    .mockRejectedValueOnce(new Error('Checklist tạm thời chưa lưu được.'))
    .mockResolvedValueOnce(undefined);
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
  fireEvent.click(screen.getByRole('button', { name: 'Thêm công việc khác' }));
  fireEvent.change(screen.getByLabelText('Tên công việc 2'), {
    target: { value: 'Nhắc uống nước' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Tạo dịch vụ, giá và checklist' }));

  expect(
    await screen.findByText(/Dịch vụ đã được tạo nhưng giá hoặc checklist chưa hoàn tất/),
  ).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Hoàn tất checklist' }));

  await waitFor(() => expect(onChanged).toHaveBeenCalledOnce());
  expect(mocks.savePricingRule).toHaveBeenCalledOnce();
  expect(mocks.saveChecklistTemplate).toHaveBeenCalledTimes(3);
  expect(mocks.saveChecklistTemplate.mock.calls[0][2]).toEqual(
    expect.objectContaining({ name: 'Kiểm tra bữa ăn', sortOrder: 1 }),
  );
  expect(mocks.saveChecklistTemplate.mock.calls[1][2]).toEqual(
    expect.objectContaining({ name: 'Nhắc uống nước', sortOrder: 2 }),
  );
  expect(mocks.saveChecklistTemplate.mock.calls[2][2]).toEqual(
    expect.objectContaining({ name: 'Nhắc uống nước', sortOrder: 2 }),
  );
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
