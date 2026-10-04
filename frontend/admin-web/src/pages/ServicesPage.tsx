import { FormEvent, useState } from 'react';
import { Edit3, Plus, RefreshCw } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { api } from '../api';
import { Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, StatusChip, Tabs, formatDate, formatMoney } from '../components/Common';
import { CatalogService, ChecklistTemplate, PricingRule } from '../types';
import { currentPricingRule, fromDateTimeInput, toDateTimeInput } from '../operations';
import { useResource } from '../useResource';

export function ServicesPage() {
  const [tab, setTab] = useState('catalog');
  return <>
    <PageHeader title="Dịch vụ" description="Quản lý gói chăm sóc, bảng giá và checklist được snapshot vào booking." />
    <Tabs value={tab} onChange={setTab} items={[{ value: 'catalog', label: 'Danh mục & bảng giá' }, { value: 'checklists', label: 'Checklist dịch vụ' }]} />
    {tab === 'catalog' ? <CatalogManager /> : <ChecklistManager />}
  </>;
}

function CatalogManager() {
  const [selected, setSelected] = useState<CatalogService | 'new' | null>(null);
  const { data: services, loading, error, reload: load } = useResource<CatalogService[]>('/api/v1/admin/catalog/services', []);
  return <section className="data-panel tab-panel">
    <div className="panel-heading"><div><h2>Gói dịch vụ</h2><p>Chỉ gói đang hoạt động mới xuất hiện trong luồng đặt lịch.</p></div><div className="toolbar"><button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button><button className="primary" onClick={() => setSelected('new')}><Plus size={16} /> Thêm dịch vụ</button></div></div>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading ? <LoadingTable rows={5} columns={6} /> : error ? null : services.length === 0
      ? <EmptyState title="Chưa có gói dịch vụ" description="Tạo gói đầu tiên để bắt đầu cấu hình giá và checklist." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Gói dịch vụ</th><th>Mã</th><th>Thời lượng</th><th>Giá hiện hành</th><th>Phí nền tảng</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {services.map((service) => { const activePrice = currentPricingRule(service.pricingRules || []); return <tr key={service.id}><td><strong>{service.name}</strong><small>{service.description || 'Không có mô tả'}</small></td><td className="mono">{service.code}</td><td>{service.defaultDurationMinutes} phút</td><td>{activePrice ? formatMoney(activePrice.baseHourlyPrice) + '/giờ' : 'Chưa cấu hình'}</td><td>{activePrice ? `${activePrice.platformFeePercent}%` : '—'}</td><td><StatusChip value={service.isActive ? 'ACTIVE' : 'SUSPENDED'} /></td><td><button className="row-action" onClick={() => setSelected(service)}><Edit3 size={14} /> Chỉnh sửa</button></td></tr>; })}
      </tbody></table></div>}
    {selected && <ServiceDrawer service={selected === 'new' ? null : selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </section>;
}

function ServiceDrawer({ service, onClose, onChanged }: { service: CatalogService | null; onClose: () => void; onChanged: () => void }) {
  const { constraints, defaults } = useAdminMetadata();
  const createServiceForm = () => ({ code: '', name: '', description: '', ...defaults.service });
  const createPriceForm = () => ({ ...defaults.pricingRule, effectiveFrom: toDateTimeInput(new Date()), effectiveTo: '' });
  const [form, setForm] = useState(() => service ? { code: service.code, name: service.name, description: service.description || '', defaultDurationMinutes: service.defaultDurationMinutes, isActive: service.isActive } : createServiceForm());
  const [priceForm, setPriceForm] = useState(createPriceForm);
  const [editingPrice, setEditingPrice] = useState<PricingRule | null>(null);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  function editPrice(rule: PricingRule) {
    setEditingPrice(rule); setPriceForm({ name: rule.name, baseHourlyPrice: rule.baseHourlyPrice, nightMultiplier: rule.nightMultiplier, holidayMultiplier: rule.holidayMultiplier, platformFeePercent: rule.platformFeePercent, disputeWindowHours: rule.disputeWindowHours, effectiveFrom: toDateTimeInput(rule.effectiveFrom), effectiveTo: rule.effectiveTo ? toDateTimeInput(rule.effectiveTo) : '', isActive: rule.isActive });
  }
  async function saveService(event: FormEvent) {
    event.preventDefault(); if (busy) return; setBusy('service'); setError('');
    try { await api(service ? `/api/v1/admin/catalog/services/${service.id}` : '/api/v1/admin/catalog/services', { method: service ? 'PUT' : 'POST', body: JSON.stringify(form) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể lưu dịch vụ.'); }
    finally { setBusy(''); }
  }
  async function savePrice(event: FormEvent) {
    event.preventDefault(); if (!service || busy) return;
    setBusy('price'); setError('');
    const path = editingPrice ? `/api/v1/admin/catalog/services/${service.id}/pricing-rules/${editingPrice.id}` : `/api/v1/admin/catalog/services/${service.id}/pricing-rules`;
    try {
      if (priceForm.effectiveTo && Date.parse(fromDateTimeInput(priceForm.effectiveTo)) <= Date.parse(fromDateTimeInput(priceForm.effectiveFrom))) throw new Error('Hiệu lực đến phải sau thời điểm bắt đầu.');
      await api(path, { method: editingPrice ? 'PUT' : 'POST', body: JSON.stringify({ ...priceForm, effectiveFrom: fromDateTimeInput(priceForm.effectiveFrom), effectiveTo: priceForm.effectiveTo ? fromDateTimeInput(priceForm.effectiveTo) : null }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể lưu bảng giá.'); }
    finally { setBusy(''); }
  }
  return <Drawer title={service ? service.name : 'Thêm gói dịch vụ'} subtitle="Danh mục dịch vụ" busy={!!busy} onClose={onClose}>
    {error && <ErrorBanner message={error} />}
    <form className="form-stack" onSubmit={saveService}><div className="form-columns"><label>Mã dịch vụ<input required maxLength={100} value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} placeholder="GENKI_AN" /></label><label>Tên dịch vụ<input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label></div>
      <label>Mô tả<textarea rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
      <div className="form-columns"><label>Thời lượng mặc định (phút)<input type="number" min={constraints.serviceDurationMinutes.min} max={constraints.serviceDurationMinutes.max} value={form.defaultDurationMinutes} onChange={(e) => setForm({ ...form, defaultDurationMinutes: Number(e.target.value) })} /></label><label className="check-label"><input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} /> Đang hoạt động</label></div>
      <button className="primary align-start" disabled={!!busy}>{busy === 'service' ? 'Đang lưu…' : service ? 'Lưu dịch vụ' : 'Tạo dịch vụ'}</button>
    </form>
    {service && <><hr className="section-divider" /><h3 className="subheading">Bảng giá</h3>
      {service.pricingRules?.length ? <div className="stack-list compact-list">{service.pricingRules.map((rule) => <article key={rule.id}><div><strong>{rule.name}</strong><p>{formatMoney(rule.baseHourlyPrice)}/giờ · phí {rule.platformFeePercent}% · từ {formatDate(rule.effectiveFrom, false)}</p></div><div><StatusChip value={rule.isActive ? 'ACTIVE' : 'SUSPENDED'} /><button className="row-action" disabled={!!busy} onClick={() => editPrice(rule)}>Sửa</button></div></article>)}</div> : <EmptyState title="Chưa có bảng giá" description="Tạo bảng giá để hệ thống có thể báo giá booking." />}
      <form className="form-stack inset-form" onSubmit={savePrice}><h3>{editingPrice ? 'Chỉnh sửa bảng giá' : 'Thêm bảng giá'}</h3><label>Tên bảng giá<input required value={priceForm.name} onChange={(e) => setPriceForm({ ...priceForm, name: e.target.value })} /></label>
        <div className="form-columns"><label>Giá theo giờ<input type="number" min="0" value={priceForm.baseHourlyPrice} onChange={(e) => setPriceForm({ ...priceForm, baseHourlyPrice: Number(e.target.value) })} /></label><label>Phí nền tảng (%)<input type="number" min={constraints.platformFeePercent.min} max={constraints.platformFeePercent.max} step={constraints.platformFeePercent.step} value={priceForm.platformFeePercent} onChange={(e) => setPriceForm({ ...priceForm, platformFeePercent: Number(e.target.value) })} /></label></div>
        <div className="form-columns"><label>Hệ số ban đêm<input type="number" min={constraints.priceMultiplier.min} max={constraints.priceMultiplier.max} step={constraints.priceMultiplier.step} value={priceForm.nightMultiplier} onChange={(e) => setPriceForm({ ...priceForm, nightMultiplier: Number(e.target.value) })} /></label><label>Hệ số ngày lễ<input type="number" min={constraints.priceMultiplier.min} max={constraints.priceMultiplier.max} step={constraints.priceMultiplier.step} value={priceForm.holidayMultiplier} onChange={(e) => setPriceForm({ ...priceForm, holidayMultiplier: Number(e.target.value) })} /></label></div>
        <p>Thời gian theo múi giờ trình duyệt: {Intl.DateTimeFormat().resolvedOptions().timeZone}.</p><div className="form-columns"><label>Hiệu lực từ<input type="datetime-local" step="0.001" required value={priceForm.effectiveFrom} onChange={(e) => setPriceForm({ ...priceForm, effectiveFrom: e.target.value })} /></label><label>Hiệu lực đến<input type="datetime-local" step="0.001" value={priceForm.effectiveTo} onChange={(e) => setPriceForm({ ...priceForm, effectiveTo: e.target.value })} /></label></div>
        <div className="form-columns"><label>Thời hạn khiếu nại (giờ)<input type="number" min={constraints.disputeWindowHours.min} max={constraints.disputeWindowHours.max} value={priceForm.disputeWindowHours} onChange={(e) => setPriceForm({ ...priceForm, disputeWindowHours: Number(e.target.value) })} /></label><label className="check-label"><input type="checkbox" checked={priceForm.isActive} onChange={(e) => setPriceForm({ ...priceForm, isActive: e.target.checked })} /> Bảng giá hoạt động</label></div>
        <div className="button-row"><button className="primary" disabled={!!busy}>{busy === 'price' ? 'Đang lưu…' : editingPrice ? 'Lưu bảng giá' : 'Thêm bảng giá'}</button>{editingPrice && <button type="button" className="secondary" disabled={!!busy} onClick={() => { setEditingPrice(null); setPriceForm(createPriceForm()); }}>Hủy sửa</button>}</div>
      </form></>}
  </Drawer>;
}

function ChecklistManager() {
  const { data: services, loading, error, reload } = useResource<CatalogService[]>('/api/v1/admin/catalog/services', []);
  const [selectedId, setSelectedId] = useState('');
  const [policies, setPolicies] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState(false);
  const selectedService = services.find((service) => service.id === selectedId) || services[0];
  if (loading) return <LoadingTable rows={5} columns={4} />;
  if (error) return <ErrorBanner message={error} onRetry={() => void reload()} />;
  if (!selectedService) return <EmptyState title="Chưa có gói dịch vụ" description="Tạo gói ở tab Danh mục & bảng giá trước khi thêm checklist." />;
  return <div className="checklist-layout tab-panel">
    <aside className="service-rail"><h2>Gói dịch vụ</h2>{services.map((service) => <button key={service.id} disabled={busy}
      className={selectedService.id === service.id ? 'active' : ''} onClick={() => setSelectedId(service.id)}>
      <strong>{service.name}</strong><small>{service.code}</small>
    </button>)}</aside>
    <ChecklistEditor key={selectedService.id} service={{ ...selectedService, allowAdHocTasks: policies[selectedService.id] ?? selectedService.allowAdHocTasks }} onBusy={setBusy}
      onPolicyChanged={(value) => setPolicies((current) => ({ ...current, [selectedService.id]: value }))} />
  </div>;
}

function ChecklistEditor({ service, onBusy, onPolicyChanged }: { service: CatalogService; onBusy: (value: boolean) => void; onPolicyChanged: (value: boolean) => void }) {
  const { defaults } = useAdminMetadata();
  const { data: templates, loading, error: loadError, reload } = useResource<ChecklistTemplate[]>(`/api/v1/admin/services/${service.id}/checklist-templates`, []);
  const initialForm = () => ({ name: '', description: '', isRequired: defaults.checklist.isRequired,
    requiresPhoto: defaults.checklist.requiresPhoto, sortOrder: null as number | null });
  const nextSortOrder = Math.max(defaults.checklist.firstSortOrder, ...templates.map((template) => template.sortOrder + 1));
  const [editing, setEditing] = useState<ChecklistTemplate | null>(null);
  const [form, setForm] = useState(initialForm);
  const [allowAdHocTasks, setAllowAdHocTasks] = useState(service.allowAdHocTasks);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const disabled = !!busy || loading || !!loadError;
  function reset() { setEditing(null); setForm(initialForm()); }
  async function mutate(action: string, path: string, method: string, body?: unknown) {
    if (disabled) return;
    setBusy(action); onBusy(true); setError('');
    try {
      await api(path, { method, body: body === undefined ? undefined : JSON.stringify(body) });
      if (action === 'policy') { setAllowAdHocTasks(!allowAdHocTasks); onPolicyChanged(!allowAdHocTasks); }
      else { reset(); await reload(); }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể cập nhật checklist.'); }
    finally { setBusy(''); onBusy(false); }
  }
  function save(event: FormEvent) {
    event.preventDefault();
    void mutate('save', `/api/v1/admin/services/${service.id}/checklist-templates${editing ? '/' + editing.id : ''}`, editing ? 'PUT' : 'POST', { ...form, sortOrder: form.sortOrder ?? nextSortOrder });
  }
  return <section className="data-panel">
    <div className="panel-heading"><div><h2>Checklist của {service.name}</h2><p>Thay đổi chỉ áp dụng cho booking xác nhận sau thời điểm lưu.</p></div>
      <label className="switch-row"><span>Cho phép việc phát sinh</span><input type="checkbox" checked={allowAdHocTasks} disabled={disabled}
        onChange={() => void mutate('policy', `/api/v1/admin/services/${service.id}/checklist-policy`, 'PATCH', { allowAdHocTasks: !allowAdHocTasks })} /></label></div>
    {loadError && <ErrorBanner message={loadError} onRetry={() => void reload()} />}
    {error && <ErrorBanner message={error} />}
    {loading ? <LoadingTable rows={5} columns={4} /> : loadError ? null : templates.length === 0
      ? <EmptyState title="Chưa có công việc mẫu" description="Thêm công việc đầu tiên bằng biểu mẫu bên dưới." />
      : <div className="stack-list checklist-list">{templates.map((template) => <article key={template.id}>
        <span className="order-badge">{template.sortOrder}</span><div><strong>{template.name}</strong><p>{template.description}</p>
          <div className="tag-row"><span>{template.isRequired ? 'Bắt buộc' : 'Tùy chọn'}</span>{template.requiresPhoto && <span>Yêu cầu ảnh</span>}</div></div>
        <div><StatusChip value={template.isActive ? 'ACTIVE' : 'SUSPENDED'} />
          <button className="row-action" disabled={disabled} onClick={() => { setEditing(template); setForm({ name: template.name, description: template.description || '', isRequired: template.isRequired, requiresPhoto: template.requiresPhoto, sortOrder: template.sortOrder }); }}>Sửa</button>
          <button className="row-action" disabled={disabled} onClick={() => void mutate(template.id, `/api/v1/admin/services/${service.id}/checklist-templates/${template.id}/active`, 'PATCH', { isActive: !template.isActive })}>{template.isActive ? 'Tắt' : 'Bật'}</button>
          <button className="row-action danger-text" disabled={disabled} onClick={() => { if (window.confirm(`Xóa “${template.name}” khỏi checklist?`)) void mutate(template.id, `/api/v1/admin/services/${service.id}/checklist-templates/${template.id}`, 'DELETE'); }}>Xóa</button>
        </div></article>)}</div>}
    <form className="form-stack inset-form checklist-form" onSubmit={save}>
      <h3>{editing ? 'Chỉnh sửa công việc' : 'Thêm công việc'}</h3>
      <label>Tên công việc<input required minLength={3} maxLength={255} disabled={disabled} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
      <label>Mô tả<textarea rows={3} maxLength={1000} disabled={disabled} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
      <div className="form-columns"><label>Thứ tự<input type="number" min="0" max="1000" disabled={disabled} value={form.sortOrder ?? nextSortOrder} onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })} /></label>
        <div className="check-group"><label className="check-label"><input type="checkbox" disabled={disabled} checked={form.isRequired} onChange={(e) => setForm({ ...form, isRequired: e.target.checked })} /> Bắt buộc</label>
          <label className="check-label"><input type="checkbox" disabled={disabled} checked={form.requiresPhoto} onChange={(e) => setForm({ ...form, requiresPhoto: e.target.checked })} /> Yêu cầu ảnh</label></div></div>
      <div className="button-row"><button className="primary" disabled={disabled}>{busy === 'save' ? 'Đang lưu…' : editing ? 'Lưu thay đổi' : 'Thêm công việc'}</button>
        {editing && <button type="button" className="secondary" disabled={disabled} onClick={reset}>Hủy sửa</button>}</div>
    </form>
  </section>;
}
