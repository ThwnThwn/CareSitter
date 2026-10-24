import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { PromotionsPage } from './PromotionsPage';
import type { AdminPromotion } from '../types';

vi.mock('../adminMetadata', () => ({ useAdminMetadata: () => ({ statusDefinitions: {
  ACTIVE: { label: 'Đang hoạt động', tone: 'success' }, INACTIVE: { label: 'Đã tắt', tone: 'neutral' },
} }) }));

const promotion: AdminPromotion = {
  id: 'campaign-1', code: 'CARE10', title: 'Chăm sóc tháng 10', summary: 'Giảm 10% cho ca chăm sóc', description: 'Điều kiện áp dụng',
  badgeText: 'Giảm 10%', terms: ['Theo điều kiện'], discountType: 'percentage', discountValue: 10,
  maxDiscountAmount: 100000, minOrderAmount: 200000, startsAt: '2026-10-01T01:00:00.123456Z', endsAt: '2026-11-01T01:00:00Z',
  isActive: true, firstPaidBookingOnly: false, totalUsageLimit: 100, perCustomerUsageLimit: 2, priority: 1, isFeatured: false,
  eligibleServiceIds: ['service-1'], status: 'ACTIVE', reservedCount: 0, redeemedCount: 0, releasedCount: 0, hasHistory: false,
  canDelete: true, createdAt: '2026-10-01T01:00:00Z', updatedAt: '2026-10-06T01:00:00.123456Z',
};
const services = [{ id: 'service-1', name: 'Chăm sóc người cao tuổi', isActive: true }];
function mockApi(current = promotion, mutate?: (init: RequestInit, path: string) => Response) {
  const fetch = vi.fn().mockImplementation(async (path: string, init: RequestInit = {}) => {
    if (init.method && init.method !== 'GET') return mutate?.(init, path) ?? Response.json(current);
    if (path.endsWith('/catalog/services')) return Response.json(services);
    if (path.endsWith('/campaign-1')) return Response.json(current);
    return Response.json({ items: [current], total: 1, page: 1, pageSize: 20 });
  });
  vi.stubGlobal('fetch', fetch); return fetch;
}

it('shows a recoverable loading error and then a real empty state', async () => {
  let offline = true;
  vi.stubGlobal('fetch', vi.fn(async () => offline
    ? Response.json({ detail: 'Mất kết nối' }, { status: 503 })
    : Response.json({ items: [], total: 0, page: 1, pageSize: 20 })));
  render(<PromotionsPage />);
  expect(await screen.findByText('Hệ thống đang gặp sự cố. Vui lòng thử lại sau.')).toBeTruthy();
  expect(screen.queryByLabelText('Đang tải dữ liệu')).toBeNull();
  offline = false; await userEvent.click(screen.getByRole('button', { name: 'Thử lại' }));
  expect(await screen.findByText('Chưa có chiến dịch ưu đãi')).toBeTruthy();
});

it('creates a disabled campaign with normalized fields and null optional limits', async () => {
  const fetch = mockApi();
  render(<PromotionsPage />); await userEvent.click(screen.getByRole('button', { name: 'Tạo chiến dịch' }));
  fireEvent.change(await screen.findByLabelText('Mã ưu đãi'), { target: { value: 'care_new' } });
  fireEvent.change(screen.getByLabelText('Nhãn ưu đãi'), { target: { value: '10%' } });
  fireEvent.change(screen.getByLabelText('Tên chiến dịch'), { target: { value: 'Chiến dịch mới' } });
  fireEvent.change(screen.getByLabelText('Tóm tắt'), { target: { value: 'Nội dung ưu đãi' } });
  await userEvent.click(screen.getAllByRole('button', { name: 'Tạo chiến dịch' }).at(-1)!);
  await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init.method === 'POST')).toBe(true));
  const call = fetch.mock.calls.find(([, init]) => init.method === 'POST')!;
  expect(call[0]).toMatch(/\/api\/v1\/admin\/promotions$/);
  expect(JSON.parse(call[1].body)).toMatchObject({ code: 'CARE_NEW', isActive: false, totalUsageLimit: null, maxDiscountAmount: null, eligibleServiceIds: [] });
  expect(await screen.findByRole('status')).toHaveProperty('textContent', 'Đã tạo chiến dịch ưu đãi.');
});

it('locks financial fields and preserves the exact original start time for a used campaign', async () => {
  const current = { ...promotion, hasHistory: true, canDelete: false, redeemedCount: 1 };
  const fetch = mockApi(current);
  render(<PromotionsPage />); await userEvent.click(await screen.findByRole('button', { name: 'Xem và sửa CARE10' }));
  expect(await screen.findByLabelText('Mã ưu đãi')).toHaveProperty('disabled', true);
  expect(screen.getByLabelText('Mức giảm (%)')).toHaveProperty('disabled', true);
  expect(screen.queryByRole('button', { name: 'Xóa chiến dịch' })).toBeNull();
  fireEvent.change(screen.getByLabelText('Tên chiến dịch'), { target: { value: 'Tên mới' } });
  await userEvent.click(screen.getByRole('button', { name: 'Lưu thay đổi' }));
  await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init.method === 'PUT')).toBe(true));
  expect(JSON.parse(fetch.mock.calls.find(([, init]) => init.method === 'PUT')![1].body))
    .toMatchObject({ title: 'Tên mới', startsAt: promotion.startsAt, expectedUpdatedAt: promotion.updatedAt, eligibleServiceIds: ['service-1'] });
});

