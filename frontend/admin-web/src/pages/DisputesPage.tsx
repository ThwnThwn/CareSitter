import { useState } from 'react';
import { Gavel, RefreshCw, XCircle } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, formatMoney, shortId } from '../components/Common';
import { Booking, Dispute } from '../types';
import { usePagedResource, useResource } from '../useResource';
import { disputeAllocation } from '../operations';

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

function DisputeDrawer({ dispute: selected, onClose, onChanged }: { dispute: Dispute; onClose: () => void; onChanged: () => void }) {
  const { disputeDecisions, reviewableStatuses } = useAdminMetadata();
  const detail = useResource<Dispute>(`/api/v1/admin/disputes/${selected.id}`, selected);
  const dispute = detail.data;
  const booking = useResource<Booking | null>(`/api/v1/bookings/${dispute.bookingId}`, null);
  const [decision, setDecision] = useState('');
  const [refundAmount, setRefundAmount] = useState(0);
  const [penaltyAmount, setPenaltyAmount] = useState(0);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const loading = detail.loading || booking.loading;
  const loadError = detail.error || booking.error;
  const actionable = !loading && !loadError && reviewableStatuses.disputes.includes(dispute.status);
  let allocation: ReturnType<typeof disputeAllocation> | undefined;
  let validation = '';
  if (actionable && booking.data && decision) {
    try { allocation = disputeAllocation(booking.data.escrowAmount, booking.data.platformFeeAmount, decision, refundAmount, penaltyAmount); }
    catch (cause) { validation = cause instanceof Error ? cause.message : 'Số tiền không hợp lệ.'; }
  }
  async function resolve() {
    if (busy || !actionable || !allocation || booking.data?.status !== 'disputed') return;
    if (!window.confirm(`Xác nhận phán quyết ${optionLabel(disputeDecisions, decision)}?\nHoàn khách: ${formatMoney(allocation.refund)}\nPhí nền tảng: ${formatMoney(allocation.fee)}\nChế tài: ${formatMoney(allocation.penalty)}\nCaregiver nhận: ${formatMoney(allocation.earning)}`)) return;
    setBusy('resolve'); setError('');
    try {
      await api(`/api/v1/disputes/${dispute.id}/resolve`, { method: 'POST', body: JSON.stringify({ decision, refundAmount: allocation.refund, caregiverPenaltyAmount: allocation.penalty }) });
      onChanged();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể giải quyết khiếu nại.');
      void detail.reload(); void booking.reload();
    } finally { setBusy(''); }
  }
  async function cancel() {
    if (busy || !actionable) return;
    if (!window.confirm('Hủy hồ sơ khiếu nại này? Thao tác hiện tại chỉ đóng hồ sơ, không tự hoàn tiền hoặc khôi phục trạng thái booking.')) return;
    setBusy('cancel'); setError('');
    try { await api(`/api/v1/disputes/${dispute.id}/cancel`, { method: 'POST' }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể hủy khiếu nại.'); }
    finally { setBusy(''); }
  }
  return <Drawer title={dispute.reason || 'Khiếu nại booking'} subtitle={shortId(dispute.id)} busy={!!busy} onClose={onClose}
    footer={actionable && <><button className="danger" disabled={!!busy} onClick={() => void cancel()}><XCircle size={17} /> {busy === 'cancel' ? 'Đang hủy…' : 'Hủy khiếu nại'}</button>
      <button className="primary" disabled={!!busy || !allocation || booking.data?.status !== 'disputed'} onClick={() => void resolve()}><Gavel size={17} /> {busy === 'resolve' ? 'Đang ghi nhận…' : 'Ghi nhận phán quyết'}</button></>}>
    {error && <ErrorBanner message={error} />}
    {loadError && <ErrorBanner message={loadError} onRetry={() => { void detail.reload(); void booking.reload(); }} />}
    {loading ? <LoadingTable rows={5} columns={2} /> : loadError ? null : <>
      <div className="drawer-status"><StatusChip value={dispute.status} /><span>Mở {formatDate(dispute.openedAt)}</span></div>
      <DetailList items={[{ label: 'Booking', value: dispute.bookingId }, { label: 'Người gửi', value: dispute.raisedByUserId }, { label: 'Mô tả', value: dispute.description },
        { label: 'Quyết định', value: optionLabel(disputeDecisions, dispute.decision) }, { label: 'Hoàn tiền đã ghi nhận', value: dispute.refundAmount == null ? '—' : formatMoney(dispute.refundAmount) },
        { label: 'Tiền giữ chờ của booking', value: formatMoney(booking.data?.escrowAmount) }]} />
      {actionable && <div className="form-stack">
        {booking.data?.status !== 'disputed' && <ErrorBanner message="Booking không còn ở trạng thái tranh chấp. Hãy kiểm tra sổ giao dịch trước khi xử lý tiếp." />}
        <label>Phán quyết<select disabled={!!busy} value={decision} onChange={(e) => { setDecision(e.target.value); setRefundAmount(0); setPenaltyAmount(0); }}>
          <option value="">Chọn phán quyết</option>{disputeDecisions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
        {decision === 'PARTIAL_REFUND' && <div className="form-columns">
          <label>Số tiền hoàn (VND)<input type="number" min="1" step="1" disabled={!!busy} max={(booking.data?.escrowAmount || 0) - 1} value={refundAmount} onChange={(e) => setRefundAmount(Number(e.target.value))} /></label>
          <label>Chế tài caregiver (VND)<input type="number" min="0" step="1" disabled={!!busy} value={penaltyAmount} onChange={(e) => setPenaltyAmount(Number(e.target.value))} /></label>
        </div>}
        {decision === 'CUSTOMER_WINS' && <p>Hoàn toàn bộ tiền giữ chờ cho khách; không khấu trừ thêm vào ví caregiver.</p>}
        {decision === 'CAREGIVER_WINS' && <p>Không hoàn tiền; caregiver nhận phần còn lại sau phí nền tảng.</p>}
        {validation && <ErrorBanner message={validation} />}
        {allocation && <section aria-label="Phân bổ tiền dự kiến" aria-live="polite"><h3>Phân bổ tiền dự kiến</h3><DetailList items={[
          { label: 'Hoàn cho khách', value: formatMoney(allocation.refund) }, { label: 'Phí nền tảng', value: formatMoney(allocation.fee) },
          { label: 'Chế tài', value: formatMoney(allocation.penalty) }, { label: 'Caregiver nhận', value: formatMoney(allocation.earning) },
        ]} /></section>}
      </div>}
    </>}
  </Drawer>;
}
