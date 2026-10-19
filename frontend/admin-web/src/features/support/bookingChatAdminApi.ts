import { api, jsonBody, qs } from '../../api';
import type {
  BookingChatAdminActivity,
  BookingChatAdminDetail,
  BookingChatAdminFilter,
  BookingChatAdminItem,
  BookingChatMessagePage,
  CursorPage,
} from '../../types';

const prefix = '/api/v1/admin/booking-chats';

export const bookingChatAdminApi = {
  list: (cursor?: string | null, filter: BookingChatAdminFilter = {}) =>
    api<CursorPage<BookingChatAdminItem>>(`${prefix}${qs({
      cursor,
      limit: 50,
      reported: filter.reported === undefined ? undefined : String(filter.reported),
      blocked: filter.blocked === undefined ? undefined : String(filter.blocked),
      deadLetter: filter.deadLetter === undefined ? undefined : String(filter.deadLetter),
      bookingId: filter.bookingId,
      userId: filter.userId,
      from: filter.from,
      to: filter.to,
    })}`),
  get: (id: string, context: { reason: string; ticketId?: string }) =>
    api<BookingChatAdminDetail>(`${prefix}/${id}${qs({
      reason: context.reason,
      ticketId: context.ticketId,
    })}`),
  messages: (id: string, context: { beforeSequence?: number | null; reason: string; ticketId?: string }) =>
    api<BookingChatMessagePage>(`${prefix}/${id}/messages${qs({
      beforeSequence: context.beforeSequence,
      reason: context.reason,
      ticketId: context.ticketId,
      limit: 50,
    })}`),
  activity: (id: string, cursor?: string | null) =>
    api<CursorPage<BookingChatAdminActivity>>(`${prefix}/${id}/activities${qs({ cursor, limit: 50 })}`),
  block: (id: string, expectedVersion: number, reason: string) =>
    api<BookingChatAdminDetail>(`${prefix}/${id}/block`, { method: 'PUT', ...jsonBody({ expectedVersion, reason }) }),
  unblock: (id: string, expectedVersion: number, reason: string) =>
    api<BookingChatAdminDetail>(`${prefix}/${id}/unblock`, { method: 'PUT', ...jsonBody({ expectedVersion, reason }) }),
  releaseLegalHold: (id: string, expectedVersion: number, reason: string) =>
    api<BookingChatAdminDetail>(`${prefix}/${id}/legal-hold/release`, { method: 'PUT', ...jsonBody({ expectedVersion, reason }) }),
};
