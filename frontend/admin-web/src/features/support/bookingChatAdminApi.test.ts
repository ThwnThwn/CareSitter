import { expect, it, vi } from 'vitest';
import { bookingChatAdminApi } from './bookingChatAdminApi';

it('sends cursor, read context, and PUT mutations using the backend contract', async () => {
  const fetch = vi.fn().mockImplementation(async () =>
    Response.json({ items: [], nextCursor: null }));
  vi.stubGlobal('fetch', fetch);

  await bookingChatAdminApi.list('next-page', { reported: true, deadLetter: false });
  await bookingChatAdminApi.messages('conversation', {
    beforeSequence: 42,
    reason: 'Điều tra khiếu nại',
    ticketId: 'ticket-id',
  });
  await bookingChatAdminApi.block('conversation', 3, 'Vi phạm');

  expect(String(fetch.mock.calls[0][0])).toContain('cursor=next-page');
  expect(String(fetch.mock.calls[0][0])).toContain('reported=true');
  expect(String(fetch.mock.calls[0][0])).toContain('deadLetter=false');
  expect(String(fetch.mock.calls[1][0])).toContain('beforeSequence=42');
  expect(String(fetch.mock.calls[1][0])).toContain('reason=%C4%90i%E1%BB%81u+tra+khi%E1%BA%BFu+n%E1%BA%A1i');
  expect(String(fetch.mock.calls[1][0])).toContain('ticketId=ticket-id');
  expect(fetch.mock.calls[2][1]).toEqual(expect.objectContaining({ method: 'PUT' }));
});
