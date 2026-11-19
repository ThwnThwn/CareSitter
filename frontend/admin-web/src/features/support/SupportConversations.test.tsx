import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, expect, it, vi } from 'vitest';
import { TOKEN_KEY } from '../../api';
import { SupportConversations } from './SupportConversations';
import { supportChatApi, type ChatConversation } from './supportChatApi';

const hub = vi.hoisted(() => {
  const handlers = new Map<string, (event: { conversationId: string }) => void>();
  return {
    handlers,
    start: vi.fn(async () => undefined),
    stop: vi.fn(async () => undefined),
    invoke: vi.fn(async () => undefined),
    onreconnected: vi.fn(),
    on: (name: string, handler: (event: { conversationId: string }) => void) => handlers.set(name, handler),
  };
});
vi.mock('@microsoft/signalr', () => ({
  HubConnectionBuilder: class {
    withUrl() { return this; }
    withAutomaticReconnect() { return this; }
    build() { return hub; }
  },
}));

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
  vi.clearAllMocks();
  hub.handlers.clear();
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

const assigned: ChatConversation = { ...conversation, assignedAdminId: 'admin-1', status: 'IN_PROGRESS' };
const second = { ...assigned, id: 'conversation-2', subject: 'Lịch thứ hai' };

function twoConversations() {
  vi.mocked(supportChatApi.messages).mockResolvedValue({ items: [], hasMore: false,
    nextAfterSequence: 0, highWatermarkSequence: 0 });
  vi.mocked(supportChatApi.list).mockResolvedValue({ items: [assigned, second],
    hasMore: false, nextCreatedAt: null, nextId: null });
  vi.mocked(supportChatApi.get).mockImplementation(async id => id === assigned.id ? assigned : second);
}

it('keeps a reply for one customer out of the next customer’s conversation', async () => {
  twoConversations();
  render(<SupportConversations />);
  const [firstButton, secondButton] = await screen.findAllByRole('button', { name: 'Mở chat' });
  await userEvent.click(firstButton);
  await userEvent.type(await screen.findByLabelText('Tin nhắn'), 'Trả lời riêng cho khách thứ nhất');
  await userEvent.click(secondButton);
  await screen.findByRole('heading', { name: second.subject });
  expect((screen.getByLabelText('Tin nhắn') as HTMLTextAreaElement).value).toBe('');
});

it('loads the selected conversation while a previous request is still pending', async () => {
  twoConversations();
  let finishFirst!: (value: ChatConversation) => void;
  vi.mocked(supportChatApi.get).mockImplementation(id => id === assigned.id
    ? new Promise(resolve => { finishFirst = resolve; }) : Promise.resolve(second));
  render(<SupportConversations />);
  const [firstButton, secondButton] = await screen.findAllByRole('button', { name: 'Mở chat' });
  await userEvent.click(firstButton);
  await waitFor(() => expect(finishFirst).toBeDefined());
  await userEvent.click(secondButton);
  await screen.findByRole('heading', { name: second.subject });
  await act(async () => finishFirst(assigned));
  expect(screen.queryByRole('heading', { name: assigned.subject })).toBeNull();
});

it('keeps an active message read running and coalesces events for the open conversation', async () => {
  sessionStorage.setItem(TOKEN_KEY, 'test');
  const initial = vi.mocked(supportChatApi.messages).getMockImplementation()!;
  let finishRead!: () => void;
  vi.mocked(supportChatApi.messages).mockImplementationOnce((id, after, watermark, signal) =>
    new Promise(resolve => { finishRead = () => { void initial(id, after, watermark, signal).then(resolve); }; }));
  render(<SupportConversations />);
  await userEvent.click(await screen.findByRole('button', { name: 'Mở chat' }));
  await waitFor(() => expect(finishRead).toBeDefined());
  const emit = hub.handlers.get('AdminQueueChanged')!;
  await act(async () => emit({ conversationId: 'unrelated' }));
  expect(supportChatApi.messages).toHaveBeenCalledTimes(1);

  await act(async () => emit({ conversationId: conversation.id }));
  await act(async () => emit({ conversationId: conversation.id }));
  expect(supportChatApi.messages).toHaveBeenCalledTimes(1);

  await act(async () => finishRead());
  expect(await screen.findByText(/Tin 125/)).toBeTruthy();
  await waitFor(() => expect(supportChatApi.messages).toHaveBeenCalledTimes(3));
  expect(hub.start).toHaveBeenCalledTimes(1);
});

it('loads only the next page when expanding the queue', async () => {
  vi.mocked(supportChatApi.list)
    .mockResolvedValueOnce({ items: [conversation], hasMore: true,
      nextCreatedAt: conversation.createdAt, nextId: conversation.id })
    .mockResolvedValueOnce({ items: [second], hasMore: false, nextCreatedAt: null, nextId: null });
  render(<SupportConversations />);
  await userEvent.click(await screen.findByRole('button', { name: 'Tải thêm' }));
  expect(await screen.findByText(second.subject)).toBeTruthy();
  expect(screen.getByText(conversation.subject)).toBeTruthy();
  expect(supportChatApi.list).toHaveBeenCalledTimes(2);
  expect(vi.mocked(supportChatApi.list).mock.calls[1][1])
    .toEqual({ createdAt: conversation.createdAt, id: conversation.id });
});

it('recovers more than 100 messages and claims with the displayed version', async () => {
  render(<SupportConversations />);
  await userEvent.click(await screen.findByRole('button', { name: 'Mở chat' }));
  await waitFor(() => expect(screen.getByText(/Tin 125/)).toBeTruthy());
  expect(vi.mocked(supportChatApi.messages).mock.calls.some(([, after]) => after === 100)).toBe(true);
  await userEvent.click(screen.getByRole('button', { name: 'Nhận xử lý' }));
  await waitFor(() => expect(supportChatApi.claim).toHaveBeenCalledWith('conversation-1', 1));
});
