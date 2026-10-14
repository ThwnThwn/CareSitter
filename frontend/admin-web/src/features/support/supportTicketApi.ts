import { api } from '../../api';

export function assignTicket(id: string, signal: AbortSignal) {
  return api<void>(`/api/v1/support/tickets/${id}/assign`, { method: 'PUT', signal });
}
export function updateTicketStatus(id: string, status: string, signal: AbortSignal) {
  return api<void>(`/api/v1/support/tickets/${id}/status`, { method: 'PUT', body: JSON.stringify({ status }), signal });
}
