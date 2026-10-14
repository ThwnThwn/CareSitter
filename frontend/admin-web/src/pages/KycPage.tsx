import { KycDrawer } from '../features/kyc/KycDrawer';
export { KycDocument } from '../features/kyc/KycDocument';
import { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
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
