import { api } from '../../api';

export function completeBooking(id: string, signal: AbortSignal) {
  return api<void>(`/api/v1/bookings/${id}/complete`, { method: 'POST', signal });
}
