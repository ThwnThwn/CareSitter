import { CalendarCheck, ChevronRight, HandCoins, Headphones, RefreshCw, ShieldCheck, UsersRound } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { useResource } from '../useResource';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, StatusChip, formatDate } from '../components/Common';
import { DashboardData, PageKey } from '../types';

const metricIcons: Record<string, typeof CalendarCheck> = {
  bookingsToday: CalendarCheck,
  pendingKyc: ShieldCheck,
  pendingPayouts: HandCoins,
  openTickets: Headphones,
};

export function DashboardPage({ onNavigate }: { onNavigate: (page: PageKey) => void }) {
  const { dashboard, navigation } = useAdminMetadata();
  const { data, loading, error, reload: load } = useResource<DashboardData | null>('/api/v1/admin/dashboard', null);

  const metrics = data ? dashboard.metricCards.map((card) => ({
    ...card,
    value: data.metrics[card.key],
    icon: metricIcons[card.key] || CalendarCheck,
  })) : [];
  const workTypePages = Object.fromEntries(navigation.flatMap((item) =>
    item.workTypes.map((workType) => [workType, item.key]))) as Record<string, PageKey>;

  return <>
    <PageHeader title="Tổng quan vận hành" description="Các hàng đợi cần quyết định và trạng thái hệ thống trong ngày."
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading && !data ? <LoadingTable rows={4} columns={4} /> : data && <>
      <p className="data-timestamp">Dữ liệu cập nhật lúc {formatDate(data.generatedAt)}{error ? ' · Chưa tải được dữ liệu mới.' : ''}</p>
      <section className="metric-grid" aria-label="Chỉ số vận hành">{metrics.map(({ icon: Icon, ...metric }) => <button
        className="metric-card" key={metric.label} onClick={() => onNavigate(metric.page)}>
        <span className="metric-icon"><Icon size={19} /></span><span>{metric.label}</span>
        <strong>{metric.value}</strong><small>{metric.note}</small>
      </button>)}</section>

      <section className="data-panel">
        <div className="panel-heading"><div><h2>Việc cần xử lý</h2><p>Ưu tiên khẩn cấp, mức cao, sau đó thời điểm chờ lâu nhất.</p></div>
          <div className="operational-summary"><span><UsersRound size={15} /> {data.metrics.activeUsers} tài khoản hoạt động</span><span><CircleDollarSignIcon /> {data.metrics.manualPayments} giao dịch cần đối soát</span></div>
        </div>
        {data.workItems.length === 0 ? <EmptyState title="Không còn hàng đợi" description="Các yêu cầu vận hành hiện đã được xử lý hết." />
          : <div className="table-wrap"><table className="data-table"><thead><tr><th>Loại</th><th>Nội dung</th><th>Trạng thái</th><th>Thời điểm</th><th /></tr></thead>
            <tbody>{data.workItems.map((item) => <tr key={`${item.type}-${item.id}`}>
              <td><StatusChip value={item.type} />{(item.priority === 'CRITICAL' || item.priority === 'HIGH') && <StatusChip value={item.priority} />}</td><td><strong>{item.title}</strong><small>{item.subtitle}</small></td>
              <td><StatusChip value={item.status} /></td><td>{formatDate(item.createdAt)}</td>
              <td>{workTypePages[item.type] && <button className="icon-button subtle" aria-label={`Mở ${item.title}`} onClick={() => onNavigate(workTypePages[item.type])}><ChevronRight size={18} /></button>}</td>
            </tr>)}</tbody></table></div>}
      </section>
    </>}
  </>;
}

function CircleDollarSignIcon() { return <HandCoins size={15} />; }
