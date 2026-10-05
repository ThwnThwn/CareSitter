import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { KycDocument, KycPage } from './KycPage';
import { TOKEN_KEY } from '../api';

vi.mock('../adminMetadata', () => ({
  useAdminMetadata: () => ({
    statusDefinitions: {}, filters: { kyc: { defaultValue: 'PENDING', options: [{ value: 'PENDING', label: 'Chờ duyệt' }] } },
    reviewableStatuses: { kyc: ['PENDING'] }, constraints: { rejectionReasonMinLength: 5 },
  }),
}));

it('does not render old public CCCD URLs and disables approval for legacy profiles', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ items: [{
    id: 'profile-1', userId: 'user-1', fullName: 'Caregiver Test', kycStatus: 'PENDING',
    requiresSecureResubmission: true, cccdFrontUrl: 'https://public.invalid/cccd.png',
    createdAt: '2026-10-04T00:00:00Z', updatedAt: '2026-10-04T00:00:00Z',
  }], total: 1, page: 1, pageSize: 20 })));
  const { container } = render(<KycPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Kiểm tra hồ sơ' }));
  expect((screen.getByRole('button', { name: 'Duyệt KYC' }) as HTMLButtonElement).disabled).toBe(true);
  expect(container.innerHTML).not.toContain('public.invalid');
  expect(screen.getByText(/Tài liệu cũ không được mở/)).toBeTruthy();
});

it('fetches a private image with a bearer header and revokes its blob on close', async () => {
  sessionStorage.setItem(TOKEN_KEY, 'admin-test');
  const id = '11111111-1111-1111-1111-111111111111';
  const fetch = vi.fn().mockImplementation(async (url: string, _init: RequestInit) => url.endsWith('/access')
    ? Response.json({ url: `/api/v1/media/${id}/content`, ticket: 'test' })
    : new Response(new Uint8Array([137, 80, 78, 71]), { headers: { 'Content-Type': 'image/png' } }));
  vi.stubGlobal('fetch', fetch);
  const create = vi.fn().mockReturnValue('blob:unit-test'); const revoke = vi.fn();
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: create, revokeObjectURL: revoke }));
  const { unmount } = render(<KycDocument label="CCCD mặt trước" mediaId={id} />);
  expect(await screen.findByAltText('CCCD mặt trước')).toBeTruthy();
  expect((screen.getByAltText('CCCD mặt trước') as HTMLImageElement).src).toBe('blob:unit-test');
  expect(new Headers(fetch.mock.calls[1][1].headers).get('Authorization')).toBe('Bearer admin-test');
  expect(fetch.mock.calls[1][1].cache).toBe('no-store');
  expect(new Headers(fetch.mock.calls[1][1].headers).get('X-Kyc-Read-Ticket')).toBe('test');
  unmount(); expect(revoke).toHaveBeenCalledWith('blob:unit-test');
});

it('shows a retry action for a failed private document without a public URL fallback', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Không thể đọc tài liệu.')));
  render(<KycDocument label="CCCD mặt sau" mediaId="media-2" />);
  expect(await screen.findByRole('button', { name: 'Thử lại' })).toBeTruthy();
  expect(screen.queryByRole('img')).toBeNull();
  await userEvent.click(screen.getByRole('button', { name: 'Thử lại' }));
  await waitFor(() => expect(fetch).toHaveBeenCalledTimes(2));
});
