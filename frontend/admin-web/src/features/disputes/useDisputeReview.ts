import { useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import type { DisputeQuote } from './disputeApi';
import { Booking, Dispute } from '../../types';
import { useResource } from '../../useResource';
import { cancelDispute, resolveDispute } from './disputeApi';

export function useDisputeReview(selected: Dispute, onChanged: (message: string) => void) {
  const { reviewableStatuses } = useAdminMetadata();
  const detail = useResource<Dispute>(`/api/v1/admin/disputes/${selected.id}`, selected);
  const dispute = detail.data;
  const booking = useResource<Booking | null>(`/api/v1/bookings/${dispute.bookingId}`, null);
  const [decision, setDecision] = useState('');
  const [refundAmount, setRefundAmount] = useState(0);
  const [penaltyAmount, setPenaltyAmount] = useState(0);
  const mutation = useAdminMutation<'resolve' | 'cancel'>();
  const loading = detail.loading || booking.loading;
  const loadError = detail.error || booking.error;
  const actionable = !loading && !loadError && reviewableStatuses.disputes.includes(dispute.status);
  const previewPath = actionable && booking.data?.status === 'disputed' && decision
    ? `/api/v1/disputes/${dispute.id}/preview?decision=${encodeURIComponent(decision)}&refundAmount=${refundAmount}&caregiverPenaltyAmount=${penaltyAmount}`
    : null;
  const preview = useResource<DisputeQuote | null>(previewPath, null);
  const allocation = previewPath && !preview.error && !preview.loading ? preview.data : null;
  const validation = preview.error;
  function reloadDetails() { void detail.reload(); void booking.reload(); void preview.reload(); }
  function chooseDecision(value: string) { setDecision(value); setRefundAmount(0); setPenaltyAmount(0); }
  async function resolve(confirm: () => boolean | Promise<boolean>) {
    if (mutation.busy || !actionable || !allocation || booking.data?.status !== 'disputed' || !(await confirm())) return;
    const resolution = { decision, refundAmount: allocation.refund, caregiverPenaltyAmount: allocation.penalty, expectedQuote: allocation };
    await mutation.run('resolve', signal => resolveDispute(dispute.id, resolution, signal),
      'Không thể giải quyết khiếu nại.', onChanged, 'Phán quyết đã được ghi nhận.', reloadDetails);
  }
  async function cancel(confirm: () => boolean | Promise<boolean>) {
    if (mutation.busy || !actionable || !(await confirm())) return;
    await mutation.run('cancel', signal => cancelDispute(dispute.id, signal), 'Không thể hủy khiếu nại.', onChanged, 'Hủy khiếu nại thành công.');
  }
  return { dispute, booking: booking.data, decision, chooseDecision, refundAmount, setRefundAmount, penaltyAmount, setPenaltyAmount,
    loading, loadError, actionable, allocation, validation, reloadDetails, busy: mutation.busy, error: mutation.error, resolve, cancel };
}
