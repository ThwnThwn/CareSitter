import { useMemo, useState } from 'react';
import { CheckCircle2, RefreshCw, Search } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, Tabs, formatDate, formatMoney, shortId } from '../components/Common';
import { Booking, CareTask, TimelineEvent } from '../types';
import { usePagedResource, useResource } from '../useResource';

export function BookingsPage() {
  const { filters } = useAdminMetadata();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.bookings.defaultValue);
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Booking | null>(null);
  const { data: result, loading, error, reload: load } = usePagedResource<Booking>(`/api/v1/bookings${qs({ status, page, pageSize: 20 })}`, page, setPage);

  const items = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return result.items;
    return result.items.filter((item) => [item.id, item.beneficiaryName, item.caregiverName, item.serviceName]
      .some((value) => value?.toLowerCase().includes(term)));
  }, [result.items, search]);

  return <>
    <PageHeader title="Booking" description="Theo dõi toàn bộ vòng đời ca chăm sóc và duyệt các ca chờ hoàn tất."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar">
      <label className="search-field"><span className="sr-only">Tìm booking trong trang này</span><Search size={17} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Tìm trong trang này: mã, tên…" /></label>
      <label><span className="sr-only">Lọc trạng thái</span><select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{filters.bookings.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
    </section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">
      {loading ? <LoadingTable rows={8} columns={6} /> : error ? null : items.length === 0
        ? <EmptyState title="Không tìm thấy booking" description="Từ khóa chỉ lọc trang hiện tại. Thử đổi trang hoặc trạng thái." />
        : <div className="table-wrap"><table className="data-table booking-table"><thead><tr><th>Booking</th><th>Dịch vụ</th><th>Người được chăm sóc</th><th>Caregiver</th><th>Lịch thực hiện</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>{items.map((item) => <tr key={item.id}>
            <td><button className="entity-link" onClick={() => setSelected(item)}>{shortId(item.id)}</button><small>{formatMoney(item.escrowAmount)}</small></td>
            <td><strong>{item.serviceName || 'Dịch vụ chăm sóc'}</strong><small>{item.addressText || 'Chưa có địa chỉ'}</small></td>
            <td>{item.beneficiaryName || shortId(item.beneficiaryId)}</td><td>{item.caregiverName || 'Chưa phân công'}</td>
            <td><strong>{formatDate(item.scheduledStart)}</strong><small>đến {formatDate(item.scheduledEnd)}</small></td>
            <td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => setSelected(item)}>Xem chi tiết</button></td>
          </tr>)}</tbody></table></div>}
      {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}
    </section>
    {selected && <BookingDrawer key={selected.id} booking={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function BookingDrawer({ booking, onClose, onChanged }: { booking: Booking; onClose: () => void; onChanged: () => void }) {
  const detailResource = useResource<Booking>(`/api/v1/bookings/${booking.id}`, booking);
  const taskResource = useResource<CareTask[]>(`/api/v1/bookings/${booking.id}/tasks`, []);
  const timelineResource = useResource<TimelineEvent[]>(`/api/v1/bookings/${booking.id}/timeline`, []);
  const detail = detailResource.data;
  const tasks = taskResource.data;
  const timeline = timelineResource.data;
  const [tab, setTab] = useState('summary');
  const loading = detailResource.loading || taskResource.loading || timelineResource.loading;
  const loadError = detailResource.error || taskResource.error || timelineResource.error;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  function reloadDetails() { void detailResource.reload(); void taskResource.reload(); void timelineResource.reload(); }

  async function complete() {
    if (busy || loading || loadError || detail.status !== 'checkout_pending_review') return;
    if (!window.confirm('Xác nhận hoàn tất ca này? Tiền giữ chờ chỉ được giải ngân sau thời hạn khiếu nại theo cấu hình của booking.')) return;
    setBusy(true); setError('');
    try { await api(`/api/v1/bookings/${booking.id}/complete`, { method: 'POST' }); onChanged(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể hoàn tất booking.'); }
    finally { setBusy(false); }
  }

  return <Drawer title={shortId(detail.id)} subtitle="Chi tiết booking" busy={!!busy} onClose={onClose}
    footer={detail.status === 'checkout_pending_review' && <button className="primary" disabled={busy || loading || !!loadError} onClick={() => void complete()}><CheckCircle2 size={17} /> {busy ? 'Đang hoàn tất…' : 'Xác nhận hoàn tất ca'}</button>}>
    <div className="drawer-status"><StatusChip value={detail.status} /><span>Cập nhật {formatDate(detail.updatedAt)}</span></div>
    {error && <ErrorBanner message={error} />}
    {loadError && <ErrorBanner message={loadError} onRetry={reloadDetails} />}
    <Tabs value={tab} onChange={setTab} items={[{ value: 'summary', label: 'Thông tin' }, { value: 'tasks', label: 'Checklist', count: tasks.length }, { value: 'timeline', label: 'Timeline', count: timeline.length }]} />
    {loading ? <LoadingTable rows={5} columns={2} /> : loadError ? null : tab === 'summary' ? <>
      <DetailList items={[
        { label: 'Dịch vụ', value: detail.serviceName }, { label: 'Người được chăm sóc', value: detail.beneficiaryName },
        { label: 'Caregiver', value: detail.caregiverName || 'Chưa phân công' }, { label: 'Bắt đầu', value: formatDate(detail.scheduledStart) },
        { label: 'Kết thúc', value: formatDate(detail.scheduledEnd) }, { label: 'Địa chỉ', value: detail.addressText },
        { label: 'Bắt đầu thực tế', value: formatDate(detail.actualStart) }, { label: 'Kết thúc thực tế', value: formatDate(detail.actualEnd) },
        { label: 'Escrow', value: formatMoney(detail.escrowAmount) }, { label: 'Thu nhập caregiver', value: formatMoney(detail.caregiverEarningAmount) },
        { label: 'Phí nền tảng', value: formatMoney(detail.platformFeeAmount) }, { label: 'Ghi chú', value: detail.note },
        { label: 'Lý do hủy', value: detail.cancelReason },
      ]} />
    </> : tab === 'tasks' ? (tasks.length === 0 ? <EmptyState title="Chưa có checklist" description="Booking này không có công việc được snapshot." />
      : <div className="stack-list">{tasks.map((task) => <article key={task.id}><div><strong>{task.name}</strong><p>{task.description}</p>
        <div className="tag-row"><span>{task.isRequired ? 'Bắt buộc' : 'Tùy chọn'}</span>{task.requiresPhoto && <span>Yêu cầu ảnh</span>}</div>
        {task.completedAt && <p>Hoàn tất: {formatDate(task.completedAt)}</p>}{task.skipReason && <p>Lý do bỏ qua: {task.skipReason}</p>}
        <div className="attachment-list">{task.photoUrls?.map((url, index) => <a key={url} href={url} target="_blank" rel="noreferrer">Ảnh minh chứng {index + 1}</a>)}</div>
      </div><StatusChip value={task.status} /></article>)}</div>)
      : (timeline.length === 0 ? <EmptyState title="Chưa có sự kiện" description="Timeline sẽ được cập nhật khi ca bắt đầu có hoạt động." />
        : <ol className="timeline-list">{timeline.map((event) => <li key={event.id}><span /><div><strong>{event.title || event.eventType}</strong><p>{event.note || event.source}</p><small>{formatDate(event.recordedAt)}</small></div></li>)}</ol>)}
  </Drawer>;
}
