import { LockKeyhole, ShieldCheck } from 'lucide-react';
import { useAdminMetadata } from '../../adminMetadata';
import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate } from '../../components/Common';
import { AdminUser } from '../../types';
import { useUserEditor } from './useUserEditor';

export function UserDrawer({ user, onClose, onChanged }: { user: AdminUser; onClose: () => void; onChanged: () => void }) {
  const { roles: roleOptions, userStatuses } = useAdminMetadata();
  const { roles, toggleRole, busy, error, saveRoles: submitRoles, setStatus: submitStatus } = useUserEditor(user, onChanged);
  async function saveRoles() {
    await submitRoles(() => window.confirm(`${roles.includes('ADMIN') ? 'Cấp' : 'Thu hồi'} quyền quản trị cho ${user.email}? Các phiên đăng nhập hiện tại sẽ bị thu hồi.`));
  }
  async function setStatus(status: string) {
    const action = userStatuses.find(option => option.value === status)?.actionLabel?.toLowerCase() || 'cập nhật';
    await submitStatus(status, () => window.confirm(`Xác nhận ${action} tài khoản ${user.email}?`));
  }
  return <Drawer title={user.displayName || user.fullName || user.email} subtitle="Quản lý tài khoản" busy={!!busy} onClose={onClose}>
    <div className="drawer-status"><StatusChip value={user.status} />{user.roles.map((role) => <StatusChip key={role} value={role} />)}</div>{error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Email', value: user.email }, { label: 'Điện thoại', value: user.phone }, { label: 'Mã tài khoản', value: user.id }, { label: 'Ngày tạo', value: formatDate(user.createdAt) }, { label: 'Đăng nhập gần nhất', value: formatDate(user.lastLoginAt) }, { label: 'Bộ phận admin', value: user.adminDepartment }]} />
    <section className="settings-section"><h3>Vai trò</h3><p>Thay đổi vai trò ảnh hưởng đến quyền truy cập ứng dụng tương ứng.</p><div className="role-options">{roleOptions.map((role) => <label key={role.value}><input type="checkbox" disabled={!!busy} checked={roles.includes(role.value)} onChange={() => toggleRole(role.value)} /><span><strong>{role.label}</strong><small>{role.description}</small></span></label>)}</div><button className="primary" disabled={!!busy || JSON.stringify([...roles].sort()) === JSON.stringify([...user.roles].sort())} onClick={() => void saveRoles()}><ShieldCheck size={17} /> {busy === 'roles' ? 'Đang lưu…' : 'Lưu vai trò'}</button></section>
    <section className="settings-section danger-zone"><h3>Trạng thái truy cập</h3><p>Khóa tài khoản sẽ ngăn đăng nhập mới. Hệ thống bảo vệ tài khoản ADMIN cuối cùng.</p><div className="button-row">{userStatuses.filter((status) => status.value !== user.status).map((status) => <button key={status.value} className={status.value === 'LOCKED' ? 'danger' : 'secondary'} disabled={!!busy} onClick={() => void setStatus(status.value)}>{status.value === 'LOCKED' && <LockKeyhole size={17} />}{status.actionLabel || status.label}</button>)}</div></section>
  </Drawer>;
}
