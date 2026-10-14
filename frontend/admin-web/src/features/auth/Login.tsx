import { FormEvent, useState } from 'react';
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
      <section className="login-story">
        <div className="brand">
          <span className="brand-mark">C</span>
          <span>
            <strong>CareSitter</strong>
            <small>Operations Console</small>
          </span>
        </div>
        <div className="story-copy">
          <span>VẬN HÀNH CHĂM SÓC</span>
          <h1>Mọi quyết định quan trọng ở đúng một nơi.</h1>
          <p>Duyệt hồ sơ, đối soát thanh toán và xử lý ca chăm sóc bằng dữ liệu được ghi nhận từ hệ thống.</p>
        </div>
        <p className="story-foot">Identity · Booking · Payments · Support</p>
      </section>
      <section className="login-panel">
        <form className="login-card" onSubmit={submit}>
          <span className="form-kicker">ĐĂNG NHẬP QUẢN TRỊ</span>
          <h2>Chào mừng quay lại</h2>
          <p>Dùng tài khoản có vai trò ADMIN.</p>
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
