const defaultApiBase = import.meta.env.PROD ? window.location.origin : 'http://localhost:5033';
export const API_BASE = (import.meta.env.VITE_API_BASE_URL || defaultApiBase).replace(/\/$/, '');
export const TOKEN_KEY = 'caresitter_admin_access_token';

export class ApiError extends Error {
  constructor(message: string, public status: number, public code?: string) {
    super(message);
  }
}

function errorMessage(payload: unknown, fallback: string) {
  if (payload && typeof payload === 'object') {
    const data = payload as Record<string, unknown>;
    return String(data.detail || data.error || data.message || data.title || fallback);
  }
  return fallback;
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = sessionStorage.getItem(TOKEN_KEY);
  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init.body && !(init.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const response = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (response.status === 401 && token && sessionStorage.getItem(TOKEN_KEY) === token) {
    window.dispatchEvent(new CustomEvent('admin:unauthorized'));
  }
  if (response.status === 204) return undefined as T;
  const payload = await response.json().catch(() => null);
  const fallback = response.status >= 500 ? 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.'
    : response.status === 403 ? 'Bạn không có quyền thực hiện thao tác này.'
      : response.status === 409 ? 'Dữ liệu đã thay đổi. Vui lòng tải lại trước khi tiếp tục.' : 'Không thể hoàn tất yêu cầu.';
  const message = response.status >= 500 ? fallback : errorMessage(payload, fallback);
  if (!response.ok) throw new ApiError(message, response.status,
    payload && typeof payload === 'object' && typeof payload.title === 'string' ? payload.title : undefined);
  if (payload === null) throw new ApiError('Phản hồi máy chủ không hợp lệ. Vui lòng thử lại.', response.status);
  return payload as T;
}

export async function logoutSession(): Promise<string> {
  if (!sessionStorage.getItem(TOKEN_KEY)) return '';
  try {
    await api('/api/v1/auth/logout', { method: 'POST', body: '{}', signal: AbortSignal.timeout(10_000) });
    return '';
  } catch (cause) {
    if (cause instanceof ApiError && cause.status === 401) return '';
    return 'Đã đăng xuất trên trình duyệt này nhưng chưa xác nhận thu hồi phiên trên máy chủ. Hãy kiểm tra kết nối hoặc liên hệ quản trị nếu cần khóa phiên.';
  } finally {
    sessionStorage.removeItem(TOKEN_KEY);
  }
}

export async function kycImage(mediaId: string, signal: AbortSignal): Promise<Blob> {
  const access = await api<{ url: string; ticket: string }>(`/api/v1/media/${mediaId}/access`, { method: 'POST', cache: 'no-store', signal });
  // Only send the JWT back to our fixed content route, never to a provider/client URL.
  if (access.url !== `/api/v1/media/${mediaId}/content` ||
      typeof access.ticket !== 'string' || !/^[A-Za-z0-9_-]{1,2048}$/.test(access.ticket)) {
    throw new ApiError('Đường đọc tài liệu không hợp lệ.', 502);
  }
  const token = sessionStorage.getItem(TOKEN_KEY);
  if (!token) throw new ApiError('Phiên đăng nhập đã kết thúc.', 401);
  const response = await fetch(`${API_BASE}${access.url}`, {
    headers: { Authorization: `Bearer ${token}`, 'X-Kyc-Read-Ticket': access.ticket }, cache: 'no-store', referrerPolicy: 'no-referrer', signal,
  });
  if (response.status === 401 && sessionStorage.getItem(TOKEN_KEY) === token) {
    window.dispatchEvent(new CustomEvent('admin:unauthorized'));
  }
  if (!response.ok) throw new ApiError('Không thể đọc tài liệu. Phiên/link có thể đã hết hạn; hãy thử lại.', response.status);
  if (sessionStorage.getItem(TOKEN_KEY) !== token) throw new ApiError('Phiên đăng nhập đã thay đổi.', 401);
  const blob = await response.blob();
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(blob.type) || blob.size > 10 * 1024 * 1024) {
    throw new ApiError('Tài liệu trả về không phải ảnh hợp lệ.', 502);
  }
  return blob;
}

export function qs(values: Record<string, string | number | undefined | null>) {
  const params = new URLSearchParams();
  Object.entries(values).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') params.set(key, String(value));
  });
  const text = params.toString();
  return text ? `?${text}` : '';
}

export function jsonBody(value: unknown): RequestInit {
  return { body: JSON.stringify(value) };
}
