import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { DisputesPage } from './DisputesPage';

vi.mock('../adminMetadata', () => ({
  optionLabel: (options: Array<{ value: string; label: string }>, value: string) => options.find((item) => item.value === value)?.label || value || '—',
  useAdminMetadata: () => ({
    statusDefinitions: {}, filters: { disputes: { defaultValue: 'OPEN', options: [{ value: 'OPEN', label: 'Đang mở' }] } },
    reviewableStatuses: { disputes: ['OPEN'] },
    disputeDecisions: [{ value: 'CUSTOMER_WINS', label: 'Khách thắng' }, { value: 'CAREGIVER_WINS', label: 'Caregiver thắng' }, { value: 'PARTIAL_REFUND', label: 'Hoàn một phần' }],
  }),
}));

const dispute = { id: 'dispute-1', bookingId: 'booking-1', reason: 'Khiếu nại', status: 'OPEN', openedAt: '2026-10-03T00:00:00Z' };
function mockRequests(bookingFails = false) {
  const fetch = vi.fn().mockImplementation(async (url: string, init: RequestInit) => {
    if (init.method === 'POST') return Response.json({ ...dispute, status: 'RESOLVED' });
    if (url.includes('/bookings/')) return bookingFails ? Response.json({ message: 'Không đọc được escrow' }, { status: 500 })
      : Response.json({ id: 'booking-1', status: 'disputed', escrowAmount: 100000, platformFeeAmount: 20000 });
    if (url.endsWith('/disputes/dispute-1')) return Response.json(dispute);
    return Response.json({ items: [dispute], total: 1, page: 1, pageSize: 20 });
  });
  vi.stubGlobal('fetch', fetch);
  return fetch;
}

it('requires a deliberate decision and valid money split, then submits the confirmed preview', async () => {
  const fetch = mockRequests();
  vi.spyOn(window, 'confirm').mockReturnValue(true);
  render(<DisputesPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Xem hồ sơ' }));
  const submit = await screen.findByRole('button', { name: 'Ghi nhận phán quyết' });
  expect((submit as HTMLButtonElement).disabled).toBe(true);
  expect((screen.getByLabelText('Phán quyết') as HTMLSelectElement).value).toBe('');
  await userEvent.selectOptions(screen.getByLabelText('Phán quyết'), 'PARTIAL_REFUND');
  expect((submit as HTMLButtonElement).disabled).toBe(true);
  fireEvent.change(screen.getByLabelText('Số tiền hoàn (VND)'), { target: { value: 30000 } });
  fireEvent.change(screen.getByLabelText('Chế tài caregiver (VND)'), { target: { value: 10000 } });
  const preview = screen.getByRole('region', { name: 'Phân bổ tiền dự kiến' });
  expect(within(preview).getByText('40.000 đ')).toBeTruthy();
  await userEvent.click(submit);
  await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init.method === 'POST')).toBe(true));
  const mutation = fetch.mock.calls.find(([, init]) => init.method === 'POST');
  expect(JSON.parse(mutation![1].body)).toEqual({ decision: 'PARTIAL_REFUND', refundAmount: 30000, caregiverPenaltyAmount: 10000 });
  expect(window.confirm).toHaveBeenCalledWith(expect.stringContaining('Caregiver nhận: 40.000 đ'));
});

it('never offers financial actions when booking financial data cannot be loaded', async () => {
  const fetch = mockRequests(true);
  render(<DisputesPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Xem hồ sơ' }));
  expect(await screen.findByText('Hệ thống đang gặp sự cố. Vui lòng thử lại sau.')).toBeTruthy();
  expect(screen.queryByRole('button', { name: 'Ghi nhận phán quyết' })).toBeNull();
  expect(fetch.mock.calls.some(([, init]) => init.method === 'POST')).toBe(false);
});
