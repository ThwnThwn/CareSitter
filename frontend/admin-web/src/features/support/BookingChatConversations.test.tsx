import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, expect, it, vi } from 'vitest';
import type { BookingChatAdminDetail, BookingChatAdminItem } from '../../types';
import { BookingChatConversations } from './BookingChatConversations';
import { bookingChatAdminApi } from './bookingChatAdminApi';

vi.mock('./bookingChatAdminApi', () => ({
  bookingChatAdminApi: {
    list: vi.fn(), get: vi.fn(), messages: vi.fn(), activity: vi.fn(),
    block: vi.fn(), unblock: vi.fn(), releaseLegalHold: vi.fn(),
  },
}));

const item: BookingChatAdminItem = {
  conversationId: 'conversation-1', bookingId: 'booking-1', changeVersion: 3,
  lastSequence: 2, lastMessageAt: null, writeBlocked: false,
  legalHoldActive: false, updatedAt: '2026-10-18T01:00:00Z',
  reportCount: 0, deadLetterCount: 0,
};
const detail: BookingChatAdminDetail = {
  conversationId: item.conversationId, bookingId: item.bookingId, changeVersion: 3,
  scopeVersion: 1, writeBlocked: false, writeBlockReason: null,
  blockedByUserId: null, legalHoldAt: null, legalHoldReason: null,
  legalHoldReleasedAt: null, disputeLockedAt: null, writeClosesAt: null, purgedAt: null,
  reports: [],
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(bookingChatAdminApi.list).mockResolvedValue({ items: [item], nextCursor: 'next' });
  vi.mocked(bookingChatAdminApi.get).mockResolvedValue(detail);
  vi.mocked(bookingChatAdminApi.messages).mockResolvedValue({ items: [], nextBeforeSequence: null });
  vi.mocked(bookingChatAdminApi.activity).mockResolvedValue({ items: [], nextCursor: null });
});

it('applies reported, blocked, and dead-letter filters together', async () => {
  render(<BookingChatConversations />);
  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenCalledWith(null, {}));

  await userEvent.selectOptions(screen.getByLabelText('Report'), 'true');
  await userEvent.selectOptions(screen.getByLabelText('Khóa ghi'), 'true');
  await userEvent.selectOptions(screen.getByLabelText('Dead letter'), 'true');
  await userEvent.type(screen.getByLabelText('Booking ID'), 'booking-filter');
  await userEvent.type(screen.getByLabelText('User ID'), 'user-filter');
  await userEvent.click(screen.getByRole('button', { name: 'Áp dụng bộ lọc' }));

  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenLastCalledWith(null, {
    reported: true,
    blocked: true,
    deadLetter: true,
    bookingId: 'booking-filter',
    userId: 'user-filter',
    from: undefined,
    to: undefined,
  }));
});

it('renders report, ticket, message, and audit context after an authorized read', async () => {
  vi.mocked(bookingChatAdminApi.get).mockResolvedValue({
    ...detail,
    reports: [{
      id: 'report-1', messageId: 'message-1', reporterUserId: 'customer-1',
      reason: 'Nội dung không phù hợp', status: 'LINKED', supportTicketId: 'ticket-1',
      attempts: 1, lastError: null, createdAt: '2026-10-18T01:00:00Z',
      updatedAt: '2026-10-18T01:01:00Z',
    }],
  });
  vi.mocked(bookingChatAdminApi.messages).mockResolvedValue({
    items: [{
      id: 'message-1', epochId: 'epoch-1', sequence: 1,
      senderUserId: 'caregiver-1', senderRole: 'CAREGIVER', kind: 'text',
      body: 'Tin nhắn cần kiểm tra', createdAt: '2026-10-18T01:00:00Z',
    }],
    nextBeforeSequence: null,
  });
  vi.mocked(bookingChatAdminApi.activity).mockResolvedValue({
    items: [{
      id: 'activity-1', actorUserId: 'admin-1', action: 'ADMIN_MESSAGES_VIEWED',
      reason: 'Điều tra report · ticket=ticket-1', createdAt: '2026-10-18T01:02:00Z',
    }],
    nextCursor: null,
  });
  render(<BookingChatConversations />);
  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenCalled());
  await userEvent.type(screen.getByLabelText('Lý do đọc nội dung *'), 'Điều tra report');
  await userEvent.type(screen.getByLabelText('Support ticket ID (nếu có)'), 'ticket-1');
  await userEvent.click(screen.getByRole('button', { name: 'Mở' }));

  expect((await screen.findByText('CAREGIVER')).parentElement?.textContent)
    .toContain('Tin nhắn cần kiểm tra');
  expect(screen.queryByText('Nội dung không phù hợp')).not.toBeNull();
  expect(screen.queryByText(/Ticket #TICKET-1/)).not.toBeNull();
  expect(screen.queryByText(/ADMIN_MESSAGES_VIEWED/)).not.toBeNull();
  expect(bookingChatAdminApi.get).toHaveBeenCalledWith('conversation-1', {
    reason: 'Điều tra report', ticketId: 'ticket-1',
  });
});

it('loads the next cursor page', async () => {
  render(<BookingChatConversations />);
  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenCalledWith(null, {}));

  await userEvent.click(screen.getByRole('button', { name: 'Trang sau' }));

  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenLastCalledWith('next', {}));
});

it('keeps the action reason draft when an expected-version conflict occurs', async () => {
  vi.mocked(bookingChatAdminApi.block).mockRejectedValue(new Error('Xung đột phiên bản'));
  render(<BookingChatConversations />);
  await waitFor(() => expect(bookingChatAdminApi.list).toHaveBeenCalledWith(null, {}));
  await userEvent.type(screen.getByLabelText('Lý do đọc nội dung *'), 'Điều tra report');
  await userEvent.click(screen.getByRole('button', { name: 'Mở' }));
  const draft = await screen.findByLabelText('Lý do thao tác *');
  await userEvent.type(draft, 'Khóa để điều tra');
  await userEvent.click(screen.getByLabelText('Tôi xác nhận thao tác này sẽ được ghi vào audit log.'));

  await userEvent.click(screen.getByRole('button', { name: 'Khóa chat' }));

  await screen.findByText('Xung đột phiên bản');
  expect(bookingChatAdminApi.block).toHaveBeenCalledWith(
    'conversation-1', 3, 'Khóa để điều tra');
  expect((draft as HTMLTextAreaElement).value).toBe('Khóa để điều tra');
});
