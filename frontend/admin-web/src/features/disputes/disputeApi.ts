import { api } from '../../api';

export interface DisputeResolution { decision: string; refundAmount: number; caregiverPenaltyAmount: number }
export function resolveDispute(id: string, resolution: DisputeResolution, signal: AbortSignal) {
  return api<void>(`/api/v1/disputes/${id}/resolve`, { method: 'POST', body: JSON.stringify(resolution), signal });
}
export function cancelDispute(id: string, signal: AbortSignal) {
  return api<void>(`/api/v1/disputes/${id}/cancel`, { method: 'POST', signal });
}
