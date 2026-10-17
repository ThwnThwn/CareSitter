import { useState } from 'react';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { RefundRequest } from '../../types';
import { confirmManualRefund } from './paymentApi';

export function useRefundConfirmation(item: RefundRequest, onChanged: () => void) {
  const [providerRefundId, setProviderRefundId] = useState('');
  const [confirmationNote, setConfirmationNote] = useState('');
  const mutation = useAdminMutation<'confirm'>();
  const confirmable = item.status === 'MANUAL_REQUIRED';

  async function confirm(confirmAction: () => boolean) {
    if (mutation.busy || !confirmable) return;
    if (providerRefundId.trim().length < 3) {
      mutation.setError('Nhập mã hoàn tiền hoặc mã giao dịch từ provider, tối thiểu 3 ký tự.');
      return;
    }
    if (confirmationNote.trim().length < 10) {
      mutation.setError('Ghi chú đối soát cần ít nhất 10 ký tự.');
      return;
    }
    if (!confirmAction()) return;
    await mutation.run('confirm',
      signal => confirmManualRefund(item.id, providerRefundId.trim(), confirmationNote.trim(), signal),
      'Không thể xác nhận hoàn tiền.', onChanged);
  }

  return {
    providerRefundId, setProviderRefundId, confirmationNote, setConfirmationNote,
    confirmable, busy: mutation.busy, error: mutation.error, confirm,
  };
}
