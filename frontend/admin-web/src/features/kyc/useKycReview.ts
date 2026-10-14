import { useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { KycProfile } from '../../types';
import { decideKyc } from './kycApi';

export function useKycReview(profile: KycProfile, onChanged: () => void) {
  const { constraints, reviewableStatuses } = useAdminMetadata();
  const [reason, setReason] = useState('');
  const mutation = useAdminMutation<'approve' | 'reject'>();
  const reviewable = reviewableStatuses.kyc.includes(profile.kycStatus);
  const secureDocuments = !!profile.cccdFrontMediaId && !!profile.cccdBackMediaId && !profile.requiresSecureResubmission;
  async function decide(approved: boolean, confirm: () => boolean) {
    if (mutation.busy || !reviewable) return;
    if (approved && !secureDocuments) { mutation.setError('Cần caregiver nộp tài liệu riêng tư trước khi duyệt.'); return; }
    if (!approved && reason.trim().length < constraints.rejectionReasonMinLength) {
      mutation.setError(`Nhập lý do từ chối tối thiểu ${constraints.rejectionReasonMinLength} ký tự để caregiver biết cách bổ sung.`); return;
    }
    if (approved && !confirm()) return;
    await mutation.run(approved ? 'approve' : 'reject', signal => decideKyc(profile.id, approved, reason.trim(), signal),
      'Không thể cập nhật KYC.', onChanged);
  }
  return { reason, setReason, reviewable, secureDocuments, busy: mutation.busy, error: mutation.error, decide };
}
