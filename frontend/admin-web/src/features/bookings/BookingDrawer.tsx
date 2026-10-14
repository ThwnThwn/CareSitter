import { useState } from 'react';
import { CheckCircle2 } from 'lucide-react';
import { DetailList, Drawer, EmptyState, ErrorBanner, LoadingTable, StatusChip, Tabs, formatDate, formatMoney, shortId } from '../../components/Common';
import { Booking } from '../../types';
import { useBookingReview } from './useBookingReview';

export function BookingDrawer({ booking, onClose, onChanged }: { booking: Booking; onClose: () => void; onChanged: () => void }) {
  const { detail, tasks, timeline, loading, loadError, busy, error, reloadDetails, complete: submit } = useBookingReview(booking, onChanged);
  const [tab, setTab] = useState('summary');
  async function complete() { await submit(() => window.confirm('Xác nhận hoàn tất ca này? Tiền giữ chờ chỉ được giải ngân sau thời hạn khiếu nại theo cấu hình của booking.')); }

  return <Drawer title={shortId(detail.id)} subtitle="Chi tiết booking" busy={!!busy} onClose={onClose}
    footer={detail.status === 'checkout_pending_review' && <button className="primary" disabled={busy || loading || !!loadError} onClick={() => void complete()}><CheckCircle2 size={17} /> {busy ? 'Đang hoàn tất…' : 'Xác nhận hoàn tất ca'}</button>}>
    <div className="drawer-status"><StatusChip value={detail.status} /><span>Cập nhật {formatDate(detail.updatedAt)}</span></div>
    {error && <ErrorBanner message={error} />}
    {loadError && <ErrorBanner message={loadError} onRetry={reloadDetails} />}
    <Tabs value={tab} onChange={setTab} items={[{ value: 'summary', label: 'Thông tin' }, { value: 'tasks', label: 'Checklist', count: tasks.length }, { value: 'timeline', label: 'Timeline', count: timeline.length }]} />
    {loading ? <LoadingTable rows={5} columns={2} /> : loadError ? null : tab === 'summary' ? <>
      <DetailList items={[
        { label: 'Dịch vụ', value: detail.serviceName }, { label: 'Người được chăm sóc', value: detail.beneficiaryName },
        { label: 'Caregiver', value: detail.caregiverName || 'Chưa phân công' }, { label: 'Bắt đầu', value: formatDate(detail.scheduledStart) },
        { label: 'Kết thúc', value: formatDate(detail.scheduledEnd) }, { label: 'Địa chỉ', value: detail.addressText },
        { label: 'Bắt đầu thực tế', value: formatDate(detail.actualStart) }, { label: 'Kết thúc thực tế', value: formatDate(detail.actualEnd) },
        { label: 'Escrow', value: formatMoney(detail.escrowAmount) }, { label: 'Thu nhập caregiver', value: formatMoney(detail.caregiverEarningAmount) },
        { label: 'Phí nền tảng', value: formatMoney(detail.platformFeeAmount) }, { label: 'Ghi chú', value: detail.note },
        { label: 'Lý do hủy', value: detail.cancelReason },
      ]} />
    </> : tab === 'tasks' ? (tasks.length === 0 ? <EmptyState title="Chưa có checklist" description="Booking này không có công việc được snapshot." />
      : <div className="stack-list">{tasks.map((task) => <article key={task.id}><div><strong>{task.name}</strong><p>{task.description}</p>
        <div className="tag-row"><span>{task.isRequired ? 'Bắt buộc' : 'Tùy chọn'}</span>{task.requiresPhoto && <span>Yêu cầu ảnh</span>}</div>
        {task.completedAt && <p>Hoàn tất: {formatDate(task.completedAt)}</p>}{task.skipReason && <p>Lý do bỏ qua: {task.skipReason}</p>}
        <div className="attachment-list">{task.photoUrls?.map((url, index) => <a key={url} href={url} target="_blank" rel="noreferrer">Ảnh minh chứng {index + 1}</a>)}</div>
      </div><StatusChip value={task.status} /></article>)}</div>)
      : (timeline.length === 0 ? <EmptyState title="Chưa có sự kiện" description="Timeline sẽ được cập nhật khi ca bắt đầu có hoạt động." />
        : <ol className="timeline-list">{timeline.map((event) => <li key={event.id}><span /><div><strong>{event.title || event.eventType}</strong><p>{event.note || event.source}</p><small>{formatDate(event.recordedAt)}</small></div></li>)}</ol>)}
  </Drawer>;
}
