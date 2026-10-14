import { api } from '../../api';

export function decideKyc(id: string, approved: boolean, reason: string, signal: AbortSignal) {
  return api<void>(`/api/v1/caregivers/${id}/kyc/${approved ? 'approve' : 'reject'}`,
    { method: 'POST', body: approved ? undefined : JSON.stringify({ reason }), signal });
}
