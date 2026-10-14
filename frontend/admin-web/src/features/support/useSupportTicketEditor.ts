import { useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { useAdminMutation } from '../../hooks/useAdminMutation';
import { SupportTicket } from '../../types';
import { assignTicket, updateTicketStatus } from './supportTicketApi';

export function useSupportTicketEditor(ticket: SupportTicket, onChanged: () => void) {
  const { transitions } = useAdminMetadata();
  const [status, setStatus] = useState(ticket.status);
  const mutation = useAdminMutation<'assign' | 'status'>();
  const nextStatuses = [ticket.status, ...(transitions.support[ticket.status] || [])];
  async function assign() {
    await mutation.run('assign', signal => assignTicket(ticket.id, signal), 'Không thể nhận xử lý ticket.', onChanged);
  }
  async function updateStatus() {
    if (status === ticket.status || !nextStatuses.includes(status)) return;
    await mutation.run('status', signal => updateTicketStatus(ticket.id, status, signal), 'Không thể cập nhật trạng thái ticket.', onChanged);
  }
  return { status, setStatus, nextStatuses, busy: mutation.busy, error: mutation.error, assign, updateStatus };
}
