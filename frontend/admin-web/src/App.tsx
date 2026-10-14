import { useCallback, useEffect, useState } from 'react';
import { AdminMetadataProvider } from './adminMetadata';
import { api, logoutSession, TOKEN_KEY } from './api';
import { Shell } from './components/Shell';
import { Login } from './features/auth/Login';
import { pageFromHash, pageRenderers } from './routes';
import { AdminMetadata, PageKey } from './types';

export function AdminApp({ onLogout }: { onLogout: () => void }) {
  const [page, setPage] = useState<PageKey>(pageFromHash);
  const [metadata, setMetadata] = useState<AdminMetadata | null>(null);
  const [metadataError, setMetadataError] = useState('');
  const [metadataRequest, setMetadataRequest] = useState(0);

  useEffect(() => {
    let active = true;
    setMetadataError('');
    void api<AdminMetadata>('/api/v1/admin/metadata')
      .then((value) => {
        if (active) setMetadata(value);
      })
      .catch((reason) => {
        if (active) setMetadataError(reason instanceof Error ? reason.message : 'Không tải được cấu hình quản trị.');
      });
    return () => {
      active = false;
    };
  }, [metadataRequest]);

  useEffect(() => {
    const onHashChange = () => setPage(pageFromHash());
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  function navigate(next: PageKey) {
    // hash change tự cập nhật state qua listener — không cần gọi setPage thêm.
    window.location.hash = `/${next}`;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  if (metadataError) {
    return (
      <main className="boot-screen">
        <div className="boot-card">
          <strong>Không thể mở Operations Console</strong>
          <p>{metadataError}</p>
          <div className="button-row">
            <button className="primary" onClick={() => setMetadataRequest((value) => value + 1)}>
              Thử lại
            </button>
            <button className="secondary" onClick={onLogout}>
              Đăng xuất
            </button>
          </div>
        </div>
      </main>
    );
  }

  if (!metadata) {
    return (
      <main className="boot-screen" aria-busy="true">
        <div className="boot-card">
          <span className="boot-spinner" />
          <strong>Đang tải cấu hình quản trị…</strong>
          <p>Đồng bộ quyền truy cập và quy tắc vận hành từ hệ thống.</p>
        </div>
      </main>
    );
  }

  // Kiểm tra quyền đồng bộ trước khi render — tránh flash 1 frame của page không có quyền.
  // Server vẫn là tuyến bảo vệ chính (trả 403); guard này chỉ để UX.
  const allowedItem = metadata.navigation.find((item) => item.key === page);
  if (!allowedItem) {
    const fallback = metadata.navigation[0]?.key || 'dashboard';
    window.location.hash = `/${fallback}`;
    return null;
  }

  return (
    <AdminMetadataProvider value={metadata}>
      {/* key=page reset ErrorBoundary khi chuyển trang — tránh state lỗi của page cũ */}
      <Shell key={page} page={page} onNavigate={navigate} onLogout={onLogout} pageLabel={allowedItem.label}>
        {pageRenderers[page](navigate)}
      </Shell>
    </AdminMetadataProvider>
  );
}

export function App() {
  const [authenticated, setAuthenticated] = useState(() => !!sessionStorage.getItem(TOKEN_KEY));
  const [loggingOut, setLoggingOut] = useState(false);
  const [notice, setNotice] = useState('');

  const expireSession = useCallback(() => {
    sessionStorage.removeItem(TOKEN_KEY);
    setAuthenticated(false);
    setNotice('Phiên đăng nhập đã hết hiệu lực. Vui lòng đăng nhập lại.');
  }, []);

  const logout = useCallback(async () => {
    setLoggingOut(true);
    setNotice(await logoutSession());
    setAuthenticated(false);
    setLoggingOut(false);
  }, []);

  useEffect(() => {
    window.addEventListener('admin:unauthorized', expireSession);
    return () => window.removeEventListener('admin:unauthorized', expireSession);
  }, [expireSession]);

  if (loggingOut) return <main className="boot-screen" aria-busy="true">Đang thu hồi phiên đăng nhập…</main>;

  return authenticated ? (
    <AdminApp onLogout={() => void logout()} />
  ) : (
    <Login
      notice={notice}
      onLoggedIn={() => {
        setNotice('');
        setAuthenticated(true);
      }}
    />
  );
}
