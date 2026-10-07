import { FormEvent, useId, useState } from 'react';
import { Edit3, Plus, RefreshCw, Search, TicketPercent, Trash2 } from 'lucide-react';
import { api, ApiError, qs } from '../api';
import { Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, formatMoney } from '../components/Common';
import { createPromotionForm, promotionPayload, PromotionForm } from '../promotionForm';
import { AdminPromotion, CatalogService } from '../types';
import { usePagedResource, useResource } from '../useResource';

const endpoint = '/api/v1/admin/promotions';

export function PromotionsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('');
  const [selected, setSelected] = useState<string | null>(null);
  const [notice, setNotice] = useState('');
  const { data, loading, error, reload } = usePagedResource<AdminPromotion>(
    endpoint + qs({ search: query, status, page, pageSize: 20 }), page, setPage);
  function changed(message: string) { setSelected(null); setNotice(message); void reload(); }
  return <>
    <PageHeader title="Ưu đãi" description="Quản lý chiến dịch giảm giá, thời gian áp dụng và lượt sử dụng theo booking."
      actions={<button className="primary" onClick={() => { setNotice(''); setSelected('new'); }}><Plus size={16} /> Tạo chiến dịch</button>} />
    {notice && <div className="notice" role="status">{notice}</div>}
    <form className="filter-bar" onSubmit={(event) => { event.preventDefault(); setQuery(search.trim()); setPage(1); }}>
      <label className="search-field"><Search size={17} aria-hidden="true" /><input aria-label="Tìm mã hoặc tên chiến dịch"
        maxLength={160} placeholder="Mã hoặc tên chiến dịch" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
      <label>Trạng thái<select value={status} onChange={(event) => { setStatus(event.target.value); setPage(1); }}>
        <option value="">Tất cả trạng thái</option><option value="ACTIVE">Đang hiệu lực</option>
        <option value="SCHEDULED">Sắp diễn ra</option><option value="EXPIRED">Đã hết hạn</option><option value="INACTIVE">Đã tắt</option>
      </select></label>
      <button className="secondary" type="submit">Tìm kiếm</button>
      <button className="secondary" type="button" disabled={loading} onClick={() => void reload()}><RefreshCw size={16} /> Làm mới</button>
    </form>
    {error && <ErrorBanner message={error} onRetry={() => void reload()} />}
    <section className="data-panel">
      <div className="panel-heading"><div><h2>Chiến dịch ưu đãi</h2><p>Lượt đang giữ còn hạn được tính vào giới hạn sử dụng.</p></div><span className="data-timestamp">{loading ? 'Đang tải…' : `${data.total} chiến dịch`}</span></div>
      {loading ? <LoadingTable rows={5} columns={6} /> : error ? null : data.items.length === 0
        ? <EmptyState title={query || status ? 'Không tìm thấy chiến dịch' : 'Chưa có chiến dịch ưu đãi'}
          description={query || status ? 'Đổi từ khóa hoặc chọn tất cả trạng thái để tìm lại.' : 'Tạo chiến dịch đầu tiên, kiểm tra điều kiện rồi bật khi sẵn sàng.'} />
        : <div className="table-wrap"><table className="data-table promotion-table"><thead><tr><th>Chiến dịch</th><th>Mức giảm</th><th>Thời gian</th><th>Lượt sử dụng</th><th>Trạng thái</th><th>Thao tác</th></tr></thead>
          <tbody>{data.items.map((promotion) => <tr key={promotion.id}>
            <td><strong><button className="promotion-title" aria-label={`Mở chiến dịch ${promotion.code}`} onClick={() => { setNotice(''); setSelected(promotion.id); }}>{promotion.title}</button></strong><small className="mono">{promotion.code}{promotion.isFeatured ? ' · Nổi bật' : ''}</small><small>{promotion.summary}</small></td>
            <td>{promotion.discountType === 'percentage' ? `${promotion.discountValue}%` : formatMoney(promotion.discountValue)}
              {promotion.maxDiscountAmount && <small>Tối đa {formatMoney(promotion.maxDiscountAmount)}</small>}<small>Đơn từ {formatMoney(promotion.minOrderAmount)}</small></td>
            <td>{formatDate(promotion.startsAt)}<small>đến {formatDate(promotion.endsAt)}</small></td>
            <td><strong>{promotion.redeemedCount} đã dùng · {promotion.reservedCount} đang giữ</strong><small>Tổng giới hạn: {promotion.totalUsageLimit ?? 'Không giới hạn'} · {promotion.perCustomerUsageLimit} lượt/khách</small></td>
            <td><StatusChip value={promotion.status} /></td>
            <td><button className="row-action" aria-label={`Xem và sửa ${promotion.code}`} onClick={() => { setNotice(''); setSelected(promotion.id); }}><Edit3 size={14} /> Chi tiết</button></td>
          </tr>)}</tbody></table></div>}
      {!loading && !error && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={setPage} />}
    </section>
    {selected && <PromotionDrawer id={selected === 'new' ? null : selected} onClose={() => setSelected(null)} onChanged={changed} />}
  </>;
}

