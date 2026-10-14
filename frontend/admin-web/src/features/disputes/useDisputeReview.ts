import { useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { disputeAllocation } from '../../operations';
import { Booking, Dispute } from '../../types';
import { useResource } from '../../useResource';
import { cancelDispute, resolveDispute } from './disputeApi';

export function useDisputeReview(selected: Dispute, onChanged: () => void) {
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
  let allocation: ReturnType<typeof disputeAllocation> | undefined;
  let validation = '';
  if (actionable && booking.data && decision) {
    try { allocation = disputeAllocation(booking.data.escrowAmount, booking.data.platformFeeAmount, decision, refundAmount, penaltyAmount); }
    catch (cause) { validation = cause instanceof Error ? cause.message : 'Số tiền không hợp lệ.'; }
  }
  function reloadDetails() { void detail.reload(); void booking.reload(); }
  function chooseDecision(value: string) { setDecision(value); setRefundAmount(0); setPenaltyAmount(0); }
  async function resolve(confirm: () => boolean) {
    if (mutation.busy || !actionable || !allocation || booking.data?.status !== 'disputed' || !confirm()) return;
    const resolution = { decision, refundAmount: allocation.refund, caregiverPenaltyAmount: allocation.penalty };
    await mutation.run('resolve', signal => resolveDispute(dispute.id, resolution, signal),
      'Không thể giải quyết khiếu nại.', onChanged, reloadDetails);
  }
  async function cancel(confirm: () => boolean) {
    if (mutation.busy || !actionable || !confirm()) return;
    await mutation.run('cancel', signal => cancelDispute(dispute.id, signal), 'Không thể hủy khiếu nại.', onChanged);
  }
  return { dispute, booking: booking.data, decision, chooseDecision, refundAmount, setRefundAmount, penaltyAmount, setPenaltyAmount,
    loading, loadError, actionable, allocation, validation, reloadDetails, busy: mutation.busy, error: mutation.error, resolve, cancel };
}
