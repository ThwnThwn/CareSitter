import { useMemo, useState } from 'react';
import { BadgeCheck, Ban, RefreshCw, Search } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, Tabs, formatDate, formatMoney, shortId } from '../components/Common';
import { PaymentReview, Payout } from '../types';
import { usePagedResource, useResource } from '../useResource';

export function PaymentsPage() {
  const [tab, setTab] = useState('reconciliation');
  return <>
    <PageHeader title="Thanh toán" description="Đối soát giao dịch chưa rõ trạng thái và duyệt yêu cầu rút tiền." />
    <Tabs value={tab} onChange={setTab} items={[{ value: 'reconciliation', label: 'Đối soát thanh toán' }, { value: 'payouts', label: 'Rút tiền caregiver' }]} />
    {tab === 'reconciliation' ? <ReconciliationQueue /> : <PayoutQueue />}
  </>;
}

function ReconciliationQueue() {
  const [selected, setSelected] = useState<PaymentReview | null>(null);
  const [query, setQuery] = useState('');
  const { data: items, loading, error, reload: load } = useResource<PaymentReview[]>('/api/v1/admin/payment-reconciliation', []);
  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    return !term ? items : items.filter((x) => [x.bookingId, x.intentId, x.providerOrderRef].some((value) => value?.toLowerCase().includes(term)));
  }, [items, query]);

  return <section className="data-panel tab-panel">
    <div className="panel-heading"><div><h2>Giao dịch cần kiểm tra</h2><p>Chỉ quyết định sau khi đã đối chiếu merchant portal hoặc sao kê.</p></div>
      <div className="toolbar"><label className="search-field compact"><Search size={16} /><input aria-label="Lọc giao dịch đã tải" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Lọc tối đa 100 giao dịch đã tải…" /></label><button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button></div></div>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading ? <LoadingTable rows={6} columns={5} /> : error ? null : filtered.length === 0
      ? <EmptyState title={query.trim() ? "Không có giao dịch khớp từ khóa" : "Không có giao dịch tồn đọng"} description={query.trim() ? "Không có kết quả trong danh sách đã tải. Thử đổi từ khóa." : "Không có giao dịch chờ đối soát trong danh sách đã tải."} />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Booking / TxnRef</th><th>Số tiền</th><th>Lần query</th><th>Deadline</th><th /></tr></thead><tbody>
        {filtered.map((item) => <tr key={item.intentId}><td><strong>{shortId(item.bookingId)}</strong><small className="mono">{item.providerOrderRef || 'Chưa có TxnRef'}</small></td>
          <td><strong>{formatMoney(item.amount)}</strong><small>{item.currency}</small></td><td>{item.reconciliationAttempts} lần</td>
          <td><strong>{formatDate(item.paymentDeadline)}</strong><small>{new Date(item.paymentDeadline) < new Date() ? 'Đã quá hạn' : 'Còn hiệu lực'}</small></td>
          <td><button className="row-action" onClick={() => setSelected(item)}>Xử lý</button></td></tr>)}</tbody></table></div>}
    {selected && <ReconciliationDrawer key={selected.intentId} item={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </section>;
}

function ReconciliationDrawer({ item, onClose, onChanged }: { item: PaymentReview; onClose: () => void; onChanged: () => void }) {
  const [reason, setReason] = useState('');
  const [transactionId, setTransactionId] = useState(item.providerTransactionId || '');
  const [busy, setBusy] = useState<'confirm' | 'reject' | ''>('');
  const [error, setError] = useState('');
  async function resolve(succeeded: boolean) {
    if (busy) return;
    if (reason.trim().length < 5) return setError('Ghi chú đối chiếu cần ít nhất 5 ký tự.');
    if (succeeded && !transactionId.trim()) return setError('Nhập mã giao dịch VNPay khi xác nhận thanh toán.');
    if (!window.confirm(`${succeeded ? 'Xác nhận đã nhận' : 'Từ chối'} ${formatMoney(item.amount)} cho booking ${shortId(item.bookingId)}?\n${succeeded ? 'Mã giao dịch: ' + transactionId.trim() : 'Booking sẽ bị hủy và slot caregiver được trả lại.'}`)) return;
    setBusy(succeeded ? 'confirm' : 'reject'); setError('');
    try {
      await api(`/api/v1/admin/payment-reconciliation/${item.intentId}/resolve`, { method: 'POST', body: JSON.stringify({ succeeded, reason: reason.trim(), providerTransactionId: transactionId.trim() || null }) });
      onChanged();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể chốt giao dịch.'); }
    finally { setBusy(''); }
  }
  return <Drawer title="Chốt giao dịch" subtitle="Đối soát thủ công" busy={!!busy} onClose={onClose} footer={<><button className="danger" disabled={!!busy} onClick={() => void resolve(false)}><Ban size={17} /> {busy === 'reject' ? 'Đang hủy…' : 'Từ chối thanh toán'}</button><button className="primary" disabled={!!busy} onClick={() => void resolve(true)}><BadgeCheck size={17} /> {busy === 'confirm' ? 'Đang xác nhận…' : 'Xác nhận đã thanh toán'}</button></>}>
    <div className="warning-box"><strong>Quyết định ảnh hưởng trực tiếp đến booking</strong><p>Xác nhận sẽ kích hoạt booking và khóa escrow; từ chối sẽ hủy booking và trả slot caregiver.</p></div>
    {error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Booking', value: item.bookingId }, { label: 'VNPay TxnRef', value: item.providerOrderRef }, { label: 'Số tiền', value: formatMoney(item.amount) }, { label: 'Lần query', value: item.reconciliationAttempts }, { label: 'Lỗi gần nhất', value: item.lastReconciliationError || item.manualReviewReason }]} />
    <label>Mã giao dịch VNPay<input value={transactionId} onChange={(e) => setTransactionId(e.target.value)} placeholder="Nhập từ merchant portal" /></label>
    <label>Ghi chú đối chiếu<textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={4} placeholder="Ví dụ: Đã đối chiếu merchant portal lúc 15:42" /></label>
  </Drawer>;
}

function PayoutQueue() {
  const { filters } = useAdminMetadata();
  const [status, setStatus] = useState(filters.payouts.defaultValue);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<Payout | null>(null);
  const { data: result, loading, error, reload: load } = usePagedResource<Payout>(`/api/v1/payments/payouts/pending${qs({ status, page, pageSize: 20 })}`, page, setPage);
  return <section className="data-panel tab-panel">
    <div className="panel-heading"><div><h2>Yêu cầu rút tiền</h2><p>Kiểm tra người thụ hưởng trước khi ghi nhận duyệt rút tiền.</p></div><label>Trạng thái<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{filters.payouts.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label></div>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading ? <LoadingTable rows={6} columns={6} /> : error ? null : result.items.length === 0
      ? <EmptyState title="Không có yêu cầu rút tiền" description="Không có yêu cầu phù hợp với trạng thái đã chọn." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Người thụ hưởng</th><th>Ngân hàng</th><th>Số tài khoản</th><th>Số tiền</th><th>Yêu cầu lúc</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((item) => <tr key={item.id}><td><strong>{item.accountHolderName}</strong><small>{shortId(item.caregiverId)}</small></td><td>{item.bankName}</td><td className="mono">{item.accountNumber}</td><td><strong>{formatMoney(item.amount)}</strong></td><td>{formatDate(item.requestedAt)}</td><td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Xem yêu cầu</button></td></tr>)}</tbody></table></div>}
    {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}
    {selected && <PayoutDrawer key={selected.id} item={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </section>;
}

function PayoutDrawer({ item, onClose, onChanged }: { item: Payout; onClose: () => void; onChanged: () => void }) {
  const { constraints, reviewableStatuses } = useAdminMetadata();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState<'approve' | 'reject' | ''>('');
  const [error, setError] = useState('');
  const reviewable = reviewableStatuses.payouts.includes(item.status);
  async function decide(approved: boolean) {
    if (busy) return;
    if (!approved && reason.trim().length < constraints.rejectionReasonMinLength) return setError(`Nhập lý do từ chối tối thiểu ${constraints.rejectionReasonMinLength} ký tự.`);
    if (approved && !window.confirm(`Duyệt yêu cầu ${formatMoney(item.amount)} cho ${item.accountHolderName}? Hệ thống ghi sổ rút tiền nhưng chưa tự chuyển khoản ngân hàng.`)) return;
    setBusy(approved ? 'approve' : 'reject'); setError('');
    try { await api(`/api/v1/payments/payouts/${item.id}/${approved ? 'approve' : 'reject'}`, { method: 'POST', body: approved ? undefined : JSON.stringify({ reason: reason.trim() }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể xử lý yêu cầu rút tiền.'); }
    finally { setBusy(''); }
  }
  return <Drawer title={formatMoney(item.amount)} subtitle="Yêu cầu rút tiền" busy={!!busy} onClose={onClose}
    footer={reviewable && <><button className="danger" disabled={!!busy} onClick={() => void decide(false)}>Từ chối yêu cầu</button><button className="primary" disabled={!!busy} onClick={() => void decide(true)}>Duyệt yêu cầu</button></>}>
    <div className="drawer-status"><StatusChip value={item.status} /><span>{formatDate(item.requestedAt)}</span></div>{error && <ErrorBanner message={error} />}
    {reviewable && <div className="warning-box"><strong>Duyệt yêu cầu chưa phải xác nhận đã chuyển khoản</strong><p>Thao tác hiện tại ghi sổ rút tiền. Việc chuyển khoản ngân hàng cần thực hiện và đối chiếu theo quy trình vận hành.</p></div>}
    <DetailList items={[{ label: 'Người thụ hưởng', value: item.accountHolderName }, { label: 'Ngân hàng', value: item.bankName }, { label: 'Số tài khoản', value: <span className="mono copy-value">{item.accountNumber}</span> }, { label: 'Caregiver', value: item.caregiverId }, { label: 'Số tiền', value: formatMoney(item.amount) }, { label: 'Lý do từ chối', value: item.rejectReason }]} />
    {reviewable && <label>Lý do từ chối<textarea rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Nêu rõ thông tin cần caregiver cập nhật" /></label>}
  </Drawer>;
}
