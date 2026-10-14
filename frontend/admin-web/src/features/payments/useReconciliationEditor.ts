import { useState } from 'react';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { PaymentReview } from '../../types';
import { resolvePayment } from './paymentApi';

export function useReconciliationEditor(item: PaymentReview, onChanged: () => void) {
  const [reason, setReason] = useState('');
  const [transactionId, setTransactionId] = useState(item.providerTransactionId || '');
  const mutation = useAdminMutation<'confirm' | 'reject'>();
  async function resolve(succeeded: boolean, confirm: () => boolean) {
    if (mutation.busy || item.canResolve === false) return;
    if (reason.trim().length < 5) { mutation.setError('Ghi chú đối chiếu cần ít nhất 5 ký tự.'); return; }
    if (succeeded && !transactionId.trim()) { mutation.setError('Nhập mã giao dịch từ cổng thanh toán khi xác nhận thanh toán.'); return; }
    if (!confirm()) return;
    await mutation.run(succeeded ? 'confirm' : 'reject',
      signal => resolvePayment(item.intentId, { succeeded, reason: reason.trim(), providerTransactionId: transactionId.trim() || null }, signal),
      'Không thể chốt giao dịch.', onChanged);
  }
  return { reason, setReason, transactionId, setTransactionId, busy: mutation.busy, error: mutation.error, resolve };
}
