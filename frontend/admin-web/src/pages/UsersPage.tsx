import { UserDrawer } from '../features/users/UserDrawer';
import { useEffect, useState } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../adminMetadata';
import { qs } from '../api';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, Pagination, StatusChip, formatDate, shortId } from '../components/Common';
import { AdminUser } from '../types';
import { usePagedResource } from '../useResource';

export function UsersPage() {
  const { filters, roles } = useAdminMetadata();
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState('');
  const [role, setRole] = useState(filters.userRoles.defaultValue);
  const [status, setStatus] = useState(filters.userStatuses.defaultValue);
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [debouncedQuery, setDebouncedQuery] = useState('');
  useEffect(() => {
    const timer = window.setTimeout(() => { setDebouncedQuery(query); setPage(1); }, 250);
    return () => window.clearTimeout(timer);
  }, [query]);
  const { data: result, loading: fetching, error, reload: load } = usePagedResource<AdminUser>(`/api/v1/admin/users${qs({ query: debouncedQuery, role, status, page, pageSize: 20 })}`, page, setPage);
  const loading = fetching || query !== debouncedQuery;

  return <>
    <PageHeader title="Tài khoản" description="Quản lý trạng thái truy cập và vai trò của người dùng CareSitter."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    <section className="filter-bar filter-grid user-filters"><label className="search-field"><Search size={17} /><input aria-label="Tìm tài khoản" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tên, email hoặc số điện thoại…" /></label>
      <label>Vai trò<select value={role} onChange={(e) => { setRole(e.target.value); setPage(1); }}>{filters.userRoles.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
      <label>Trạng thái<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>{filters.userStatuses.options.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
    </section>
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    <section className="data-panel">{loading ? <LoadingTable rows={8} columns={6} /> : error ? null : result.items.length === 0
      ? <EmptyState title="Không tìm thấy tài khoản" description="Thử đổi từ khóa hoặc bộ lọc tài khoản." />
      : <div className="table-wrap"><table className="data-table"><thead><tr><th>Tài khoản</th><th>Liên hệ</th><th>Vai trò</th><th>Đăng nhập gần nhất</th><th>Trạng thái</th><th /></tr></thead><tbody>
        {result.items.map((user) => <tr key={user.id}><td><strong>{user.displayName || user.fullName || 'Chưa cập nhật tên'}</strong><small>{shortId(user.id)}</small></td><td><strong>{user.email}</strong><small>{user.phone || 'Chưa có số điện thoại'}</small></td><td><div className="tag-row">{user.roles.map((item) => <span key={item}>{optionLabel(roles, item)}</span>)}</div></td><td>{formatDate(user.lastLoginAt)}</td><td><StatusChip value={user.status} /></td><td><button className="row-action" onClick={() => setSelected(user)}>Quản lý</button></td></tr>)}</tbody></table></div>}
      {!loading && !error && <Pagination page={result.page} pageSize={result.pageSize} total={result.total} onChange={setPage} />}</section>
    {selected && <UserDrawer key={selected.id} user={selected} onClose={() => setSelected(null)} onChanged={() => { setSelected(null); void load(); }} />}
  </>;
}