function PromotionDrawer({ id, onClose, onChanged }: { id: string | null; onClose: () => void; onChanged: (message: string) => void }) {
  const { data, loading, error, reload } = useResource<AdminPromotion | null>(id ? `${endpoint}/${id}` : null, null);
  if (loading || error || (id && !data)) return <Drawer title="Chi tiết chiến dịch" onClose={onClose}>
    {error ? <ErrorBanner message={error} onRetry={() => void reload()} /> : <LoadingTable rows={5} columns={2} />}
  </Drawer>;
  return <PromotionEditor key={data?.updatedAt ?? 'new'} promotion={data} onClose={onClose} onChanged={onChanged} onReload={() => void reload()} />;
}

function PromotionEditor({ promotion, onClose, onChanged, onReload }: {
  promotion: AdminPromotion | null; onClose: () => void; onChanged: (message: string) => void; onReload: () => void;
}) {
  const formId = useId();
  const [form, setForm] = useState(() => createPromotionForm(promotion));
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [stale, setStale] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const locked = !!promotion?.hasHistory;
  const { data: services, loading: servicesLoading, error: servicesError, reload: reloadServices } = useResource<CatalogService[]>('/api/v1/admin/catalog/services', []);
  const set = <K extends keyof PromotionForm>(key: K, value: PromotionForm[K]) => setForm((previous) => ({ ...previous, [key]: value }));
  function failed(cause: unknown) {
    setError(cause instanceof Error ? cause.message : 'Không thể lưu chiến dịch.');
    setStale(!!promotion && cause instanceof ApiError && cause.status === 409 &&
      ['promotion.stale', 'promotion.has_history', 'promotion.rules_locked'].includes(cause.code || ''));
  }
  async function save(event: FormEvent) {
    event.preventDefault(); if (busy) return; setBusy('save'); setError(''); setStale(false);
    try {
      const payload = promotionPayload(form, promotion?.updatedAt);
      if (locked && promotion) payload.startsAt = promotion.startsAt;
      await api(promotion ? `${endpoint}/${promotion.id}` : endpoint, { method: promotion ? 'PUT' : 'POST', body: JSON.stringify(payload) });
      onChanged(promotion ? 'Đã lưu thay đổi chiến dịch.' : 'Đã tạo chiến dịch ưu đãi.');
    } catch (cause) { failed(cause); } finally { setBusy(''); }
  }
  async function changeActive() {
    if (!promotion || busy) return; setBusy('active'); setError(''); setStale(false);
    try {
      await api(`${endpoint}/${promotion.id}/active`, { method: 'PATCH', body: JSON.stringify({ isActive: !promotion.isActive, expectedUpdatedAt: promotion.updatedAt }) });
      onChanged(promotion.isActive ? 'Đã tắt chiến dịch. Lượt giữ hiện có vẫn được xử lý theo booking.' : 'Đã bật chiến dịch. Ưu đãi áp dụng trong thời gian đã cấu hình.');
    } catch (cause) { failed(cause); } finally { setBusy(''); }
  }
  async function remove() {
    if (!promotion || !promotion.canDelete || busy) return; setBusy('delete'); setError(''); setStale(false);
    try {
      await api(`${endpoint}/${promotion.id}`, { method: 'DELETE', body: JSON.stringify({ expectedUpdatedAt: promotion.updatedAt }) });
      onChanged(`Đã xóa chiến dịch ${promotion.code}.`);
    } catch (cause) { failed(cause); } finally { setBusy(''); }
  }
  return <Drawer title={promotion ? promotion.title : 'Tạo chiến dịch'} subtitle="Quản lý ưu đãi" busy={!!busy} onClose={onClose}
    footer={<><button className="secondary" disabled={!!busy} onClick={onClose}>Đóng</button>
      <button className="primary" form={formId} type="submit" disabled={!!busy || stale}>{busy === 'save' ? 'Đang lưu…' : promotion ? 'Lưu thay đổi' : 'Tạo chiến dịch'}</button></>}>
    {promotion && <div className="drawer-status"><StatusChip value={promotion.status} /><span>{promotion.redeemedCount} đã dùng · {promotion.reservedCount} đang giữ · {promotion.releasedCount} đã giải phóng</span></div>}
    {error && <ErrorBanner message={error} />}
    {stale && <div className="warning-box"><p>Tải bản mới nhất để kiểm tra lại dữ liệu. Bản nháp đang nhập sẽ được thay thế.</p><button className="secondary" disabled={!!busy} onClick={onReload}>Tải lại chiến dịch</button></div>}
    {locked && <div className="notice">Chiến dịch đã có lịch sử. Mã, mức giảm, thời điểm bắt đầu và điều kiện áp dụng được giữ nguyên. Bạn vẫn có thể sửa nội dung, thời điểm kết thúc, giới hạn lượt hoặc tắt chiến dịch.</div>}
    <form id={formId} className="form-stack promotion-form" onSubmit={save}>
      <fieldset disabled={!!busy}><legend>Nội dung hiển thị</legend>
        <div className="form-columns"><label>Mã ưu đãi<input required pattern="[A-Za-z0-9_-]+" maxLength={50} disabled={locked} value={form.code} onChange={(e) => set('code', e.target.value.toUpperCase())} /></label>
          <label>Nhãn ưu đãi<input required maxLength={50} value={form.badgeText} onChange={(e) => set('badgeText', e.target.value)} /></label></div>
        <label>Tên chiến dịch<input required maxLength={160} value={form.title} onChange={(e) => set('title', e.target.value)} /></label>
        <label>Tóm tắt<textarea required rows={2} maxLength={300} value={form.summary} onChange={(e) => set('summary', e.target.value)} /></label>
        <label>Mô tả chi tiết<textarea rows={3} maxLength={10000} value={form.description} onChange={(e) => set('description', e.target.value)} /></label>
        <label>Điều khoản (mỗi dòng một điều kiện)<textarea rows={3} value={form.terms} onChange={(e) => set('terms', e.target.value)} /><small>Tối đa 20 dòng, mỗi dòng 500 ký tự.</small></label>
      </fieldset>
      <fieldset disabled={!!busy}><legend>Mức giảm và thời gian</legend>
        <div className="form-columns"><label>Loại giảm<select disabled={locked} value={form.discountType} onChange={(e) => set('discountType', e.target.value as PromotionForm['discountType'])}><option value="percentage">Theo phần trăm</option><option value="fixed_amount">Số tiền cố định</option></select></label>
          <NumberField label={form.discountType === 'percentage' ? 'Mức giảm (%)' : 'Mức giảm (VND)'} value={form.discountValue} min={1} max={form.discountType === 'percentage' ? 100 : Number.MAX_SAFE_INTEGER} disabled={locked} onChange={(value) => set('discountValue', value)} /></div>
        <div className="form-columns"><NumberField label="Giảm tối đa (VND)" value={form.maxDiscountAmount} min={1} optional disabled={locked} onChange={(value) => set('maxDiscountAmount', value)} />
          <NumberField label="Đơn tối thiểu (VND)" value={form.minOrderAmount} disabled={locked} onChange={(value) => set('minOrderAmount', value)} /></div>
        <div className="form-columns"><label>Bắt đầu<input type="datetime-local" step="any" required disabled={locked} value={form.startsAt} onChange={(e) => set('startsAt', e.target.value)} /></label>
          <label>Kết thúc<input type="datetime-local" step="any" required value={form.endsAt} onChange={(e) => set('endsAt', e.target.value)} /></label></div>
        <p className="form-help">Thời gian theo múi giờ thiết bị. Ưu đãi chưa hỗ trợ đơn có số tiền thanh toán bằng 0.</p>
      </fieldset>
      <fieldset disabled={!!busy}><legend>Điều kiện và giới hạn lượt</legend>
        <label className="check-label"><input type="checkbox" disabled={locked} checked={form.firstPaidBookingOnly} onChange={(e) => set('firstPaidBookingOnly', e.target.checked)} /> Chỉ cho booking thanh toán đầu tiên</label>
        <div className="form-columns"><NumberField label="Tổng lượt sử dụng" value={form.totalUsageLimit} min={1} max={2147483647} optional onChange={(value) => set('totalUsageLimit', value)} />
          <NumberField label="Lượt mỗi khách" value={form.perCustomerUsageLimit} min={1} max={2147483647} onChange={(value) => set('perCustomerUsageLimit', value)} /></div>
        <p className="form-help">Giới hạn bao gồm lượt đã dùng và lượt đang giữ còn hạn. Để trống tổng lượt nếu không giới hạn.</p>
        <label className="check-label"><input type="checkbox" disabled={locked || !!servicesError || servicesLoading} checked={form.eligibleServiceIds.length === 0}
          onChange={(e) => set('eligibleServiceIds', e.target.checked ? [] : services.filter((service) => service.isActive).map((service) => service.id))} /> Áp dụng tất cả dịch vụ</label>
        {servicesError ? <ErrorBanner message={servicesError} onRetry={() => void reloadServices()} /> : servicesLoading ? <p className="form-help" role="status">Đang tải danh mục dịch vụ…</p>
          : <div className="promotion-scopes" role="group" aria-label="Dịch vụ áp dụng">{services.map((service) => <label key={service.id} className="check-label"><input type="checkbox"
            disabled={locked || (!service.isActive && !form.eligibleServiceIds.includes(service.id))} checked={form.eligibleServiceIds.includes(service.id)}
            onChange={(e) => set('eligibleServiceIds', e.target.checked ? [...form.eligibleServiceIds, service.id] : form.eligibleServiceIds.filter((id) => id !== service.id))} />{service.name}{!service.isActive ? ' (Đã tắt)' : ''}</label>)}
            {services.length === 0 && <p className="form-help">Chưa có dịch vụ để giới hạn phạm vi.</p>}</div>}
        <p className="form-help">Không chọn dịch vụ cụ thể nghĩa là áp dụng tất cả dịch vụ.</p>
      </fieldset>
      <fieldset disabled={!!busy}><legend>Hiển thị và trạng thái</legend>
        <NumberField label="Độ ưu tiên" value={form.priority} max={2147483647} onChange={(value) => set('priority', value)} />
        <label className="check-label"><input type="checkbox" checked={form.isFeatured} onChange={(e) => set('isFeatured', e.target.checked)} /> Ưu đãi nổi bật</label>
        <label className="check-label"><input type="checkbox" checked={form.isActive} onChange={(e) => set('isActive', e.target.checked)} /> Bật chiến dịch trong thời gian đã cấu hình</label>
      </fieldset>
    </form>
    <section className="promotion-preview" aria-label="Xem trước nội dung ưu đãi"><h3><TicketPercent size={17} /> Khách hàng sẽ thấy</h3>
      <span className="status-chip success">{form.badgeText || 'Nhãn ưu đãi'}</span><h4>{form.title || 'Tên chiến dịch'}</h4><p>{form.summary || 'Tóm tắt nội dung ưu đãi'}</p><span className="mono">{form.code || 'MÃ ƯU ĐÃI'}</span>
      {form.description && <p className="promotion-description">{form.description}</p>}
      {form.terms.trim() && <ul>{form.terms.split('\n').filter((term) => term.trim()).map((term, index) => <li key={index}>{term}</li>)}</ul>}
    </section>
    {promotion && <section className="promotion-actions"><h3>Vận hành chiến dịch</h3><p className="form-help">Bật/tắt dùng cấu hình đã lưu. Lượt giữ hiện có vẫn được redeem hoặc release theo booking.</p>
      <button className="secondary" disabled={!!busy || stale} onClick={() => void changeActive()}>{busy === 'active' ? 'Đang cập nhật…' : promotion.isActive ? 'Tắt chiến dịch' : 'Bật chiến dịch'}</button>
      {promotion.canDelete ? confirmDelete ? <div className="warning-box"><p>Xóa vĩnh viễn chiến dịch <strong>{promotion.code}</strong>? Chiến dịch chưa có lịch sử sử dụng.</p><div className="button-row">
        <button className="danger" disabled={!!busy || stale} onClick={() => void remove()}>{busy === 'delete' ? 'Đang xóa…' : `Xác nhận xóa ${promotion.code}`}</button>
        <button className="secondary" disabled={!!busy} onClick={() => setConfirmDelete(false)}>Hủy xóa</button></div></div>
        : <button className="danger" disabled={!!busy || stale} onClick={() => setConfirmDelete(true)}><Trash2 size={15} /> Xóa chiến dịch</button>
        : <p className="form-help">Không thể xóa vì đã có lịch sử giữ hoặc sử dụng. Có thể tắt để ngừng nhận lượt mới.</p>}
    </section>}
  </Drawer>;
}

function NumberField({ label, value, onChange, min = 0, max = Number.MAX_SAFE_INTEGER, disabled = false, optional = false }: {
  label: string; value: string; onChange: (value: string) => void; min?: number; max?: number; disabled?: boolean; optional?: boolean;
}) {
  const id = useId();
  return <div className="promotion-number-field"><label htmlFor={id}>{label}<input id={id} type="number" step="1" min={min} max={max} required={!optional}
    aria-describedby={optional ? `${id}-help` : undefined} disabled={disabled} value={value} onChange={(e) => onChange(e.target.value)} /></label>
    {optional && <small id={`${id}-help`}>Để trống nếu không giới hạn.</small>}</div>;
}
