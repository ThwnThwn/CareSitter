import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5033').replace(/\/$/, '');
const TOKEN_KEY = 'caresitter_admin_access_token';

type ReviewItem = {
  intentId: string;
  bookingId: string;
  customerId: string;
  amount: number;
  currency: string;
  providerOrderRef?: string;
  providerTransactionId?: string;
  reconciliationAttempts: number;
  reconciliationStartedAt?: string;
  lastReconciliationAt?: string;
  lastReconciliationError?: string;
  manualReviewReason?: string;
  bookingStatus: string;
  paymentDeadline: string;
};

type LoginResponse = {
  accessToken: string;
  roles: string[];
  displayName?: string;
};

type Service = { id: string; code: string; name: string; description?: string; allowAdHocTasks?: boolean };
type ChecklistTemplate = {
  id: string;
  serviceTypeId: string;
  name: string;
  description?: string;
  isRequired: boolean;
  requiresPhoto: boolean;
  sortOrder: number;
  isActive: boolean;
};

function getError(payload: unknown, fallback: string) {
  if (payload && typeof payload === 'object') {
    const value = payload as Record<string, unknown>;
    return String(value.detail || value.error || value.message || fallback);
  }
  return fallback;
}

function Login({ onLoggedIn }: { onLoggedIn: (name?: string) => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const response = await fetch(`${API_BASE}/api/v1/auth/login/password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, requiredRole: 'ADMIN' }),
      });
      const payload = await response.json().catch(() => null) as LoginResponse | null;
      if (!response.ok || !payload?.accessToken) {
        throw new Error(getError(payload, 'Không thể đăng nhập.'));
      }
      if (!payload.roles?.some((role) => role.toUpperCase() === 'ADMIN')) {
        throw new Error('Tài khoản không có quyền quản trị.');
      }
      sessionStorage.setItem(TOKEN_KEY, payload.accessToken);
      onLoggedIn(payload.displayName);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Không thể đăng nhập.');
    } finally {
      setBusy(false);
    }
  }

  return <main className="login-page">
    <section className="login-story">
      <div className="brand"><span className="brand-mark">C</span><span>CareSitter</span></div>
      <div className="story-copy">
        <p className="eyebrow">OPERATIONS CONSOLE</p>
        <h1>Xác minh đúng giao dịch trước khi chốt booking.</h1>
        <p>Mọi ca thanh toán chưa rõ trạng thái đều được giữ an toàn để đội vận hành đối chiếu với VNPay.</p>
      </div>
      <p className="story-foot">Reconciliation · Audit source · DB lock</p>
    </section>
    <section className="login-panel">
      <form className="login-card" onSubmit={submit}>
        <p className="eyebrow">ĐĂNG NHẬP QUẢN TRỊ</p>
        <h2>Chào mừng quay lại</h2>
        <p className="muted">Dùng tài khoản có vai trò ADMIN.</p>
        <label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" /></label>
        <label>Mật khẩu<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" /></label>
        {error && <div className="error-box" role="alert">{error}</div>}
        <button className="primary" disabled={busy}>{busy ? 'Đang xác thực…' : 'Đăng nhập'}</button>
      </form>
    </section>
  </main>;
}

function Dashboard({ onLogout }: { onLogout: () => void }) {
  const [items, setItems] = useState<ReviewItem[]>([]);
  const [selected, setSelected] = useState<ReviewItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState<'reconciliation' | 'checklists'>('reconciliation');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    const token = sessionStorage.getItem(TOKEN_KEY);
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/payment-reconciliation`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (response.status === 401 || response.status === 403) return onLogout();
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(getError(payload, 'Không tải được hàng đợi.'));
      setItems(Array.isArray(payload) ? payload : []);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Không tải được hàng đợi.');
    } finally {
      setLoading(false);
    }
  }, [onLogout]);

  useEffect(() => { void load(); }, [load]);

  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return items;
    return items.filter((item) => [item.bookingId, item.intentId, item.providerOrderRef]
      .some((value) => value?.toLowerCase().includes(term)));
  }, [items, query]);

  if (page === 'checklists') return <ChecklistDashboard onLogout={onLogout} onBack={() => setPage('reconciliation')} />;

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">C</span><span>CareSitter</span></div>
      <nav>
        <button className="nav-item active"><span>⌁</span>Đối soát thanh toán</button>
        <button className="nav-item" onClick={() => setPage('checklists')}><span>✓</span>Checklist dịch vụ</button>
        <button className="nav-item" disabled><span>◇</span>Booking</button>
        <button className="nav-item" disabled><span>○</span>Nhân sự</button>
      </nav>
      <button className="nav-item logout" onClick={onLogout}><span>↪</span>Đăng xuất</button>
    </aside>
    <main className="workspace">
      <header className="topbar">
        <div><p className="eyebrow">PAYMENT OPERATIONS</p><h1>Hàng đợi đối soát</h1></div>
        <button className="secondary" onClick={() => void load()} disabled={loading}>↻ Làm mới</button>
      </header>

      <section className="metrics" aria-label="Tổng quan">
        <article><span>Đang chờ xử lý</span><strong>{items.length}</strong><small>Cần quyết định thủ công</small></article>
        <article><span>Quá hạn thanh toán</span><strong>{items.filter((x) => new Date(x.paymentDeadline) < new Date()).length}</strong><small>Đã qua deadline booking</small></article>
        <article><span>Tổng giá trị giữ</span><strong>{formatMoney(items.reduce((sum, x) => sum + x.amount, 0))}</strong><small>Chưa chốt trạng thái</small></article>
      </section>

      <section className="queue-card">
        <div className="queue-head">
          <div><h2>Giao dịch cần kiểm tra</h2><p>Chỉ xác nhận sau khi đối chiếu cổng merchant hoặc sao kê.</p></div>
          <input className="search" placeholder="Tìm booking, intent, TxnRef…" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
        {error && <div className="error-box table-error">{error}</div>}
        {loading ? <div className="empty"><span className="spinner" />Đang tải dữ liệu…</div>
          : filtered.length === 0 ? <div className="empty"><span className="empty-icon">✓</span><strong>Không có giao dịch tồn đọng</strong><p>Hàng đợi hiện đã được xử lý hết.</p></div>
          : <div className="table-wrap"><table>
            <thead><tr><th>Booking / TxnRef</th><th>Số tiền</th><th>Đối soát</th><th>Deadline</th><th /></tr></thead>
            <tbody>{filtered.map((item) => <tr key={item.intentId}>
              <td><strong className="mono">{shortId(item.bookingId)}</strong><small className="mono">{item.providerOrderRef || 'Chưa có TxnRef'}</small></td>
              <td><strong>{formatMoney(item.amount)}</strong><small>{item.currency}</small></td>
              <td><span className="status-dot">Cần kiểm tra</span><small>{item.reconciliationAttempts} lần query</small></td>
              <td><strong>{formatDate(item.paymentDeadline)}</strong><small>{relativeDeadline(item.paymentDeadline)}</small></td>
              <td><button className="row-action" onClick={() => setSelected(item)}>Xử lý →</button></td>
            </tr>)}</tbody>
          </table></div>}
      </section>
    </main>
    {selected && <ReviewPanel item={selected} onClose={() => setSelected(null)} onResolved={() => { setSelected(null); void load(); }} />}
  </div>;
}

