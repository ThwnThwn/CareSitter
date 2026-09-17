import { useCallback, useEffect, useState } from 'react';
import { Gavel, RefreshCw, XCircle } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, formatMoney, shortId } from '../components/Common';
import { Dispute, Paged } from '../types';

export function DisputesPage() {
  const { disputeDecisions, filters } = useAdminMetadata();
  const [result, setResult] = useState<Paged<Dispute>>({ items: [], total: 0, page: 1, pageSize: 20 });
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.disputes.defaultValue);
  const [selected, setSelected] = useState<Dispute | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { setResult(await api<Paged<Dispute>>(`/api/v1/admin/disputes${qs({ status, page, pageSize: 20 })}`)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Không tải được danh sách khiếu nại.'); }
    finally { setLoading(false); }
  }, [page, status]);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { setPage(1); }, [status]);
  return <>
    <PageHeader title="Khiếu nại" description="Phân xử tranh chấp booking và ghi nhận hoàn tiền hoặc chế tài."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar"><label>Trạng thái<select value={status} onChange={(e) => setStatus(e.target.value)}>{filters.disputes.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label></section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">{loading ? <LoadingTable rows={7} columns={6} /> : result.items.length === 0
      ? <EmptyState title="Không có khiếu nại" description="Không có hồ sơ phù hợp với trạng thái đã chọn." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Khiếu nại</th><th>Booking</th><th>Người gửi</th><th>Mở lúc</th><th>Quyết định</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((item) => <tr key={item.id}><td><strong>{item.reason || 'Khiếu nại booking'}</strong><small>{shortId(item.id)}</small></td><td>{shortId(item.bookingId)}</td><td>{shortId(item.raisedByUserId)}</td><td>{formatDate(item.openedAt)}</td><td>{optionLabel(disputeDecisions, item.decision)}</td><td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Xem hồ sơ</button></td></tr>)}</tbody></table></div>}
      <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} /></section>
    {selected && <DisputeDrawer dispute={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function DisputeDrawer({ dispute, onClose, onChanged }: { dispute: Dispute; onClose: () => void; onChanged: () => void }) {
  const { disputeDecisions, reviewableStatuses } = useAdminMetadata();
  const [decision, setDecision] = useState(disputeDecisions[0]?.value || '');
  const [refundAmount, setRefundAmount] = useState(0);
  const [penaltyAmount, setPenaltyAmount] = useState(0);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const actionable = reviewableStatuses.disputes.includes(dispute.status);
  async function resolve() {
    if (!window.confirm('Xác nhận phán quyết? Hệ thống có thể ghi hoàn tiền và chế tài vào sổ cái.')) return;
    setBusy('resolve'); setError('');
    try { await api(`/api/v1/disputes/${dispute.id}/resolve`, { method: 'POST', body: JSON.stringify({ decision, refundAmount: refundAmount || null, caregiverPenaltyAmount: penaltyAmount || null }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể giải quyết khiếu nại.'); }
    finally { setBusy(''); }
  }
  async function cancel() {
    if (!window.confirm('Hủy hồ sơ khiếu nại này?')) return;
    setBusy('cancel'); setError('');
    try { await api(`/api/v1/disputes/${dispute.id}/cancel`, { method: 'POST' }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể hủy khiếu nại.'); }
    finally { setBusy(''); }
  }
  return <Drawer title={dispute.reason || 'Khiếu nại booking'} subtitle={shortId(dispute.id)} onClose={onClose}
    footer={actionable && <><button className="danger" disabled={!!busy} onClick={() => void cancel()}><XCircle size={17} /> {busy === 'cancel' ? 'Đang hủy…' : 'Hủy khiếu nại'}</button><button className="primary" disabled={!!busy} onClick={() => void resolve()}><Gavel size={17} /> {busy === 'resolve' ? 'Đang ghi nhận…' : 'Ghi nhận phán quyết'}</button></>}>
    <div className="drawer-status"><StatusChip value={dispute.status} /><span>Mở {formatDate(dispute.openedAt)}</span></div>{error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Booking', value: dispute.bookingId }, { label: 'Người gửi', value: dispute.raisedByUserId }, { label: 'Mô tả', value: dispute.description }, { label: 'Quyết định', value: optionLabel(disputeDecisions, dispute.decision) }, { label: 'Hoàn tiền', value: dispute.refundAmount ? formatMoney(dispute.refundAmount) : '—' }]} />
    {actionable && <div className="form-stack"><label>Phán quyết<select value={decision} onChange={(e) => setDecision(e.target.value)}>{disputeDecisions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
      <div className="form-columns"><label>Số tiền hoàn<input type="number" min="0" value={refundAmount} onChange={(e) => setRefundAmount(Number(e.target.value))} /></label><label>Chế tài caregiver<input type="number" min="0" value={penaltyAmount} onChange={(e) => setPenaltyAmount(Number(e.target.value))} /></label></div></div>}
  </Drawer>;
}
