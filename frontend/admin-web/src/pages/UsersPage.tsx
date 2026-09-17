import { useCallback, useEffect, useState } from 'react';
import { LockKeyhole, RefreshCw, Search, ShieldCheck } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { api, qs } from '../api';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { AdminUser, Paged } from '../types';

export function UsersPage() {
  const { filters, roles } = useAdminMetadata();
  const [result, setResult] = useState<Paged<AdminUser>>({ items: [], total: 0, page: 1, pageSize: 20 });
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState('');
  const [role, setRole] = useState(filters.userRoles.defaultValue);
  const [status, setStatus] = useState(filters.userStatuses.defaultValue);
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { setResult(await api<Paged<AdminUser>>(`/api/v1/admin/users${qs({ query, role, status, page, pageSize: 20 })}`)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Không tải được tài khoản.'); }
    finally { setLoading(false); }
  }, [page, query, role, status]);
  useEffect(() => { const timer = window.setTimeout(() => void load(), 250); return () => window.clearTimeout(timer); }, [load]);
  useEffect(() => { setPage(1); }, [query, role, status]);

  return <>
    <PageHeader title="Tài khoản" description="Quản lý trạng thái truy cập và vai trò của người dùng CareSitter."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar filter-grid user-filters"><label className="search-field"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tên, email hoặc số điện thoại…" /></label>
      <label>Vai trò<select value={role} onChange={(e) => setRole(e.target.value)}>{filters.userRoles.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
      <label>Trạng thái<select value={status} onChange={(e) => setStatus(e.target.value)}>{filters.userStatuses.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
    </section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">{loading ? <LoadingTable rows={8} columns={6} /> : result.items.length === 0
      ? <EmptyState title="Không tìm thấy tài khoản" description="Thử đổi từ khóa hoặc bộ lọc tài khoản." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Tài khoản</th><th>Liên hệ</th><th>Vai trò</th><th>Đăng nhập gần nhất</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((user) => <tr key={user.id}><td><strong>{user.displayName || user.fullName || 'Chưa cập nhật tên'}</strong><small>{shortId(user.id)}</small></td><td><strong>{user.email}</strong><small>{user.phone || 'Chưa có số điện thoại'}</small></td><td><div className="tag-row">{user.roles.map((item) => <span key={item}>{optionLabel(roles, item)}</span>)}</div></td><td>{formatDate(user.lastLoginAt)}</td><td><StatusChip value={user.status} /></td><td><button className="row-action" onClick={() => setSelected(user)}>Quản lý</button></td></tr>)}</tbody></table></div>}
      <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} /></section>
    {selected && <UserDrawer user={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}

function UserDrawer({ user, onClose, onChanged }: { user: AdminUser; onClose: () => void; onChanged: () => void }) {
  const { roles: roleOptions, userStatuses } = useAdminMetadata();
  const [roles, setRoles] = useState(user.roles);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  function toggleRole(role: string) { setRoles((current) => current.includes(role) ? current.filter((x) => x !== role) : [...current, role]); }
  async function saveRoles() {
    if (roles.length === 0) return setError('Tài khoản phải có ít nhất một vai trò.');
    setBusy('roles'); setError('');
    try { await api(`/api/v1/admin/users/${user.id}/roles`, { method: 'PUT', body: JSON.stringify({ roles }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể cập nhật vai trò.'); }
    finally { setBusy(''); }
  }
  async function setStatus(status: string) {
    const action = userStatuses.find((option) => option.value === status)?.actionLabel?.toLowerCase() || 'cập nhật';
    if (!window.confirm(`Xác nhận ${action} tài khoản ${user.email}?`)) return;
    setBusy('status'); setError('');
    try { await api(`/api/v1/admin/users/${user.id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) }); onChanged(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Không thể cập nhật trạng thái tài khoản.'); }
    finally { setBusy(''); }
  }
  return <Drawer title={user.displayName || user.fullName || user.email} subtitle="Quản lý tài khoản" onClose={onClose}>
    <div className="drawer-status"><StatusChip value={user.status} />{user.roles.map((role) => <StatusChip key={role} value={role} />)}</div>{error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Email', value: user.email }, { label: 'Điện thoại', value: user.phone }, { label: 'Mã tài khoản', value: user.id }, { label: 'Ngày tạo', value: formatDate(user.createdAt) }, { label: 'Đăng nhập gần nhất', value: formatDate(user.lastLoginAt) }, { label: 'Bộ phận admin', value: user.adminDepartment }]} />
    <section className="settings-section"><h3>Vai trò</h3><p>Thay đổi vai trò ảnh hưởng đến quyền truy cập ứng dụng tương ứng.</p><div className="role-options">{roleOptions.map((role) => <label key={role.value}><input type="checkbox" checked={roles.includes(role.value)} onChange={() => toggleRole(role.value)} /><span><strong>{role.label}</strong><small>{role.description}</small></span></label>)}</div><button className="primary" disabled={!!busy || JSON.stringify([...roles].sort()) === JSON.stringify([...user.roles].sort())} onClick={() => void saveRoles()}><ShieldCheck size={17} /> {busy === 'roles' ? 'Đang lưu…' : 'Lưu vai trò'}</button></section>
    <section className="settings-section danger-zone"><h3>Trạng thái truy cập</h3><p>Khóa tài khoản sẽ ngăn đăng nhập mới. Hệ thống bảo vệ tài khoản ADMIN cuối cùng.</p><div className="button-row">{userStatuses.filter((status) => status.value !== user.status).map((status) => <button key={status.value} className={status.value === 'LOCKED' ? 'danger' : 'secondary'} disabled={!!busy} onClick={() => void setStatus(status.value)}>{status.value === 'LOCKED' && <LockKeyhole size={17} />}{status.actionLabel || status.label}</button>)}</div></section>
  </Drawer>;
}
