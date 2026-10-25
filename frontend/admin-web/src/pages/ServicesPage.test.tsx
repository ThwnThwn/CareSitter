import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { ServicesPage } from './ServicesPage';

vi.mock('../adminMetadata', () => ({ useAdminMetadata: () => ({
  statusDefinitions: {}, defaults: { checklist: { isRequired: true, requiresPhoto: false, firstSortOrder: 1 } },
}) }));

const services = [
  { id: 'a', code: 'A', name: 'Dịch vụ A', isActive: true, allowAdHocTasks: false, pricingRules: [] },
  { id: 'b', code: 'B', name: 'Dịch vụ B', isActive: true, allowAdHocTasks: false, pricingRules: [] },
];
const template = { id: 'template-a', serviceTypeId: 'a', name: 'Công việc của A', isRequired: true, requiresPhoto: false, sortOrder: 1, isActive: true };

it('ends loading and hides the editor when no services exist', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => Response.json([])));
  render(<ServicesPage />);
  await userEvent.click(screen.getByRole('tab', { name: 'Checklist dịch vụ' }));
  expect(await screen.findByText('Chưa có gói dịch vụ')).toBeTruthy();
  expect(screen.queryByLabelText('Đang tải dữ liệu')).toBeNull();
  expect(screen.queryByRole('button', { name: 'Thêm công việc' })).toBeNull();
});

it('shows a recoverable service load failure instead of an endless spinner', async () => {
  let request = 0;
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => {
    request++;
    return request === 2 ? Response.json({ message: 'service offline' }, { status: 500 }) : Response.json([]);
  }));
  render(<ServicesPage />);
  await userEvent.click(screen.getByRole('tab', { name: 'Checklist dịch vụ' }));
  expect(await screen.findByText('Hệ thống đang gặp sự cố. Vui lòng thử lại sau.')).toBeTruthy();
  expect(screen.queryByLabelText('Đang tải dữ liệu')).toBeNull();
  await userEvent.click(screen.getByRole('button', { name: /Thử lại/ }));
  expect(await screen.findByText('Chưa có gói dịch vụ')).toBeTruthy();
});

it('discards another service’s edit identity and draft before creating a checklist item', async () => {
  const fetch = vi.fn().mockImplementation(async (url: string, init: RequestInit) => {
    if (init.method === 'POST') return Response.json({ id: 'new-b' }, { status: 201 });
    if (url.endsWith('/catalog/services')) return Response.json(services);
    return Response.json(url.includes('/services/a/') ? [template] : []);
  });
  vi.stubGlobal('fetch', fetch);
  render(<ServicesPage />);
  await userEvent.click(screen.getByRole('tab', { name: 'Checklist dịch vụ' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Sửa' }));
  expect((screen.getByLabelText('Tên công việc') as HTMLInputElement).value).toBe(template.name);
  await userEvent.click(screen.getByRole('button', { name: /Dịch vụ B/ }));
  await waitFor(() => expect((screen.getByLabelText('Tên công việc') as HTMLInputElement).disabled).toBe(false));
  expect((screen.getByLabelText('Tên công việc') as HTMLInputElement).value).toBe('');
  expect(screen.queryByText('Chỉnh sửa công việc')).toBeNull();
  fireEvent.change(screen.getByLabelText('Tên công việc'), { target: { value: 'Công việc mới B' } });
  await userEvent.click(screen.getByRole('button', { name: 'Thêm công việc' }));
  const mutation = fetch.mock.calls.find(([, init]) => init.method === 'POST');
  expect(mutation?.[0]).toMatch(/\/services\/b\/checklist-templates$/);
  expect(JSON.parse(mutation![1].body)).toMatchObject({ name: 'Công việc mới B' });
});

it('retains a saved checklist policy when navigating away and back', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async (url: string, init: RequestInit) => {
    if (init.method === 'PATCH') return new Response(null, { status: 204 });
    return Response.json(url.endsWith('/catalog/services') ? services : []);
  }));
  render(<ServicesPage />);
  await userEvent.click(screen.getByRole('tab', { name: 'Checklist dịch vụ' }));
  await waitFor(() => expect((screen.getByLabelText('Cho phép việc phát sinh') as HTMLInputElement).disabled).toBe(false));
  await userEvent.click(screen.getByLabelText('Cho phép việc phát sinh'));
  await waitFor(() => expect((screen.getByLabelText('Cho phép việc phát sinh') as HTMLInputElement).checked).toBe(true));
  await userEvent.click(screen.getByRole('button', { name: /Dịch vụ B/ }));
  await userEvent.click(screen.getByRole('button', { name: /Dịch vụ A/ }));
  expect((screen.getByLabelText('Cho phép việc phát sinh') as HTMLInputElement).checked).toBe(true);
});
