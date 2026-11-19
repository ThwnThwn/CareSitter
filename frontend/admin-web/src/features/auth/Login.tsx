import { FormEvent, useState } from 'react';
import { Brand } from '../../components/Brand';
import careAtHome from '../../assets/care-at-home.jpg';
import { api, TOKEN_KEY } from '../../api';

export type LoginResponse = { accessToken: string; roles: string[]; displayName?: string };

interface LoginProps {
  onLoggedIn: () => void;
  notice?: string;
}

export function Login({ onLoggedIn, notice }: LoginProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const payload = await api<LoginResponse>('/api/v1/auth/login/password', {
        method: 'POST',
        body: JSON.stringify({ email, password, requiredRole: 'ADMIN' }),
      });
      if (!payload.accessToken || !payload.roles?.some((role) => role.toUpperCase() === 'ADMIN')) {
        throw new Error('Tài khoản không có quyền quản trị.');
      }
      // Token phải được lưu trước khi gọi onLoggedIn() —
      // callback sẽ render ngay component con cần token trong sessionStorage.
      sessionStorage.setItem(TOKEN_KEY, payload.accessToken);
      onLoggedIn();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Không thể đăng nhập.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login-page">
      <div className="login-story">
        <Brand />
        <div className="story-copy">
          <h2>Điều phối ca chăm sóc</h2>
          <p>Theo dõi lịch chăm sóc, duyệt hồ sơ người chăm sóc và đối soát thanh toán.</p>
        </div>
        <img className="login-photo" src={careAtHome} alt="Người chăm sóc trò chuyện cùng gia đình tại nhà" />
      </div>
      <section className="login-panel">
        <form className="login-card" onSubmit={submit}>
          <h1>Đăng nhập quản trị</h1>
          <p>Sử dụng tài khoản quản trị CareSitter của bạn.</p>
          {notice && (
            <div className="notice" role="status">
              {notice}
            </div>
          )}
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </label>
          <label>
            Mật khẩu
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </label>
          {error && (
            <div className="notice error-notice" role="alert">
              {error}
            </div>
          )}
          <button className="primary login-submit" disabled={busy}>
            {busy ? 'Đang xác thực…' : 'Đăng nhập'}
          </button>
        </form>
      </section>
    </main>
  );
}
