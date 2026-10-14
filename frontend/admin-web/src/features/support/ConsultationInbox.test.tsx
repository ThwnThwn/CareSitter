import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { ConsultationInbox } from './ConsultationInbox';

const request = {
  id: 'a27c002c-e139-470a-961c-5e2d44b36b1d',
  contactName: 'Khách tư vấn',
  phone: '0901234567',
  serviceCategory: 'elderly_care',
  preferredDate: '2026-10-15',
  hours: 4,
  note: 'Liên hệ buổi sáng',
  consentAt: '2026-10-12T01:00:00Z',
  createdAt: '2026-10-12T01:00:00Z',
};

it('loads saved contact information and opens the request details', async () => {
  const fetch = vi
    .fn()
    .mockResolvedValue(Response.json({ items: [request], total: 1, page: 1, pageSize: 20 }));
  vi.stubGlobal('fetch', fetch);
  render(<ConsultationInbox />);
  expect(await screen.findByText(request.phone)).toBeTruthy();
  expect(fetch.mock.calls[0][0]).toContain('/api/v1/consultation-requests?page=1&pageSize=20');
  await userEvent.click(screen.getByRole('button', { name: 'Xem yêu cầu' }));
  expect(screen.getByText(request.note)).toBeTruthy();
  expect(screen.getByText(request.id)).toBeTruthy();
});

it('keeps an access or network failure visible and allows retry', async () => {
  vi.stubGlobal(
    'fetch',
    vi
      .fn()
      .mockResolvedValueOnce(
        Response.json({ message: 'Không có quyền đọc yêu cầu.' }, { status: 403 }),
      )
      .mockResolvedValueOnce(Response.json({ items: [], total: 0, page: 1, pageSize: 20 })),
  );
  render(<ConsultationInbox />);
  expect(await screen.findByText('Không có quyền đọc yêu cầu.')).toBeTruthy();
  expect(screen.queryByText('Chưa có yêu cầu tư vấn')).toBeNull();
  await userEvent.click(screen.getByRole('button', { name: /Thử lại/ }));
  expect(await screen.findByText('Chưa có yêu cầu tư vấn')).toBeTruthy();
});
