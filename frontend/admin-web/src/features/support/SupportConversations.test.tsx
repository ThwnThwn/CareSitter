import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, expect, it, vi } from 'vitest';
import { SupportConversations } from './SupportConversations';
import { supportChatApi, type ChatConversation } from './supportChatApi';

vi.mock('../../adminMetadata', () => ({
  useAdminMetadata: () => ({ currentUser: { id: 'admin-1' }, statusDefinitions: {} }),
}));
vi.mock('./supportChatApi', () => ({
  supportChatApi: {
    config: vi.fn(), list: vi.fn(), get: vi.fn(), messages: vi.fn(),
    read: vi.fn(), send: vi.fn(), claim: vi.fn(), transfer: vi.fn(), status: vi.fn(),
  },
}));

const conversation: ChatConversation = {
  id: 'conversation-1', ticketId: 'ticket-1', ownerUserId: 'customer-1',
  subject: 'Hỏi lịch chăm sóc', status: 'NEW', assignedAdminId: null,
  ticketVersion: 1, lastSequence: 125, ownLastReadSequence: 0,
  unreadCount: 125, createdAt: '2026-10-15T01:00:00Z',
};

beforeEach(() => {
  vi.mocked(supportChatApi.config).mockResolvedValue({ enabled: true });
  vi.mocked(supportChatApi.list).mockResolvedValue({ items: [conversation],
    hasMore: false, nextCreatedAt: null, nextId: null });
  vi.mocked(supportChatApi.get).mockResolvedValue(conversation);
  vi.mocked(supportChatApi.messages).mockImplementation(async (_id, after) => {
    const end = Math.min(after + 100, 125);
    return {
      items: Array.from({ length: end - after }, (_, index) => ({
        id: String(after + index + 1), sequence: after + index + 1,
        senderUserId: 'customer-1', senderRole: 'CUSTOMER',
        body: `Tin ${after + index + 1}`, createdAt: '2026-10-15T01:00:00Z',
      })),
      hasMore: end < 125, nextAfterSequence: end, highWatermarkSequence: 125,
    };
  });
  vi.mocked(supportChatApi.read).mockResolvedValue(conversation);
  vi.mocked(supportChatApi.claim).mockResolvedValue({ ...conversation,
    status: 'IN_PROGRESS', assignedAdminId: 'admin-1', ticketVersion: 2 });
});

it('recovers more than 100 messages and claims with the displayed version', async () => {
  render(<SupportConversations />);
  await userEvent.click(await screen.findByRole('button', { name: 'Mở chat' }));
  await waitFor(() => expect(screen.getByText(/Tin 125/)).toBeTruthy());
  expect(vi.mocked(supportChatApi.messages).mock.calls.some(([, after]) => after === 100)).toBe(true);
  await userEvent.click(screen.getByRole('button', { name: 'Nhận xử lý' }));
  await waitFor(() => expect(supportChatApi.claim).toHaveBeenCalledWith('conversation-1', 1));
});
