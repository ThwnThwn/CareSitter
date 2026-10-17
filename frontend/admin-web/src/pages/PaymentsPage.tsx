import { ReconciliationDrawer } from '../features/payments/ReconciliationDrawer';
import { PayoutDrawer } from '../features/payments/PayoutDrawer';
import { RefundDrawer } from '../features/payments/RefundDrawer';
import { useMemo, useState } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, Tabs, formatDate, formatMoney, shortId } from '../components/Common';
import { PaymentReview, Payout, RefundRequest } from '../types';
import { usePagedResource, useResource } from '../useResource';

export function PaymentsPage() {
  const [tab, setTab] = useState('reconciliation');
  return <>
    <PageHeader title="Thanh toán" description="Đối soát thu tiền, theo dõi payout caregiver và hoàn tiền về phương thức gốc." />
    <Tabs value={tab} onChange={setTab} items={[{ value: 'reconciliation', label: 'Đối soát thanh toán' }, { value: 'payouts', label: 'Rút tiền caregiver' }, { value: 'refunds', label: 'Hoàn tiền' }]} />
    {tab === 'reconciliation' ? <ReconciliationQueue /> : tab === 'payouts' ? <PayoutQueue /> : <RefundQueue />}
  </>;
}

const refundStatuses = [
  { value: 'ALL', label: 'Tất cả' },
  { value: 'MANUAL_REQUIRED', label: 'Cần hoàn thủ công' },
  { value: 'PENDING', label: 'Đang chờ' },
  { value: 'PROCESSING', label: 'Đang xử lý' },
  { value: 'UNKNOWN', label: 'Cần đối soát' },
  { value: 'SUCCEEDED', label: 'Đã hoàn' },
  { value: 'FAILED', label: 'Thất bại' },
];

function RefundQueue() {
  const [status, setStatus] = useState('ALL');
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<RefundRequest | null>(null);
  const { data: result, loading, error, reload: load } = usePagedResource<RefundRequest>(`/api/v1/admin/refunds${qs({ status, page, pageSize: 20 })}`, page, setPage);
  return <section className="data-panel tab-panel">
    <div className="panel-heading"><div><h2>Refund theo phương thức gốc</h2><p>payOS cần xử lý ngoài hệ thống; chỉ ghi ledger sau khi provider hoặc ngân hàng xác nhận.</p></div><label>Trạng thái<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{refundStatuses.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label></div>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading ? <LoadingTable rows={6} columns={6} /> : error ? null : result.items.length === 0
      ? <EmptyState title="Không có yêu cầu hoàn tiền" description="Không có refund phù hợp với trạng thái đã chọn." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Booking</th><th>Provider gốc</th><th>Số tiền</th><th>Yêu cầu lúc</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((item) => <tr key={item.id}><td><strong>{shortId(item.bookingId)}</strong><small className="mono">{item.originalProviderOrderRef || item.requestId}</small></td><td>{item.provider}</td><td><strong>{formatMoney(item.amount)}</strong><small>{item.currency}</small></td><td>{formatDate(item.requestedAt)}</td><td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>{item.status === 'MANUAL_REQUIRED' ? 'Xác nhận hoàn tiền' : 'Xem chi tiết'}</button></td></tr>)}</tbody></table></div>}
    {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}
    {selected && <RefundDrawer key={selected.id} item={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </section>;
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
          <td><strong>{formatDate(item.paymentDeadline ?? undefined)}</strong><small>{!item.paymentDeadline ? 'Cần đối chiếu' : new Date(item.paymentDeadline) < new Date() ? 'Đã quá hạn' : 'Còn hiệu lực'}</small></td>
          <td><button className="row-action" onClick={() => setSelected(item)}>{item.canResolve === false ? 'Xem đối soát' : 'Xử lý'}</button></td></tr>)}</tbody></table></div>}
    {selected && <ReconciliationDrawer key={selected.intentId} item={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </section>;
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
