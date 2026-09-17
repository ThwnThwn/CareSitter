import { FormEvent, ReactNode, useCallback, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { AdminMetadataProvider } from './adminMetadata';
import { api, TOKEN_KEY } from './api';
import { Shell } from './components/Shell';
import { BookingsPage } from './pages/BookingsPage';
import { DashboardPage } from './pages/DashboardPage';
import { DisputesPage } from './pages/DisputesPage';
import { KycPage } from './pages/KycPage';
import { PaymentsPage } from './pages/PaymentsPage';
import { ServicesPage } from './pages/ServicesPage';
import { SupportPage } from './pages/SupportPage';
import { UsersPage } from './pages/UsersPage';
import { AdminMetadata, PageKey } from './types';
import './styles.css';

type LoginResponse = { accessToken: string; roles: string[]; displayName?: string };
const pageRenderers: Record<PageKey, (navigate: (page: PageKey) => void) => ReactNode> = {
  dashboard: (navigate) => <DashboardPage onNavigate={navigate} />,
  bookings: () => <BookingsPage />,
  kyc: () => <KycPage />,
  payments: () => <PaymentsPage />,
  support: () => <SupportPage />,
  disputes: () => <DisputesPage />,
  services: () => <ServicesPage />,
  users: () => <UsersPage />,
};
const pages = Object.keys(pageRenderers) as PageKey[];

function pageFromHash(): PageKey {
  const value = window.location.hash.replace('#/', '') as PageKey;
  return pages.includes(value) ? value : 'dashboard';
}

function Login({ onLoggedIn }: { onLoggedIn: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError('');
    try {
      const payload = await api<LoginResponse>('/api/v1/auth/login/password', {
        method: 'POST', body: JSON.stringify({ email, password, requiredRole: 'ADMIN' }),
      });
      if (!payload.accessToken || !payload.roles?.some((role) => role.toUpperCase() === 'ADMIN')) {
        throw new Error('Tài khoản không có quyền quản trị.');
      }
      sessionStorage.setItem(TOKEN_KEY, payload.accessToken);
      onLoggedIn();
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Không thể đăng nhập.'); }
    finally { setBusy(false); }
  }
  return <main className="login-page">
    <section className="login-story"><div className="brand"><span className="brand-mark">C</span><span><strong>CareSitter</strong><small>Operations Console</small></span></div><div className="story-copy"><span>VẬN HÀNH CHĂM SÓC</span><h1>Mọi quyết định quan trọng ở đúng một nơi.</h1><p>Duyệt hồ sơ, đối soát thanh toán và xử lý ca chăm sóc bằng dữ liệu được ghi nhận từ hệ thống.</p></div><p className="story-foot">Identity · Booking · Payments · Support</p></section>
    <section className="login-panel"><form className="login-card" onSubmit={submit}><span className="form-kicker">ĐĂNG NHẬP QUẢN TRỊ</span><h2>Chào mừng quay lại</h2><p>Dùng tài khoản có vai trò ADMIN.</p><label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" /></label><label>Mật khẩu<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" /></label>{error && <div className="notice error-notice" role="alert">{error}</div>}<button className="primary login-submit" disabled={busy}>{busy ? 'Đang xác thực…' : 'Đăng nhập'}</button></form></section>
  </main>;
}

function AdminApp({ onLogout }: { onLogout: () => void }) {
  const [page, setPage] = useState<PageKey>(pageFromHash);
  const [metadata, setMetadata] = useState<AdminMetadata | null>(null);
  const [metadataError, setMetadataError] = useState('');
  const [metadataRequest, setMetadataRequest] = useState(0);

  useEffect(() => {
    let active = true;
    setMetadataError('');
    void api<AdminMetadata>('/api/v1/admin/metadata')
      .then((value) => { if (active) setMetadata(value); })
      .catch((reason) => {
        if (active) setMetadataError(reason instanceof Error ? reason.message : 'Không tải được cấu hình quản trị.');
      });
    return () => { active = false; };
  }, [metadataRequest]);

  useEffect(() => {
    const onHashChange = () => setPage(pageFromHash());
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  useEffect(() => {
    if (!metadata || metadata.navigation.some((item) => item.key === page)) return;
    const fallback = metadata.navigation[0]?.key || 'dashboard';
    window.location.hash = `/${fallback}`;
    setPage(fallback);
  }, [metadata, page]);

  function navigate(next: PageKey) { window.location.hash = `/${next}`; setPage(next); window.scrollTo({ top: 0, behavior: 'smooth' }); }
  if (metadataError) return <main className="boot-screen"><div className="boot-card"><strong>Không thể mở Operations Console</strong><p>{metadataError}</p><div className="button-row"><button className="primary" onClick={() => setMetadataRequest((value) => value + 1)}>Thử lại</button><button className="secondary" onClick={onLogout}>Đăng xuất</button></div></div></main>;
  if (!metadata) return <main className="boot-screen" aria-busy="true"><div className="boot-card"><span className="boot-spinner" /><strong>Đang tải cấu hình quản trị…</strong><p>Đồng bộ quyền truy cập và quy tắc vận hành từ hệ thống.</p></div></main>;

  return <AdminMetadataProvider value={metadata}>
    <Shell page={page} onNavigate={navigate} onLogout={onLogout}>{pageRenderers[page](navigate)}</Shell>
  </AdminMetadataProvider>;
}

function App() {
  const [authenticated, setAuthenticated] = useState(() => !!sessionStorage.getItem(TOKEN_KEY));
  const logout = useCallback(() => { sessionStorage.removeItem(TOKEN_KEY); setAuthenticated(false); }, []);
  useEffect(() => {
    window.addEventListener('admin:unauthorized', logout);
    return () => window.removeEventListener('admin:unauthorized', logout);
  }, [logout]);
  return authenticated ? <AdminApp onLogout={logout} /> : <Login onLoggedIn={() => setAuthenticated(true)} />;
}

createRoot(document.getElementById('root')!).render(<App />);
