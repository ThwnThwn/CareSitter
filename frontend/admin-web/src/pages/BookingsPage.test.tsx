import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { BookingsPage } from './BookingsPage';

vi.mock('../adminMetadata', () => ({
  useAdminMetadata: () => ({
    statusDefinitions: {},
    filters: {
      bookings: {
        defaultValue: 'ALL',
        options: [
          { value: 'ALL', label: 'Tất cả' },
          { value: 'checkout_pending_review', label: 'Chờ duyệt hoàn tất' },
        ],
      },
    },
  }),
}));

const mockBooking = {
  id: 'booking-999',
  serviceName: 'Chăm sóc người già',
  addressText: '123 Nguyễn Huệ, Q.1, TP.HCM',
  beneficiaryName: 'Bà Nguyễn Thị Mai',
  beneficiaryId: 'beneficiary-1',
  caregiverName: 'Trần Thị Caregiver',
  caregiverId: 'caregiver-1',
  scheduledStart: '2026-10-12T08:00:00Z',
  scheduledEnd: '2026-10-12T12:00:00Z',
  status: 'checkout_pending_review',
  escrowAmount: 500000,
  caregiverEarningAmount: 425000,
  platformFeeAmount: 75000,
  updatedAt: '2026-10-12T12:30:00Z',
};

const mockTasks = [
  {
    id: 'task-1',
    name: 'Đo huyết áp',
    description: 'Đo huyết áp buổi sáng',
    isRequired: true,
    requiresPhoto: true,
    status: 'COMPLETED',
    completedAt: '2026-10-12T09:00:00Z',
    photoUrls: ['https://example.com/photo1.jpg'],
  },
];

const mockTimeline = [
  {
    id: 'tl-1',
    title: 'Bắt đầu ca',
    note: 'Caregiver đã check-in',
    recordedAt: '2026-10-12T08:05:00Z',
  },
];

function setupFetch(booking = mockBooking) {
  const fetchMock = vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
    if (init?.method === 'POST') {
      return Response.json({ success: true });
    }
    if (url.includes('/tasks')) {
      return Response.json(mockTasks);
    }
    if (url.includes('/timeline')) {
      return Response.json(mockTimeline);
    }
    if (url.endsWith(`/bookings/${booking.id}`)) {
      return Response.json(booking);
    }
    return Response.json({
      items: [booking],
      total: 1,
      page: 1,
      pageSize: 20,
    });
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

it('renders booking list and filters items by search input', async () => {
  setupFetch();
  render(<BookingsPage />);

  expect(await screen.findByText('Chăm sóc người già')).toBeTruthy();
  expect(screen.getByText('Bà Nguyễn Thị Mai')).toBeTruthy();

  // Search by keyword that does not match
  const searchInput = screen.getByPlaceholderText(/Tìm trong trang này/i);
  await userEvent.type(searchInput, 'Không tồn tại');

  expect(await screen.findByText('Không tìm thấy booking')).toBeTruthy();

  // Clear search
  await userEvent.clear(searchInput);
  expect(await screen.findByText('Chăm sóc người già')).toBeTruthy();
});

it('opens drawer, inspects checklist and timeline tabs', async () => {
  setupFetch();
  render(<BookingsPage />);

  const detailBtn = await screen.findByRole('button', { name: 'Xem chi tiết' });
  await userEvent.click(detailBtn);

  expect(await screen.findByRole('dialog')).toBeTruthy();
  expect(screen.getByText('Chi tiết booking')).toBeTruthy();

  // Switch to Checklist tab
  const tasksTab = screen.getByRole('tab', { name: /Checklist/i });
  await userEvent.click(tasksTab);
  expect(await screen.findByText('Đo huyết áp')).toBeTruthy();
  expect(screen.getByText('Đo huyết áp buổi sáng')).toBeTruthy();

  // Switch to Timeline tab
  const timelineTab = screen.getByRole('tab', { name: /Timeline/i });
  await userEvent.click(timelineTab);
  expect(await screen.findByText('Bắt đầu ca')).toBeTruthy();
});

it('allows confirming checkout completion for checkout_pending_review booking', async () => {
  const fetchMock = setupFetch();
  const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

  render(<BookingsPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Xem chi tiết' }));

  const completeBtn = await screen.findByRole('button', { name: /Xác nhận hoàn tất ca/i });
  expect(completeBtn).toBeTruthy();

  await userEvent.click(completeBtn);

  expect(confirmSpy).toHaveBeenCalledWith(
    expect.stringContaining('Xác nhận hoàn tất ca này?')
  );

  await waitFor(() => {
    const postCall = fetchMock.mock.calls.find(([url, init]) =>
      url.endsWith(`/bookings/${mockBooking.id}/complete`) && init?.method === 'POST'
    );
    expect(postCall).toBeDefined();
  });
});
