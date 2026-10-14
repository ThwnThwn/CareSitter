import { ExternalLink, UserCheck } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../../adminMetadata';
import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate, shortId } from '../../components/Common';
import { SupportTicket } from '../../types';
import { useSupportTicketEditor } from './useSupportTicketEditor';

export function SupportDrawer({
  ticket,
  onClose,
  onChanged,
}: {
  ticket: SupportTicket;
  onClose: () => void;
  onChanged: () => void;
}) {
  const { filters, statusDefinitions } = useAdminMetadata();
  const { status, setStatus, busy, error, nextStatuses, assign, updateStatus } = useSupportTicketEditor(ticket, onChanged);
  return (
    <Drawer
      title={ticket.title}
      subtitle={`${optionLabel(filters.ticketTypes.options, ticket.type)} · ${shortId(ticket.id)}`}
      busy={!!busy}
      onClose={onClose}
      footer={
        <>
          <button
            className="secondary"
            disabled={!!busy || !!ticket.assignedAdminId}
            onClick={() => void assign()}
          >
            <UserCheck size={17} />{' '}
            {ticket.assignedAdminId
              ? 'Đã phân công'
              : busy === 'assign'
                ? 'Đang nhận…'
                : 'Nhận xử lý'}
          </button>
          <button
            className="primary"
            disabled={!!busy || status === ticket.status}
            onClick={() => void updateStatus()}
          >
            {busy === 'status' ? 'Đang lưu…' : 'Lưu trạng thái'}
          </button>
        </>
      }
    >
      <div className="drawer-status">
        <StatusChip value={ticket.status} />
        <StatusChip value={ticket.priority} />
        <span>{formatDate(ticket.createdAt)}</span>
      </div>
      {error && <ErrorBanner message={error} />}
      <DetailList
        items={[
          { label: 'Người gửi', value: ticket.userId },
          { label: 'Booking', value: ticket.bookingId },
          { label: 'Admin phụ trách', value: ticket.assignedAdminId || 'Chưa phân công' },
        ]}
      />
      <section className="prose-block">
        <h3>Nội dung yêu cầu</h3>
        <p>{ticket.description}</p>
      </section>
      {ticket.attachmentUrls?.length > 0 && (
        <section>
          <h3 className="subheading">Tệp đính kèm</h3>
          <div className="attachment-list">
            {ticket.attachmentUrls.map((url, index) => (
              <a href={url} target="_blank" rel="noreferrer" key={url}>
                Tệp đính kèm {index + 1}
                <ExternalLink size={14} />
              </a>
            ))}
          </div>
        </section>
      )}
      <label>
        Trạng thái tiếp theo
        <select disabled={!!busy} value={status} onChange={(e) => setStatus(e.target.value)}>
          {nextStatuses.map((value) => (
            <option value={value} key={value}>
              {statusDefinitions[value]?.label || value}
            </option>
          ))}
        </select>
      </label>
    </Drawer>
  );
}
