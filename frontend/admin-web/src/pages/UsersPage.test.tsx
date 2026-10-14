import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import { UsersPage } from './UsersPage';

vi.mock('../adminMetadata', () => ({
  optionLabel: (options: Array<{ value: string; label: string }>, value: string) =>
    options.find((item) => item.value === value)?.label || value || '—',
  useAdminMetadata: () => ({
    statusDefinitions: {},
    filters: {
      userRoles: { defaultValue: 'ALL', options: [{ value: 'ALL', label: 'Tất cả' }, { value: 'ADMIN', label: 'Quản trị' }] },
      userStatuses: {
        defaultValue: 'ALL',
        options: [
          { value: 'ALL', label: 'Tất cả' },
          { value: 'ACTIVE', label: 'Đang hoạt động', actionLabel: 'Mở khóa' },
          { value: 'LOCKED', label: 'Đã khóa', actionLabel: 'Khóa tài khoản' },
        ],
      },
    },
    roles: [
      { value: 'CUSTOMER', label: 'Khách hàng', description: 'Đặt lịch' },
      { value: 'CAREGIVER', label: 'Caregiver', description: 'Thực hiện ca' },
      { value: 'ADMIN', label: 'Quản trị viên', description: 'Toàn quyền hệ thống' },
    ],
    userStatuses: [
      { value: 'ACTIVE', label: 'Đang hoạt động', actionLabel: 'Mở khóa' },
      { value: 'LOCKED', label: 'Đã khóa', actionLabel: 'Khóa tài khoản' },
    ],
  }),
}));

const mockUser = {
  id: 'user-001',
  email: 'admin@caresitter.vn',
  phone: '0901234567',
  displayName: 'Nguyễn Quản Trị',
  fullName: 'Nguyễn Văn Quản Trị',
  status: 'ACTIVE',
  roles: ['CUSTOMER', 'ADMIN'],
  createdAt: '2026-01-01T00:00:00Z',
  lastLoginAt: '2026-10-10T12:00:00Z',
  adminDepartment: 'Vận hành',
};

function setupFetch(customUser = mockUser) {
  const fetchMock = vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
    if (init?.method === 'PUT') {
      return Response.json({ success: true });
    }
    if (init?.method === 'PATCH') {
      return Response.json({ success: true });
    }
    return Response.json({
      items: [customUser],
      total: 1,
      page: 1,
      pageSize: 20,
    });
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

it('renders user list and opens drawer on "Quản lý"', async () => {
  setupFetch();
  render(<UsersPage />);

  expect(await screen.findByText('Nguyễn Quản Trị')).toBeTruthy();
  expect(screen.getByText('admin@caresitter.vn')).toBeTruthy();

  const manageBtn = screen.getByRole('button', { name: 'Quản lý' });
  await userEvent.click(manageBtn);

  expect(await screen.findByRole('dialog')).toBeTruthy();
  expect(screen.getByText('Mã tài khoản')).toBeTruthy();
});

it('confirms and calls API when revoking ADMIN role', async () => {
  const fetchMock = setupFetch();
  const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

  render(<UsersPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Quản lý' }));

  // Find ADMIN checkbox and uncheck it
  const adminCheckbox = screen.getByLabelText(/Quản trị viên/i);
  expect((adminCheckbox as HTMLInputElement).checked).toBe(true);

  await userEvent.click(adminCheckbox);
  expect((adminCheckbox as HTMLInputElement).checked).toBe(false);

  // Click Save roles
  const saveBtn = screen.getByRole('button', { name: /Lưu vai trò/i });
  await userEvent.click(saveBtn);

  expect(confirmSpy).toHaveBeenCalledWith(
    expect.stringContaining('Thu hồi quyền quản trị cho admin@caresitter.vn')
  );

  await waitFor(() => {
    const putCall = fetchMock.mock.calls.find(([, init]) => init?.method === 'PUT');
    expect(putCall).toBeDefined();
    expect(JSON.parse(putCall![1]!.body as string)).toEqual({ roles: ['CUSTOMER'] });
  });
});

it('confirms and calls API when locking account', async () => {
  const fetchMock = setupFetch();
  const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

  render(<UsersPage />);
  await userEvent.click(await screen.findByRole('button', { name: 'Quản lý' }));

  const lockBtn = await screen.findByRole('button', { name: /Khóa tài khoản/i });
  await userEvent.click(lockBtn);

  expect(confirmSpy).toHaveBeenCalledWith(
    expect.stringMatching(/Xác nhận .* admin@caresitter\.vn\?/)
  );

  await waitFor(() => {
    const patchCall = fetchMock.mock.calls.find(([, init]) => init?.method === 'PATCH');
    expect(patchCall).toBeDefined();
    expect(JSON.parse(patchCall![1]!.body as string)).toEqual({ status: 'LOCKED' });
  });
});
