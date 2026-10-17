import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { PaymentsPage } from './PaymentsPage';
import type { PaymentReview, RefundRequest } from '../types';

vi.mock('../adminMetadata', () => ({ useAdminMetadata: () => ({ statusDefinitions: {} }) }));

const review: PaymentReview = {
  intentId: 'intent-123', bookingId: 'booking-123', customerId: 'customer-123',
  amount: 100000, currency: 'VND', provider: 'PAYOS', providerOrderRef: '123456',
  reconciliationAttempts: 1, bookingStatus: 'closed_or_changed',
  intentStatus: 'SUCCEEDED', canResolve: false,
  manualReviewReason: 'Nhận thêm tiền; cần xử lý hoàn ngân hàng.',
};

it('shows extra/late payOS money without allowing a closed booking to be approved again', async () => {
  const fetch = vi.fn(async () => Response.json([review]));
  vi.stubGlobal('fetch', fetch);
  render(<PaymentsPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Xem đối soát' }));
  expect(screen.getByText('Cần xử lý khoản tiền với ngân hàng')).toBeTruthy();
  expect(screen.getByText('PAYOS')).toBeTruthy();
  expect(screen.queryByRole('button', { name: 'Xác nhận đã thanh toán' })).toBeNull();
  expect(screen.queryByRole('button', { name: 'Từ chối thanh toán' })).toBeNull();
  expect(fetch).toHaveBeenCalledTimes(1);
});

it('keeps manual resolution available for a pending payOS booking in review', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => Response.json([{ ...review,
    bookingStatus: 'needs_manual_review', intentStatus: 'PENDING', canResolve: true }])));
  render(<PaymentsPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Xử lý' }));
  expect(screen.getByRole('button', { name: 'Xác nhận đã thanh toán' })).toBeTruthy();
  expect(screen.getByLabelText('Mã giao dịch thanh toán')).toBeTruthy();
  expect(screen.queryByText('Mã giao dịch VNPay')).toBeNull();
});

it('requires external provider evidence before confirming a manual payOS refund', async () => {
  const refund: RefundRequest = {
    id: 'refund-123', bookingId: 'booking-456', paymentIntentId: 'intent-456', customerId: 'customer-456',
    provider: 'PAYOS', amount: 2000, currency: 'VND', reason: 'BOOKING_CANCELLED', status: 'MANUAL_REQUIRED',
    requestId: 'refund-booking-456', originalProviderOrderRef: '1019656752193156', attemptCount: 0,
    requestedAt: '2026-10-16T10:00:00Z',
  };
  const fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes('/api/v1/admin/payment-reconciliation')) return Response.json([]);
    if (url.includes('/api/v1/admin/refunds/refund-123/confirm')) return new Response(null, { status: 204 });
    if (url.includes('/api/v1/admin/refunds')) return Response.json({ items: [refund], total: 1, page: 1, pageSize: 20 });
    throw new Error(`Unexpected request: ${url} ${init?.method || 'GET'}`);
  });
  vi.stubGlobal('fetch', fetch);
  vi.spyOn(window, 'confirm').mockReturnValue(true);

  render(<PaymentsPage />);
  await userEvent.click(screen.getByRole('tab', { name: 'Hoàn tiền' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Xác nhận hoàn tiền' }));
  expect(screen.getByText('Không bấm trước khi provider xác nhận hoàn tiền')).toBeTruthy();

  await userEvent.type(screen.getByLabelText('Mã hoàn tiền từ provider'), 'PAYOS-REFUND-001');
  await userEvent.type(screen.getByLabelText('Ghi chú đối soát refund'), 'Đã kiểm tra merchant portal lúc 17:00.');
  await userEvent.click(screen.getByRole('button', { name: 'Xác nhận đã hoàn tiền' }));

  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  const confirmCall = fetch.mock.calls.find(([input]) => String(input).includes('/refund-123/confirm'));
  expect(confirmCall?.[1]).toMatchObject({ method: 'POST' });
  expect(confirmCall?.[1]?.body).toContain('PAYOS-REFUND-001');
});
