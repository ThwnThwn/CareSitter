import { api } from '../../api';

export interface ReconciliationDecision {
  succeeded: boolean;
  reason: string;
  providerTransactionId: string | null;
}
export function resolvePayment(intentId: string, decision: ReconciliationDecision, signal: AbortSignal) {
  return api<void>(`/api/v1/admin/payment-reconciliation/${intentId}/resolve`,
    { method: 'POST', body: JSON.stringify(decision), signal });
}
export function decidePayout(id: string, approved: boolean, reason: string, signal: AbortSignal) {
  return api<void>(`/api/v1/payments/payouts/${id}/${approved ? 'approve' : 'reject'}`,
    { method: 'POST', body: approved ? undefined : JSON.stringify({ reason }), signal });
}

export function confirmManualRefund(id: string, providerRefundId: string, confirmationNote: string, signal: AbortSignal) {
  return api<void>(`/api/v1/admin/refunds/${id}/confirm`, {
    method: 'POST', body: JSON.stringify({ providerRefundId, confirmationNote }), signal,
  });
}
