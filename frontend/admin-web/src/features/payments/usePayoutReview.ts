import { useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { Payout } from '../../types';
import { decidePayout } from './paymentApi';

export function usePayoutReview(item: Payout, onChanged: () => void) {
  const { constraints, reviewableStatuses } = useAdminMetadata();
  const [reason, setReason] = useState('');
  const mutation = useAdminMutation<'approve' | 'reject'>();
  const reviewable = reviewableStatuses.payouts.includes(item.status);
  async function decide(approved: boolean, confirm: () => boolean) {
    if (mutation.busy || !reviewable) return;
    if (!approved && reason.trim().length < constraints.rejectionReasonMinLength) {
      mutation.setError(`Nhập lý do từ chối tối thiểu ${constraints.rejectionReasonMinLength} ký tự.`); return;
    }
    if (approved && !confirm()) return;
    await mutation.run(approved ? 'approve' : 'reject',
      signal => decidePayout(item.id, approved, reason.trim(), signal), 'Không thể xử lý yêu cầu rút tiền.', onChanged);
  }
  return { reason, setReason, reviewable, busy: mutation.busy, error: mutation.error, decide };
}
