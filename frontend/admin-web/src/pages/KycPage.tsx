import { useEffect, useState } from 'react';
import { ExternalLink, RefreshCw, ShieldCheck, ShieldX } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { api, kycImage, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { KycProfile } from '../types';
import { usePagedResource } from '../useResource';

export function KycPage() {
  const { filters } = useAdminMetadata();
  const [status, setStatus] = useState(filters.kyc.defaultValue);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<KycProfile | null>(null);
  const { data: result, loading, error, reload: load } = usePagedResource<KycProfile>(`/api/v1/caregivers/kyc${qs({ status, page, pageSize: 20 })}`, page, setPage);

  return <>
    <PageHeader title="Nhân sự & KYC" description="Kiểm tra giấy tờ trước khi caregiver được phép nhận ca."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar"><label>Trạng thái hồ sơ<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
      {filters.kyc.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}
    </select></label></section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">
      {loading ? <LoadingTable rows={7} columns={5} /> : error ? null : result.items.length === 0
        ? <EmptyState title="Không có hồ sơ phù hợp" description="Hàng đợi KYC ở trạng thái này hiện đang trống." />
        : <div className="table-wrap"><table className="data-table"><thead><tr><th>Caregiver</th><th>Ngày sinh</th><th>Tài liệu</th><th>Cập nhật</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>{result.items.map((item) => <tr key={item.id}>
            <td><strong>{item.fullName || 'Chưa cập nhật tên'}</strong><small>{shortId(item.id)}</small></td>
            <td>{item.dateOfBirth ? formatDate(item.dateOfBirth, false) : '—'}</td>
            <td>{[item.cccdFrontMediaId, item.cccdBackMediaId, ...(item.certificateMediaIds || [])].filter(Boolean).length} tệp{item.requiresSecureResubmission && <small>Cần chuyển tài liệu cũ</small>}</td><td>{formatDate(item.updatedAt)}</td>
            <td><StatusChip value={item.kycStatus} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Kiểm tra hồ sơ</button></td>
          </tr>)}</tbody></table></div>}
      {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}
    </section>
    {selected && <KycDrawer key={selected.id} profile={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function KycDrawer({ profile, onClose, onChanged }: { profile: KycProfile; onClose: () => void; onChanged: () => void }) {
  const { constraints, reviewableStatuses } = useAdminMetadata();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState<'approve' | 'reject' | ''>('');
  const [error, setError] = useState('');
  const reviewable = reviewableStatuses.kyc.includes(profile.kycStatus);
  const secureDocuments = !!profile.cccdFrontMediaId && !!profile.cccdBackMediaId && !profile.requiresSecureResubmission;
  async function decide(approved: boolean) {
    if (busy) return;
    if (approved && !secureDocuments) return setError('Cần caregiver nộp tài liệu riêng tư trước khi duyệt.');
    if (!approved && reason.trim().length < constraints.rejectionReasonMinLength) return setError(`Nhập lý do từ chối tối thiểu ${constraints.rejectionReasonMinLength} ký tự để caregiver biết cách bổ sung.`);
    if (approved && !window.confirm(`Duyệt hồ sơ của ${profile.fullName || 'caregiver này'}?`)) return;
    setBusy(approved ? 'approve' : 'reject'); setError('');
    try {
      await api(`/api/v1/caregivers/${profile.id}/kyc/${approved ? 'approve' : 'reject'}`, {
        method: 'POST', body: approved ? undefined : JSON.stringify({ reason: reason.trim() }),
      });
      onChanged();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể cập nhật KYC.'); }
    finally { setBusy(''); }
  }

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

export function KycDocument({ label, mediaId }: { label: string; mediaId?: string }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    if (!mediaId) return;
    const controller = new AbortController();
    let objectUrl = '';
    setUrl(''); setError('');
    void kycImage(mediaId, controller.signal).then((blob) => {
      if (controller.signal.aborted) return;
      objectUrl = URL.createObjectURL(blob); setUrl(objectUrl);
    }).catch((cause) => {
      if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : 'Không thể đọc tài liệu.');
    });
    return () => { controller.abort(); if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [mediaId, attempt]);
  if (!mediaId) return <div className="missing-document"><span>{label}</span><small>Chưa có tài liệu riêng tư</small></div>;
  if (!url) return <div className="missing-document" aria-live="polite"><span>{label}</span><small>{error || 'Đang tải tài liệu riêng tư…'}</small>{error && <button className="secondary" onClick={() => setAttempt((value) => value + 1)}>Thử lại</button>}</div>;
  return <a href={url} target="_blank" rel="noreferrer"><img src={url} alt={label} referrerPolicy="no-referrer" /><span>{label}<ExternalLink size={14} /></span></a>;
}
