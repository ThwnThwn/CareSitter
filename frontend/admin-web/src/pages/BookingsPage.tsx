import { BookingDrawer } from '../features/bookings/BookingDrawer';
import { useMemo, useState } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, formatMoney, shortId } from '../components/Common';
import { Booking } from '../types';
import { usePagedResource } from '../useResource';

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
