import { useState } from 'react';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { AdminUser } from '../../types';
import { updateUserRoles, updateUserStatus } from './userApi';

export function useUserEditor(user: AdminUser, onChanged: () => void) {
  const [roles, setRoles] = useState(user.roles);
  const mutation = useAdminMutation<'roles' | 'status'>();
  function toggleRole(role: string) { setRoles(current => current.includes(role) ? current.filter(x => x !== role) : [...current, role]); }
  async function saveRoles(confirm: () => boolean) {
    if (mutation.busy) return;
    if (roles.length === 0) { mutation.setError('Tài khoản phải có ít nhất một vai trò.'); return; }
    if (roles.includes('ADMIN') !== user.roles.includes('ADMIN') && !confirm()) return;
    await mutation.run('roles', signal => updateUserRoles(user.id, roles, signal), 'Không thể cập nhật vai trò.', onChanged);
  }
  async function setStatus(status: string, confirm: () => boolean) {
    if (mutation.busy || !confirm()) return;
    await mutation.run('status', signal => updateUserStatus(user.id, status, signal), 'Không thể cập nhật trạng thái tài khoản.', onChanged);
  }
  return { roles, toggleRole, busy: mutation.busy, error: mutation.error, saveRoles, setStatus };
}
