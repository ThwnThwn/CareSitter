import { DataRow, DataTable } from '../components/DataTable';
import { BookingDrawer } from '../features/bookings/BookingDrawer';
import { useMemo, useState } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, formatMoney, shortId } from '../components/Common';
import { Booking } from '../types';
import { usePagedResource, useResource } from '../useResource';
import { updateBookingLocation, useHashParam } from '../hashLocation';
import { bookingReference } from '../utils/format';
import type { ShowToast } from '../useToast';

export function BookingsPage({ showToast = () => undefined }: { showToast?: ShowToast }) {
  const { filters } = useAdminMetadata();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.bookings.defaultValue);
  const [search, setSearch] = useState('');
  const linkedId = useHashParam('id');
  const { data: result, loading, error, hasLoaded, reload: load } = usePagedResource<Booking>(`/api/v1/bookings${qs({ status, page, pageSize: 20 })}`, page, setPage);

  const listed = result.items.find(item => item.id === linkedId);
  const linked = useResource<Booking | null>(
    linkedId && !listed ? `/api/v1/bookings/${encodeURIComponent(linkedId)}` : null, null);
  const selected = listed ?? linked.data;

  function openBooking(item: Booking) { if (linkedId !== item.id) updateBookingLocation(item.id); }
  function closeBooking() { updateBookingLocation(null); }

  const term = search.trim().toLowerCase();
  const items = useMemo(() => {
    if (!term) return result.items;
    return result.items.filter((item) => [
      item.id, bookingReference(item.id), item.beneficiaryName, item.caregiverName, item.serviceName,
    ].some((value) => value?.toLowerCase().includes(term)));
  }, [result.items, term]);

  return <>
    <PageHeader title="Lịch chăm sóc" description="Theo dõi ca đã đặt và duyệt các ca chờ hoàn tất."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar">
      <label className="search-field"><span className="sr-only">Tìm booking trong trang này</span><Search size={17} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Tìm trong trang này: mã, tên…" /></label>
      <label><span className="sr-only">Lọc trạng thái</span><select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{filters.bookings.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
    </section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {linked.error && <ErrorBanner message={`Không mở được booking từ liên kết: ${linked.error}`} onRetry={() => void linked.reload()} />}
    <section className="data-panel">
      {loading && !hasLoaded ? <LoadingTable rows={8} columns={6} /> : error && !hasLoaded ? null : items.length === 0
        ? <EmptyState title="Không tìm thấy booking" description="Từ khóa chỉ lọc trang hiện tại. Thử đổi trang hoặc trạng thái." />
        : <div className="table-wrap"><DataTable columns={['Booking', 'Dịch vụ', 'Người được chăm sóc', 'Caregiver', 'Lịch thực hiện', 'Trạng thái', '']} className="booking-table">{items.map((item) => <DataRow key={item.id}>
            <td><button className="entity-link" title={item.id} onClick={() => openBooking(item)}>{bookingReference(item.id)}</button><small>{formatMoney(item.escrowAmount)}</small></td>
            <td><strong>{item.serviceName || 'Dịch vụ chăm sóc'}</strong><small>{item.addressText || 'Chưa có địa chỉ'}</small></td>
            <td>{item.beneficiaryName || shortId(item.beneficiaryId)}</td><td>{item.caregiverName || 'Chưa phân công'}</td>
            <td><strong>{formatDate(item.scheduledStart)}</strong><small>đến {formatDate(item.scheduledEnd)}</small></td>
            <td><StatusChip value={item.status} /></td><td><button className="row-action" onClick={() => openBooking(item)}>Xem chi tiết</button></td>
          </DataRow>)}</DataTable></div>}
      {hasLoaded && result.total > 0 && <Pagination page={result.page} pageSize={result.pageSize}
        total={result.total} onChange={setPage} showSinglePage
        summary={term ? `Tìm thấy ${items.length} lịch trên trang này` : undefined} />}
    </section>
    {selected && <BookingDrawer key={selected.id} booking={selected} onClose={closeBooking} onChanged={(msg) => { closeBooking(); void load(); showToast(msg); }} />}
  </>;
}
