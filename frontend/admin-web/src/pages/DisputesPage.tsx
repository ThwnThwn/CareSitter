import { DisputeDrawer } from '../features/disputes/DisputeDrawer';
import { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { Dispute } from '../types';
import { usePagedResource } from '../useResource';

export function DisputesPage() {
  const { disputeDecisions, filters } = useAdminMetadata();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.disputes.defaultValue);
  const [selected, setSelected] = useState<Dispute | null>(null);
  const { data: result, loading, error, reload: load } = usePagedResource<Dispute>(`/api/v1/admin/disputes${qs({ status, page, pageSize: 20 })}`, page, setPage);
  return <>
    <PageHeader title="Khiếu nại" description="Phân xử tranh chấp booking và ghi nhận hoàn tiền hoặc chế tài."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar"><label>Trạng thái<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{filters.disputes.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label></section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">{loading ? <LoadingTable rows={7} columns={6} /> : error ? null : result.items.length === 0
      ? <EmptyState title="Không có khiếu nại" description="Không có hồ sơ phù hợp với trạng thái đã chọn." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Khiếu nại</th><th>Booking</th><th>Người gửi</th><th>Mở lúc</th><th>Quyết định</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((item) => <tr key={item.id}><td><strong>{item.reason || 'Khiếu nại booking'}</strong><small>{shortId(item.id)}</small></td><td>{shortId(item.bookingId)}</td><td>{shortId(item.raisedByUserId)}</td><td>{formatDate(item.openedAt)}</td><td>{optionLabel(disputeDecisions, item.decision)}</td><td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Xem hồ sơ</button></td></tr>)}</tbody></table></div>}
      {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}</section>
    {selected && <DisputeDrawer key={selected.id} dispute={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}
