import { ArrowUpRight, ChevronRight, RefreshCw } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { useResource } from '../useResource';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, StatusChip, formatDate } from '../components/Common';
import { DashboardData, NavigateAdmin, PageKey } from '../types';

const count = new Intl.NumberFormat('vi-VN');

export function DashboardPage({ onNavigate }: { onNavigate: NavigateAdmin }) {
  const { dashboard, navigation } = useAdminMetadata();
  const { data, loading, error, reload: load } = useResource<DashboardData | null>('/api/v1/admin/dashboard', null);

  const workTypePages = Object.fromEntries(navigation.flatMap((item) =>
    item.workTypes.map((workType) => [workType, item.key]))) as Record<string, PageKey>;

  return <>
    <PageHeader title="Tổng quan vận hành" description={data ? `Cập nhật lúc ${formatDate(data.generatedAt)}${error ? ' · Dữ liệu lần tải trước' : ''}` : undefined}
      actions={<button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={16} /> Làm mới</button>} />
    {error && <ErrorBanner message={error} onRetry={() => void load()} />}
    {loading && !data ? <LoadingTable rows={4} columns={4} /> : data && <>
      <section className="metric-grid" aria-label="Chỉ số vận hành">{dashboard.metricCards.map((metric) =>
        <button className="metric-card" key={metric.key} onClick={() =>
          onNavigate(metric.page, metric.key === 'pendingPayouts' ? { tab: 'payouts' } : undefined)}>
          <span>{metric.label}</span><ArrowUpRight size={16} aria-hidden="true" />
          <strong>{count.format(data.metrics[metric.key])}</strong><small>{metric.note}</small>
        </button>)}</section>

      <section className="data-panel queue-panel">
        <div className="panel-heading"><div><h2>Việc cần xử lý</h2><p>Xếp theo mức ưu tiên, sau đó theo thời gian chờ.</p></div></div>
        {data.workItems.length === 0 ? <EmptyState title="Không còn hàng đợi" description="Các yêu cầu vận hành hiện đã được xử lý hết." />
          : <ul className="work-queue">{data.workItems.map((item) =>
            <li key={`${item.type}-${item.id}`}>
              <div className="work-item">
                <div className="work-meta"><StatusChip value={item.type} />
                  {(item.priority === 'CRITICAL' || item.priority === 'HIGH') && <StatusChip value={item.priority} />}
                </div>
                <strong>{item.title}</strong>{item.subtitle && <small>{item.subtitle}</small>}
              </div>
              <StatusChip value={item.status} />
              <time dateTime={item.createdAt}>{formatDate(item.createdAt)}</time>
              {workTypePages[item.type] && <button className="icon-button subtle" aria-label={`Mở ${item.title}`}
                onClick={() => onNavigate(workTypePages[item.type], item.type === 'PAYOUT' ? { tab: 'payouts' } : undefined)}><ChevronRight size={18} /></button>}
            </li>)}</ul>}
        <footer className="operational-summary">
          <span><b>{count.format(data.metrics.activeUsers)}</b> tài khoản hoạt động</span>
          <span><b>{count.format(data.metrics.manualPayments)}</b> giao dịch cần đối soát</span>
        </footer>
      </section>
    </>}
  </>;
}
