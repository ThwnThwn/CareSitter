import { useCallback, useEffect, useState } from 'react';
import { ExternalLink, RefreshCw, ShieldCheck, ShieldX } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { KycProfile, Paged } from '../types';

export function KycPage() {
  const { filters } = useAdminMetadata();
  const [result, setResult] = useState<Paged<KycProfile>>({ items: [], total: 0, page: 1, pageSize: 20 });
  const [status, setStatus] = useState(filters.kyc.defaultValue);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<KycProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { setResult(await api<Paged<KycProfile>>(`/api/v1/caregivers/kyc${qs({ status, page, pageSize: 20 })}`)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Không tải được hồ sơ KYC.'); }
    finally { setLoading(false); }
  }, [page, status]);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { setPage(1); }, [status]);

  return <>
    <PageHeader title="Nhân sự & KYC" description="Kiểm tra giấy tờ trước khi caregiver được phép nhận ca."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar"><label>Trạng thái hồ sơ<select value={status} onChange={(e) => setStatus(e.target.value)}>
      {filters.kyc.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}
    </select></label></section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">
      {loading ? <LoadingTable rows={7} columns={5} /> : result.items.length === 0
        ? <EmptyState title="Không có hồ sơ phù hợp" description="Hàng đợi KYC ở trạng thái này hiện đang trống." />
        : <div className="table-wrap"><table className="data-table"><thead><tr><th>Caregiver</th><th>Ngày sinh</th><th>Tài liệu</th><th>Cập nhật</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>{result.items.map((item) => <tr key={item.id}>
            <td><strong>{item.fullName || 'Chưa cập nhật tên'}</strong><small>{shortId(item.id)}</small></td>
            <td>{item.dateOfBirth ? formatDate(item.dateOfBirth, false) : '—'}</td>
            <td>{2 + (item.certificateUrls?.length || 0)} tệp</td><td>{formatDate(item.updatedAt)}</td>
            <td><StatusChip value={item.kycStatus} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Kiểm tra hồ sơ</button></td>
          </tr>)}</tbody></table></div>}
      <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />
    </section>
    {selected && <KycDrawer profile={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function KycDrawer({ profile, onClose, onChanged }: { profile: KycProfile; onClose: () => void; onChanged: () => void }) {
  const { constraints, reviewableStatuses } = useAdminMetadata();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState<'approve' | 'reject' | ''>('');
  const [error, setError] = useState('');
  const reviewable = reviewableStatuses.kyc.includes(profile.kycStatus);
  async function decide(approved: boolean) {
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
    { label: 'CCCD mặt trước', url: profile.cccdFrontUrl }, { label: 'CCCD mặt sau', url: profile.cccdBackUrl },
    ...(profile.certificateUrls || []).map((url, index) => ({ label: `Chứng chỉ ${index + 1}`, url })),
  ];
  return <Drawer title={profile.fullName || 'Hồ sơ caregiver'} subtitle="Xác minh KYC" onClose={onClose}
    footer={reviewable && <><button className="danger" disabled={!!busy} onClick={() => void decide(false)}><ShieldX size={17} /> {busy === 'reject' ? 'Đang từ chối…' : 'Từ chối hồ sơ'}</button><button className="primary" disabled={!!busy} onClick={() => void decide(true)}><ShieldCheck size={17} /> {busy === 'approve' ? 'Đang duyệt…' : 'Duyệt KYC'}</button></>}>
    <div className="drawer-status"><StatusChip value={profile.kycStatus} /><span>Nộp {formatDate(profile.updatedAt)}</span></div>
    {error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Mã hồ sơ', value: profile.id }, { label: 'Ngày sinh', value: profile.dateOfBirth ? formatDate(profile.dateOfBirth, false) : '—' }, { label: 'Giới tính', value: profile.gender }]} />
    <h3 className="subheading">Tài liệu đã nộp</h3>
    <div className="document-grid">{documents.map((document) => document.url ? <a href={document.url} target="_blank" rel="noreferrer" key={document.label}>
      <img src={document.url} alt={document.label} /><span>{document.label}<ExternalLink size={14} /></span>
    </a> : <div className="missing-document" key={document.label}><span>{document.label}</span><small>Chưa có tài liệu</small></div>)}</div>
    {reviewable && <label>Lý do từ chối<textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} placeholder="Nêu rõ tài liệu cần bổ sung hoặc thông tin chưa hợp lệ" /></label>}
  </Drawer>;
}
