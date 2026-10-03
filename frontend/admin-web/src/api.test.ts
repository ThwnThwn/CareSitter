import { describe, expect, it, vi } from 'vitest';
import { api, logoutSession, TOKEN_KEY } from './api';

describe('session handling', () => {
  it('keeps the session on 403 and exposes the permission error', async () => {
    sessionStorage.setItem(TOKEN_KEY, 'current');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 403 })));
    const dispatch = vi.spyOn(window, 'dispatchEvent');
    await expect(api('/restricted')).rejects.toThrow('không có quyền');
    expect(dispatch).not.toHaveBeenCalled();
    expect(sessionStorage.getItem(TOKEN_KEY)).toBe('current');
  });
  it('expires the current session on 401', async () => {
    sessionStorage.setItem(TOKEN_KEY, 'current');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 401 })));
    const dispatch = vi.spyOn(window, 'dispatchEvent');
    await expect(api('/protected')).rejects.toThrow();
    expect(dispatch).toHaveBeenCalledWith(expect.objectContaining({ type: 'admin:unauthorized' }));
  });
  it('does not expire a newer login when an old request gets 401', async () => {
    sessionStorage.setItem(TOKEN_KEY, 'old');
    vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => {
      sessionStorage.setItem(TOKEN_KEY, 'new');
      return new Response('{}', { status: 401 });
    }));
    const dispatch = vi.spyOn(window, 'dispatchEvent');
    await expect(api('/protected')).rejects.toThrow();
    expect(dispatch).not.toHaveBeenCalled();
  });
  it('revokes the authenticated session before clearing the local token', async () => {
    sessionStorage.setItem(TOKEN_KEY, 'current');
    const fetch = vi.fn().mockImplementation(async (_url, init: RequestInit) => {
      expect(sessionStorage.getItem(TOKEN_KEY)).toBe('current');
      expect(new Headers(init.headers).get('Authorization')).toBe('Bearer current');
      expect(init.method).toBe('POST');
      return new Response(null, { status: 204 });
    });
    vi.stubGlobal('fetch', fetch);
    expect(await logoutSession()).toBe('');
    expect(fetch.mock.calls[0][0]).toMatch(/\/api\/v1\/auth\/logout$/);
    expect(sessionStorage.getItem(TOKEN_KEY)).toBeNull();
  });
  it('clears the local session but reports unconfirmed revocation on network failure', async () => {
    sessionStorage.setItem(TOKEN_KEY, 'current');
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('offline')));
    expect(await logoutSession()).toContain('chưa xác nhận thu hồi phiên');
    expect(sessionStorage.getItem(TOKEN_KEY)).toBeNull();
  });
  it('rejects an HTML fallback returned with status 200', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('<html>app</html>')));
    await expect(api('/data')).rejects.toThrow('không hợp lệ');
  });
});