function ChecklistDashboard({ onLogout, onBack }: { onLogout: () => void; onBack: () => void }) {
  const [services, setServices] = useState<Service[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [templates, setTemplates] = useState<ChecklistTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [savingPolicy, setSavingPolicy] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState<ChecklistTemplate | null>(null);
  const [form, setForm] = useState({ name: '', description: '', isRequired: true, requiresPhoto: false, sortOrder: 1 });

  const headers = useCallback(() => ({ Authorization: `Bearer ${sessionStorage.getItem(TOKEN_KEY)}`, 'Content-Type': 'application/json' }), []);
  const loadTemplates = useCallback(async (serviceId: string) => {
    if (!serviceId) return;
    setLoading(true); setError('');
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/services/${serviceId}/checklist-templates`, { headers: headers() });
      if (response.status === 401 || response.status === 403) return onLogout();
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(getError(payload, 'Không tải được checklist.'));
      setTemplates(Array.isArray(payload) ? payload : []);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Không tải được checklist.');
    } finally { setLoading(false); }
  }, [headers, onLogout]);

  useEffect(() => {
    void (async () => {
      try {
        const response = await fetch(`${API_BASE}/api/v1/services`);
        const payload = await response.json().catch(() => null);
        if (!response.ok) throw new Error(getError(payload, 'Không tải được danh sách dịch vụ.'));
        const loaded = Array.isArray(payload) ? payload as Service[] : [];
        setServices(loaded);
        if (loaded[0]) setSelectedId(loaded[0].id);
      } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không tải được danh sách dịch vụ.'); }
    })();
  }, []);
  useEffect(() => { void loadTemplates(selectedId); }, [selectedId, loadTemplates]);

  function resetForm() { setEditing(null); setForm({ name: '', description: '', isRequired: true, requiresPhoto: false, sortOrder: templates.length + 1 }); }
  function edit(template: ChecklistTemplate) {
    setEditing(template);
    setForm({ name: template.name, description: template.description || '', isRequired: template.isRequired, requiresPhoto: template.requiresPhoto, sortOrder: template.sortOrder });
  }
  async function save(event: FormEvent) {
    event.preventDefault();
    if (!selectedId) return;
    setSaving(true); setError('');
    try {
      const path = editing
        ? `/api/v1/admin/services/${selectedId}/checklist-templates/${editing.id}`
        : `/api/v1/admin/services/${selectedId}/checklist-templates`;
      const response = await fetch(`${API_BASE}${path}`, { method: editing ? 'PUT' : 'POST', headers: headers(), body: JSON.stringify(form) });
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(getError(payload, 'Không thể lưu checklist.'));
      resetForm(); await loadTemplates(selectedId);
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể lưu checklist.'); }
    finally { setSaving(false); }
  }
  async function toggle(template: ChecklistTemplate) {
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/services/${selectedId}/checklist-templates/${template.id}/active`, {
        method: 'PATCH', headers: headers(), body: JSON.stringify({ isActive: !template.isActive }),
      });
      if (!response.ok) throw new Error(getError(await response.json().catch(() => null), 'Không thể cập nhật trạng thái.'));
      await loadTemplates(selectedId);
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể cập nhật trạng thái.'); }
  }
  async function remove(template: ChecklistTemplate) {
    if (!window.confirm(`Xóa “${template.name}” khỏi checklist? Booking đã xác nhận sẽ không bị thay đổi.`)) return;
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/services/${selectedId}/checklist-templates/${template.id}`, { method: 'DELETE', headers: headers() });
      if (!response.ok) throw new Error(getError(await response.json().catch(() => null), 'Không thể xóa checklist.'));
      if (editing?.id === template.id) resetForm();
      await loadTemplates(selectedId);
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể xóa checklist.'); }
  }
  async function setAllowAdHocTasks(allowAdHocTasks: boolean) {
    if (!selectedId) return;
    setSavingPolicy(true); setError('');
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/services/${selectedId}/checklist-policy`, {
        method: 'PATCH', headers: headers(), body: JSON.stringify({ allowAdHocTasks }),
      });
      if (!response.ok) throw new Error(getError(await response.json().catch(() => null), 'Không thể cập nhật chính sách.'));
      setServices((current) => current.map((service) => service.id === selectedId ? { ...service, allowAdHocTasks } : service));
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể cập nhật chính sách.'); }
    finally { setSavingPolicy(false); }
  }
  const selectedService = services.find((service) => service.id === selectedId);

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">C</span><span>CareSitter</span></div>
      <nav>
        <button className="nav-item" onClick={onBack}><span>⌁</span>Đối soát thanh toán</button>
        <button className="nav-item active"><span>✓</span>Checklist dịch vụ</button>
        <button className="nav-item" disabled><span>◇</span>Booking</button>
      </nav>
      <button className="nav-item logout" onClick={onLogout}><span>↪</span>Đăng xuất</button>
    </aside>
    <main className="workspace checklist-workspace">
      <header className="topbar"><div><p className="eyebrow">SERVICE CONFIGURATION</p><h1>Checklist theo gói</h1><p className="muted">Thay đổi chỉ áp dụng cho booking được xác nhận sau thời điểm lưu.</p></div></header>
      <section className="checklist-layout">
        <aside className="service-list" aria-label="Danh sách dịch vụ">
          <h2>Gói dịch vụ</h2>
          {services.map((service) => <button key={service.id} className={`service-option ${service.id === selectedId ? 'selected' : ''}`} onClick={() => setSelectedId(service.id)}>
            <strong>{service.name}</strong><small>{service.code}</small>
          </button>)}
        </aside>
        <div className="checklist-content">
          {error && <div className="error-box">{error}</div>}
          <section className="template-list">
            <div className="section-head"><div><h2>Công việc mẫu</h2><p>Yêu cầu ảnh và bắt buộc được snapshot vào từng ca mới.</p></div><span className="count-chip">{templates.length} việc</span></div>
            <div className="policy-row"><div><strong>Cho phép việc phát sinh</strong><p>Caregiver có thể thêm tối đa 20 việc sau khi check-in.</p></div><label className="switch"><input type="checkbox" checked={selectedService?.allowAdHocTasks ?? false} disabled={savingPolicy || !selectedService} onChange={(event) => void setAllowAdHocTasks(event.target.checked)} /><span /></label></div>
            {loading ? <div className="empty"><span className="spinner" />Đang tải checklist…</div>
              : templates.length === 0 ? <div className="empty"><span className="empty-icon">✓</span><strong>Chưa có công việc mẫu</strong><p>Thêm công việc đầu tiên cho gói này ở biểu mẫu bên phải.</p></div>
              : <div className="template-rows">{templates.map((template) => <article className={`template-row ${template.isActive ? '' : 'inactive'}`} key={template.id}>
                <div className="order-badge">{template.sortOrder}</div><div className="template-copy"><strong>{template.name}</strong>{template.description && <p>{template.description}</p>}<div className="template-tags"><span>{template.isRequired ? 'Bắt buộc' : 'Tùy chọn'}</span>{template.requiresPhoto && <span>Yêu cầu ảnh</span>}{!template.isActive && <span>Đang tắt</span>}</div></div>
                <div className="template-actions"><button className="row-action" onClick={() => edit(template)}>Sửa</button><button className="row-action" onClick={() => void toggle(template)}>{template.isActive ? 'Tắt' : 'Bật'}</button><button className="row-action delete-action" onClick={() => void remove(template)}>Xóa</button></div>
              </article>)}</div>}
          </section>
          <form className="template-form" onSubmit={save}>
            <div className="section-head"><div><h2>{editing ? 'Chỉnh sửa công việc' : 'Thêm công việc'}</h2><p>{editing ? 'Cập nhật sẽ không làm đổi checklist của các ca đã xác nhận.' : 'Công việc mới sẽ có trong các booking xác nhận sau này.'}</p></div>{editing && <button className="secondary" type="button" onClick={resetForm}>Hủy sửa</button>}</div>
            <label>Tên công việc<input value={form.name} maxLength={255} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Ví dụ: Nhắc lịch uống thuốc" required /></label>
            <label>Mô tả<textarea value={form.description} maxLength={1000} rows={3} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="Hướng dẫn ngắn cho caregiver" /></label>
            <div className="form-grid"><label>Thứ tự<input type="number" min="0" max="1000" value={form.sortOrder} onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })} required /></label><div className="toggle-group"><label><input type="checkbox" checked={form.isRequired} onChange={(e) => setForm({ ...form, isRequired: e.target.checked })} /> Bắt buộc</label><label><input type="checkbox" checked={form.requiresPhoto} onChange={(e) => setForm({ ...form, requiresPhoto: e.target.checked })} /> Yêu cầu ảnh</label></div></div>
            <button className="primary" disabled={saving}>{saving ? 'Đang lưu…' : editing ? 'Lưu thay đổi' : 'Thêm vào checklist'}</button>
          </form>
        </div>
      </section>
    </main>
  </div>;
}

