import { api } from '../../api';

export function updateUserRoles(id: string, roles: string[], signal: AbortSignal) {
  return api<void>(`/api/v1/admin/users/${id}/roles`, { method: 'PUT', body: JSON.stringify({ roles }), signal });
}
export function updateUserStatus(id: string, status: string, signal: AbortSignal) {
  return api<void>(`/api/v1/admin/users/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status }), signal });
}
