import { api, qs } from '../../api';

export type ChatConversation = {
  id: string;
  ticketId: string;
  ownerUserId: string;
  subject: string;
  status: 'NEW' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED';
  assignedAdminId: string | null;
  ticketVersion: number;
  lastSequence: number;
  ownLastReadSequence: number;
  unreadCount: number;
  createdAt: string;
};

export type ChatMessage = {
  id: string;
  sequence: number;
  senderUserId: string;
  senderRole: string;
  body: string;
  createdAt: string;
};

type ChatList = {
  items: ChatConversation[];
  hasMore: boolean;
  nextCreatedAt: string | null;
  nextId: string | null;
};

type ChatPage = {
  items: ChatMessage[];
  hasMore: boolean;
  nextAfterSequence: number | null;
  highWatermarkSequence: number;
};

export const supportChatApi = {
  config: () => api<{ enabled: boolean }>('/api/v1/support/chat-config'),
  list: (queue: string, cursor?: { createdAt: string; id: string }) =>
    api<ChatList>(`/api/v1/admin/support/conversations${qs({
      queue, limit: 50, beforeCreatedAt: cursor?.createdAt, beforeId: cursor?.id,
    })}`),
  get: (id: string) => api<ChatConversation>(`/api/v1/support/conversations/${id}`),
  messages: (id: string, afterSequence: number, highWatermarkSequence?: number) =>
    api<ChatPage>(`/api/v1/support/conversations/${id}/messages${qs({
      afterSequence, highWatermarkSequence, limit: 100,
    })}`),
  read: (id: string, lastReadSequence: number) =>
    api<ChatConversation>(`/api/v1/support/conversations/${id}/read`, {
      method: 'PUT', body: JSON.stringify({ lastReadSequence }),
    }),
  send: (id: string, body: string, key: string) =>
    api<ChatMessage>(`/api/v1/support/conversations/${id}/messages`, {
      method: 'POST', headers: { 'Idempotency-Key': key }, body: JSON.stringify({ body }),
    }),
  claim: (id: string, expectedVersion: number) =>
    api<ChatConversation>(`/api/v1/admin/support/conversations/${id}/claim`, {
      method: 'POST', body: JSON.stringify({ expectedVersion }),
    }),
  transfer: (id: string, targetAdminId: string, takeover: boolean,
    expectedVersion: number, reason: string) =>
    api<ChatConversation>(`/api/v1/admin/support/conversations/${id}/assignment`, {
      method: 'PATCH', body: JSON.stringify({ targetAdminId, takeover, expectedVersion, reason }),
    }),
  status: (id: string, status: 'RESOLVED' | 'CLOSED', expectedVersion: number, reason: string) =>
    api<ChatConversation>(`/api/v1/admin/support/conversations/${id}/status`, {
      method: 'PATCH', body: JSON.stringify({ status, expectedVersion, reason }),
    }),
};
