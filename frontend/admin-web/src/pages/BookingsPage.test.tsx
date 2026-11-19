import { act, render, screen, waitFor } from '@testing-library/react';
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

it('opens and closes the correct booking when the URL changes on the same page', async () => {
  setupFetch();
  window.history.replaceState(null, '', '#/bookings');
  render(<BookingsPage />);
  await screen.findByText(mockBooking.serviceName);
  function navigate(hash: string) {
    act(() => {
      window.history.replaceState(null, '', hash);
      window.dispatchEvent(new HashChangeEvent('hashchange'));
    });
  }
  try {
    navigate('#/bookings?id=' + mockBooking.id);
    await screen.findByRole('dialog');
    navigate('#/bookings');
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  } finally {
    window.history.replaceState(null, '', '#/bookings');
  }
});

it('renders booking list and filters items by search input', async () => {
  setupFetch();
  render(<BookingsPage />);

  expect(await screen.findByText('Chăm sóc người già')).toBeTruthy();
  expect(screen.getByText('Bà Nguyễn Thị Mai')).toBeTruthy();

  // Search by keyword that does not match
  const searchInput = screen.getByPlaceholderText(/Tìm trong trang này/i);
  await userEvent.type(searchInput, 'Không tồn tại');

  expect(await screen.findByText('Không tìm thấy booking')).toBeTruthy();
  expect(screen.getByText('Tìm thấy 0 lịch trên trang này')).toBeTruthy();

  // Clear search
  await userEvent.clear(searchInput);
  expect(await screen.findByText('Chăm sóc người già')).toBeTruthy();
});

it('shows the total and page position when the booking list fits on one page', async () => {
  setupFetch();
  render(<BookingsPage />);

  expect(await screen.findByText('Trang 1/1')).toBeTruthy();
  expect(screen.getByText('Hiển thị 1–1 trong 1')).toBeTruthy();
  expect((screen.getByRole('button', { name: 'Trang trước' }) as HTMLButtonElement).disabled).toBe(true);
  expect((screen.getByRole('button', { name: 'Trang sau' }) as HTMLButtonElement).disabled).toBe(true);
});

it('requests the next and previous server pages', async () => {
  vi.stubGlobal('fetch', vi.fn(async (url: string) => {
    const page = Number(new URL(url).searchParams.get('page'));
    const items = [{ ...mockBooking, serviceName: page === 1 ? 'Dịch vụ trang đầu' : 'Dịch vụ trang sau' }];
    return Response.json({ items, page, pageSize: 20, total: 21 });
  }));
  render(<BookingsPage />);

  await screen.findByText('Dịch vụ trang đầu');
  await userEvent.click(screen.getByRole('button', { name: 'Trang sau' }));
  expect(await screen.findByText('Dịch vụ trang sau')).toBeTruthy();
  expect(screen.getByText('Trang 2/2')).toBeTruthy();
  await userEvent.click(screen.getByRole('button', { name: 'Trang trước' }));
  expect(await screen.findByText('Dịch vụ trang đầu')).toBeTruthy();
});

it('shows distinct identifiers for bookings with the same prefix and matches the displayed identifier', async () => {
  const first = { ...mockBooking, id: 'd0000000-0000-0000-0000-000000000101', serviceName: 'Lịch một' };
  const second = { ...mockBooking, id: 'd0000000-0000-0000-0000-000000000102', serviceName: 'Lịch hai' };
  vi.stubGlobal('fetch', vi.fn(async () => Response.json({ items: [first, second], total: 2, page: 1, pageSize: 20 })));
  render(<BookingsPage />);

  await screen.findByRole('button', { name: '#D0000000…00000101' });
  expect(screen.getByRole('button', { name: '#D0000000…00000102' })).toBeTruthy();
  await userEvent.type(screen.getByRole('textbox', { name: 'Tìm booking trong trang này' }), '#D0000000…00000102');
  expect(screen.queryByText('Lịch một')).toBeNull();
  expect(screen.getByText('Lịch hai')).toBeTruthy();
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
