import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { PaymentsPage } from './PaymentsPage';
import type { PaymentReview } from '../types';

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
