import { useCallback, useEffect, useState } from 'react';
import { ExternalLink, RefreshCw, UserCheck } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { Paged, SupportTicket } from '../types';

export function SupportPage() {
  const { filters } = useAdminMetadata();
  const [result, setResult] = useState<Paged<SupportTicket>>({ items: [], total: 0, page: 1, pageSize: 20 });
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.tickets.defaultValue);
  const [type, setType] = useState(filters.ticketTypes.defaultValue);
  const [priority, setPriority] = useState(filters.ticketPriorities.defaultValue);
  const [selected, setSelected] = useState<SupportTicket | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { setResult(await api<Paged<SupportTicket>>(`/api/v1/support/tickets${qs({ status, type, priority, page, pageSize: 20 })}`)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Không tải được ticket hỗ trợ.'); }
    finally { setLoading(false); }
  }, [page, priority, status, type]);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { setPage(1); }, [status, type, priority]);

  return <>
    <PageHeader title="Hỗ trợ" description="Tiếp nhận, phân công và theo dõi yêu cầu hỗ trợ của khách hàng và caregiver."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar filter-grid">
      <label>Trạng thái<select value={status} onChange={(e) => setStatus(e.target.value)}>{filters.tickets.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
      <label>Loại ticket<select value={type} onChange={(e) => setType(e.target.value)}>{filters.ticketTypes.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
      <label>Độ ưu tiên<select value={priority} onChange={(e) => setPriority(e.target.value)}>{filters.ticketPriorities.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
    </section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">
      {loading ? <LoadingTable rows={7} columns={6} /> : result.items.length === 0
        ? <EmptyState title="Không có ticket phù hợp" description="Hãy đổi bộ lọc hoặc kiểm tra lại sau." />
        : <div className="table-wrap"><table className="data-table"><thead><tr><th>Ticket</th><th>Loại</th><th>Ưu tiên</th><th>Người gửi</th><th>Cập nhật</th><th>Trạng thái</th><th /></tr></thead><tbody>
          {result.items.map((item) => <tr key={item.id}><td><strong>{item.title}</strong><small>{shortId(item.id)}</small></td><td>{optionLabel(filters.ticketTypes.options, item.type)}</td><td><StatusChip value={item.priority} /></td><td>{shortId(item.userId)}</td><td>{formatDate(item.updatedAt)}</td><td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Mở ticket</button></td></tr>)}</tbody></table></div>}
      <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />
    </section>
    {selected && <SupportDrawer ticket={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function SupportDrawer({ ticket, onClose, onChanged }: { ticket: SupportTicket; onClose: () => void; onChanged: () => void }) {
  const { filters, statusDefinitions, transitions } = useAdminMetadata();
  const [status, setStatus] = useState(ticket.status);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  async function assign() {
    setBusy('assign'); setError('');
    try { await api(`/api/v1/support/tickets/${ticket.id}/assign`, { method: 'PUT' }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể nhận xử lý ticket.'); }
    finally { setBusy(''); }
  }
  async function updateStatus() {
    if (status === ticket.status) return;
    setBusy('status'); setError('');
    try { await api(`/api/v1/support/tickets/${ticket.id}/status`, { method: 'PUT', body: JSON.stringify({ status }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể cập nhật trạng thái ticket.'); }
    finally { setBusy(''); }
  }
  const nextStatuses = [ticket.status, ...(transitions.support[ticket.status] || [])];
  return <Drawer title={ticket.title} subtitle={`${optionLabel(filters.ticketTypes.options, ticket.type)} · ${shortId(ticket.id)}`} onClose={onClose}
    footer={<><button className="secondary" disabled={!!busy || !!ticket.assignedAdminId} onClick={() => void assign()}><UserCheck size={17} /> {ticket.assignedAdminId ? 'Đã phân công' : busy === 'assign' ? 'Đang nhận…' : 'Nhận xử lý'}</button><button className="primary" disabled={!!busy || status === ticket.status} onClick={() => void updateStatus()}>{busy === 'status' ? 'Đang lưu…' : 'Lưu trạng thái'}</button></>}>
    <div className="drawer-status"><StatusChip value={ticket.status} /><StatusChip value={ticket.priority} /><span>{formatDate(ticket.createdAt)}</span></div>
    {error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Người gửi', value: ticket.userId }, { label: 'Booking', value: ticket.bookingId }, { label: 'Admin phụ trách', value: ticket.assignedAdminId || 'Chưa phân công' }]} />
    <section className="prose-block"><h3>Nội dung yêu cầu</h3><p>{ticket.description}</p></section>
    {ticket.attachmentUrls?.length > 0 && <section><h3 className="subheading">Tệp đính kèm</h3><div className="attachment-list">{ticket.attachmentUrls.map((url, index) => <a href={url} target="_blank" rel="noreferrer" key={url}>Tệp đính kèm {index + 1}<ExternalLink size={14} /></a>)}</div></section>}
    <label>Trạng thái tiếp theo<select value={status} onChange={(e) => setStatus(e.target.value)}>{nextStatuses.map((value) => <option value={value} key={value}>{statusDefinitions[value]?.label || value}</option>)}</select></label>
  </Drawer>;
}
