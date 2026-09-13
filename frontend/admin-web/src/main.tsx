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

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">C</span><span>CareSitter</span></div>
      <nav>
        <button className="nav-item active"><span>⌁</span>Đối soát thanh toán</button>
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