it('toggles the persisted campaign using its edit token', async () => {
  const fetch = mockApi();
  render(<PromotionsPage />); await userEvent.click(await screen.findByRole('button', { name: 'Xem và sửa CARE10' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Tắt chiến dịch' }));
  const call = fetch.mock.calls.find(([, init]) => init.method === 'PATCH')!;
  expect(call[0]).toMatch(/\/campaign-1\/active$/);
  expect(JSON.parse(call[1].body)).toEqual({ isActive: false, expectedUpdatedAt: promotion.updatedAt });
});

it('asks for confirmation before deleting and retains the draft after a conflict', async () => {
  const fetch = mockApi(promotion, () => Response.json({ title: 'promotion.stale', detail: 'Chiến dịch đã thay đổi' }, { status: 409 }));
  render(<PromotionsPage />); await userEvent.click(await screen.findByRole('button', { name: 'Xem và sửa CARE10' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Xóa chiến dịch' }));
  expect(fetch.mock.calls.some(([, init]) => init.method === 'DELETE')).toBe(false);
  await userEvent.click(screen.getByRole('button', { name: 'Xác nhận xóa CARE10' }));
  expect(await screen.findByText('Chiến dịch đã thay đổi')).toBeTruthy();
  expect(screen.getByLabelText('Tên chiến dịch')).toHaveProperty('value', promotion.title);
  expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toHaveProperty('disabled', true);
  const call = fetch.mock.calls.find(([, init]) => init.method === 'DELETE')!;
  expect(JSON.parse(call[1].body)).toEqual({ expectedUpdatedAt: promotion.updatedAt });
  await userEvent.click(screen.getByRole('button', { name: 'Tải lại chiến dịch' }));
  await waitFor(() => expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toHaveProperty('disabled', false));
});

it('sends search and status filters to the server', async () => {
  const fetch = mockApi();
  render(<PromotionsPage />);
  await screen.findByText(promotion.title);
  fireEvent.change(screen.getByLabelText('Tìm mã hoặc tên chiến dịch'), { target: { value: 'Care' } });
  await userEvent.click(screen.getByRole('button', { name: 'Tìm kiếm' }));
  await waitFor(() => expect(fetch.mock.calls.some(([path]) => path.includes('search=Care'))).toBe(true));
  fireEvent.change(screen.getByLabelText('Trạng thái'), { target: { value: 'INACTIVE' } });
  await waitFor(() => expect(fetch.mock.calls.some(([path]) => path.includes('status=INACTIVE'))).toBe(true));
});

it('allows correcting a duplicate code without discarding the create draft', async () => {
  let duplicate = true;
  const fetch = mockApi(promotion, () => duplicate
    ? Response.json({ title: 'promotion.code_exists', detail: 'Mã ưu đãi đã tồn tại.' }, { status: 409 })
    : Response.json(promotion));
  render(<PromotionsPage />); await userEvent.click(screen.getByRole('button', { name: 'Tạo chiến dịch' }));
  fireEvent.change(await screen.findByLabelText('Mã ưu đãi'), { target: { value: 'CARE10' } });
  fireEvent.change(screen.getByLabelText('Nhãn ưu đãi'), { target: { value: '10%' } });
  fireEvent.change(screen.getByLabelText('Tên chiến dịch'), { target: { value: 'Bản nháp' } });
  fireEvent.change(screen.getByLabelText('Tóm tắt'), { target: { value: 'Nội dung' } });
  await userEvent.click(screen.getAllByRole('button', { name: 'Tạo chiến dịch' }).at(-1)!);
  expect(await screen.findByText('Mã ưu đãi đã tồn tại.')).toBeTruthy();
  expect(screen.getAllByRole('button', { name: 'Tạo chiến dịch' }).at(-1)).toHaveProperty('disabled', false);
  expect(screen.getByLabelText('Tên chiến dịch')).toHaveProperty('value', 'Bản nháp');
  duplicate = false;
  fireEvent.change(screen.getByLabelText('Mã ưu đãi'), { target: { value: 'CARE_NEW' } });
  await userEvent.click(screen.getAllByRole('button', { name: 'Tạo chiến dịch' }).at(-1)!);
  await screen.findByText('Đã tạo chiến dịch ưu đãi.');
  expect(fetch.mock.calls.filter(([, init]) => init.method === 'POST')).toHaveLength(2);
});

it('allows fixing a quota conflict without forcing a reload', async () => {
  const fetch = mockApi(promotion, () => Response.json({ title: 'promotion.quota_below_usage', detail: 'Giới hạn thấp hơn lượt đã dùng.' }, { status: 409 }));
  render(<PromotionsPage />); await userEvent.click(await screen.findByRole('button', { name: 'Mở chiến dịch CARE10' }));
  await screen.findByLabelText('Tên chiến dịch');
  fireEvent.change(screen.getByLabelText('Tổng lượt sử dụng'), { target: { value: '1' } });
  await userEvent.click(screen.getByRole('button', { name: 'Lưu thay đổi' }));
  expect(await screen.findByText('Giới hạn thấp hơn lượt đã dùng.')).toBeTruthy();
  expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toHaveProperty('disabled', false);
  expect(screen.queryByRole('button', { name: 'Tải lại chiến dịch' })).toBeNull();
  expect(fetch.mock.calls.filter(([, init]) => init.method === 'PUT')).toHaveLength(1);
});