function ReviewPanel({ item, onClose, onResolved }: { item: ReviewItem; onClose: () => void; onResolved: () => void }) {
  const [reason, setReason] = useState('');
  const [transactionId, setTransactionId] = useState(item.providerTransactionId || '');
  const [busy, setBusy] = useState<'confirm' | 'reject' | ''>('');
  const [error, setError] = useState('');

  async function resolve(succeeded: boolean) {
    if (!reason.trim()) return setError('Vui lòng nhập lý do và bằng chứng đã kiểm tra.');
    if (succeeded && !transactionId.trim()) return setError('Cần nhập mã giao dịch VNPay khi xác nhận thành công.');
    setBusy(succeeded ? 'confirm' : 'reject');
    setError('');
    try {
      const response = await fetch(`${API_BASE}/api/v1/admin/payment-reconciliation/${item.intentId}/resolve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${sessionStorage.getItem(TOKEN_KEY)}` },
        body: JSON.stringify({ succeeded, reason: reason.trim(), providerTransactionId: transactionId.trim() || null }),
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(getError(payload, 'Không thể chốt giao dịch.'));
      onResolved();
    } catch (reasonValue) {
      setError(reasonValue instanceof Error ? reasonValue.message : 'Không thể chốt giao dịch.');
    } finally {
      setBusy('');
    }
  }

  return <div className="drawer-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <aside className="drawer" role="dialog" aria-modal="true" aria-label="Xử lý đối soát">
      <div className="drawer-head"><div><p className="eyebrow">MANUAL REVIEW</p><h2>Chốt giao dịch</h2></div><button className="close" onClick={onClose}>×</button></div>
      <div className="warning"><strong>Đối chiếu trước khi quyết định</strong><p>Xác nhận sẽ kích hoạt booking và khóa escrow. Từ chối sẽ hủy booking và trả slot caregiver.</p></div>
      <dl className="details">
        <div><dt>Booking</dt><dd className="mono">{item.bookingId}</dd></div>
        <div><dt>VNPay TxnRef</dt><dd className="mono">{item.providerOrderRef || '—'}</dd></div>
        <div><dt>Số tiền</dt><dd>{formatMoney(item.amount)}</dd></div>
        <div><dt>Lần query</dt><dd>{item.reconciliationAttempts}</dd></div>
        <div><dt>Lỗi gần nhất</dt><dd>{item.lastReconciliationError || item.manualReviewReason || 'Không có phản hồi chắc chắn'}</dd></div>
      </dl>
      <label>Mã giao dịch VNPay<input value={transactionId} onChange={(e) => setTransactionId(e.target.value)} placeholder="Nhập từ merchant portal" /></label>
      <label>Ghi chú kiểm tra<textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={4} placeholder="Ví dụ: Đã đối chiếu merchant portal lúc 15:42…" /></label>
      {error && <div className="error-box">{error}</div>}
      <div className="drawer-actions">
        <button className="danger" disabled={!!busy} onClick={() => void resolve(false)}>{busy === 'reject' ? 'Đang hủy…' : 'Từ chối & hủy booking'}</button>
        <button className="primary" disabled={!!busy} onClick={() => void resolve(true)}>{busy === 'confirm' ? 'Đang xác nhận…' : 'Xác nhận đã thanh toán'}</button>
      </div>
    </aside>
  </div>;
}

function formatMoney(value: number) { return new Intl.NumberFormat('vi-VN').format(value) + ' ₫'; }
function formatDate(value: string) { return new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value)); }
function shortId(value: string) { return `#${value.slice(0, 8).toUpperCase()}`; }
function relativeDeadline(value: string) {
  const minutes = Math.round((Date.now() - new Date(value).getTime()) / 60000);
  return minutes >= 0 ? `Quá hạn ${minutes} phút` : `Còn ${Math.abs(minutes)} phút`;
}

function App() {
  const [authenticated, setAuthenticated] = useState(() => !!sessionStorage.getItem(TOKEN_KEY));
  const logout = useCallback(() => { sessionStorage.removeItem(TOKEN_KEY); setAuthenticated(false); }, []);
  return authenticated ? <Dashboard onLogout={logout} /> : <Login onLoggedIn={() => setAuthenticated(true)} />;
}

createRoot(document.getElementById('root')!).render(<App />);
