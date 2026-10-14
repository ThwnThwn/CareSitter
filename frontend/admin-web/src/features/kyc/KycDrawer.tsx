import { ShieldCheck, ShieldX } from 'lucide-react';
import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate, shortId } from '../../components/Common';
import { KycProfile } from '../../types';
import { KycDocument } from './KycDocument';
import { useKycReview } from './useKycReview';

export function KycDrawer({ profile, onClose, onChanged }: { profile: KycProfile; onClose: () => void; onChanged: () => void }) {
  const { reason, setReason, busy, error, reviewable, secureDocuments, decide: submit } = useKycReview(profile, onChanged);
  async function decide(approved: boolean) { await submit(approved, () => window.confirm(`Duyệt hồ sơ của ${profile.fullName || 'caregiver này'}?`)); }

  const documents = [
    { label: 'CCCD mặt trước', mediaId: profile.cccdFrontMediaId }, { label: 'CCCD mặt sau', mediaId: profile.cccdBackMediaId },
    ...(profile.certificateMediaIds || []).map((mediaId, index) => ({ label: `Chứng chỉ ${index + 1}`, mediaId })),
  ];
  return <Drawer title={profile.fullName || 'Hồ sơ caregiver'} subtitle="Xác minh KYC" busy={!!busy} onClose={onClose}
    footer={reviewable && <><button className="danger" disabled={!!busy} onClick={() => void decide(false)}><ShieldX size={17} /> {busy === 'reject' ? 'Đang từ chối…' : 'Từ chối hồ sơ'}</button><button className="primary" disabled={!!busy || !secureDocuments} onClick={() => void decide(true)}><ShieldCheck size={17} /> {busy === 'approve' ? 'Đang duyệt…' : 'Duyệt KYC'}</button></>}>
    <div className="drawer-status"><StatusChip value={profile.kycStatus} /><span>Nộp {formatDate(profile.updatedAt)}</span></div>
    {error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Mã hồ sơ', value: profile.id }, { label: 'Ngày sinh', value: profile.dateOfBirth ? formatDate(profile.dateOfBirth, false) : '—' }, { label: 'Giới tính', value: profile.gender }]} />
    <h3 className="subheading">Tài liệu đã nộp</h3>
    {profile.requiresSecureResubmission && <p role="status">Tài liệu cũ không được mở qua URL công khai. Từ chối hồ sơ đang chờ duyệt với hướng dẫn nộp lại; hồ sơ đã duyệt cần quy trình chuyển đổi riêng.</p>}
    <div className="document-grid">{documents.map((document) => <KycDocument key={document.label} {...document} />)}</div>
    {reviewable && <label>Lý do từ chối<textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} placeholder="Nêu rõ tài liệu cần bổ sung hoặc thông tin chưa hợp lệ" /></label>}
  </Drawer>;
}
