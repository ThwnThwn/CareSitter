export const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5033').replace(/\/$/, '');
export const TOKEN_KEY = 'caresitter_admin_access_token';

export class ApiError extends Error {
  constructor(message: string, public status: number) {
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
  if (response.status === 401 || response.status === 403) {
    window.dispatchEvent(new CustomEvent('admin:unauthorized'));
  }
  if (response.status === 204) return undefined as T;
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(errorMessage(payload, 'Không thể hoàn tất yêu cầu.'), response.status);
  return payload as T;
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
