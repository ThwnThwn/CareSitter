import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { CrashReportsPage } from './CrashReportsPage';

const page = { sourceStatus: 'ready', exportMode: 'batch', queriedAt: '2026-11-07T08:00:00Z',
  windowEnd: '2026-11-07T08:00:00Z', days: 7, page: 1, pageSize: 20, hasMore: false, items: [] };
function respond(data: unknown, status = 200) {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify(data), { status })));
}
it('distinguishes unconfigured source from a successfully queried empty export', async () => {
  respond({ ...page, sourceStatus: 'not_configured' });
  render(<CrashReportsPage />);
  expect(await screen.findByText('Nguồn báo cáo chưa được cấu hình')).toBeTruthy();
  expect(screen.queryByText('Chưa có báo cáo trong cửa sổ này')).toBeNull();
});
it('does not show old or empty success when the provider is unavailable', async () => {
  respond({ title: 'crash.source_unavailable' }, 503);
  render(<CrashReportsPage />);
  expect(await screen.findByRole('alert')).toBeTruthy();
  expect(screen.queryByText('Chưa có báo cáo trong cửa sổ này')).toBeNull();
});
it('shows real source timestamps and correlation ID and resets page on filtering', async () => {
  respond({ ...page, hasMore: true, items: [{ eventId: 'event', issueId: 'issue',
    occurredAt: page.queriedAt, errorType: 'NON_FATAL', appVersion: '1.0', buildVersion: '1',
    platform: 'ANDROID', screen: 'lab3_diagnostics', demoRunId: 'demo-run' }] });
  render(<CrashReportsPage />);
  expect(await screen.findByText('NON_FATAL')).toBeTruthy();
  await userEvent.click(screen.getByText('Mã báo cáo'));
  expect(screen.getByText('demo-run')).toBeTruthy();
  await userEvent.click(screen.getByRole('button', { name: 'Trang sau' }));
  await waitFor(() => expect(fetch).toHaveBeenLastCalledWith(expect.stringContaining('page=2'), expect.anything()));
  await userEvent.selectOptions(screen.getByLabelText('Loại lỗi'), 'FATAL');
  await waitFor(() => expect(fetch).toHaveBeenLastCalledWith(expect.stringMatching(/page=1.*errorType=FATAL/), expect.anything()));
});
