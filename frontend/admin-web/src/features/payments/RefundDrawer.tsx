import { BadgeCheck } from 'lucide-react';
import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate, formatMoney, shortId } from '../../components/Common';
import { RefundRequest } from '../../types';
import { useRefundConfirmation } from './useRefundConfirmation';

export function RefundDrawer({ item, onClose, onChanged }: { item: RefundRequest; onClose: () => void; onChanged: () => void }) {
  const state = useRefundConfirmation(item, onChanged);
  async function confirm() {
    await state.confirm(() => window.confirm(
      `Xác nhận đã hoàn ${formatMoney(item.amount)} qua ${item.provider} cho booking ${shortId(item.bookingId)}?\n` +
      'Chỉ tiếp tục khi merchant portal hoặc ngân hàng đã xác nhận giao dịch hoàn tiền thành công.'));
  }

  return <Drawer title={formatMoney(item.amount)} subtitle="Refund về phương thức thanh toán gốc" busy={!!state.busy} onClose={onClose}
    footer={state.confirmable && <button className="primary" disabled={!!state.busy} onClick={() => void confirm()}>
      <BadgeCheck size={17} /> {state.busy ? 'Đang xác nhận…' : 'Xác nhận đã hoàn tiền'}
    </button>}>
    <div className="drawer-status"><StatusChip value={item.status} /><span>{formatDate(item.requestedAt)}</span></div>
    {state.error && <ErrorBanner message={state.error} />}
    {state.confirmable && <div className="warning-box"><strong>Không bấm trước khi provider xác nhận hoàn tiền</strong><p>CareSitter không tự chuyển tiền ở bước này. Hãy hoàn qua merchant portal hoặc ngân hàng theo đúng giao dịch gốc, kiểm tra bằng chứng, rồi mới ghi nhận mã refund bên dưới.</p></div>}
    <DetailList items={[
      { label: 'Booking', value: item.bookingId },
      { label: 'Khách hàng', value: item.customerId },
      { label: 'Provider gốc', value: item.provider },
      { label: 'Số tiền', value: `${formatMoney(item.amount)} · ${item.currency}` },
      { label: 'Lý do', value: item.reason },
      { label: 'Request ID', value: item.requestId },
      { label: 'Mã đơn gốc', value: item.originalProviderOrderRef },
      { label: 'Mã giao dịch gốc', value: item.originalProviderTransactionId },
      { label: 'Mã refund provider', value: item.providerRefundId },
      { label: 'Trạng thái provider', value: item.providerTransactionStatus },
      { label: 'Lỗi gần nhất', value: item.lastErrorCode },
      { label: 'Số lần xử lý', value: item.attemptCount },
      { label: 'Lần thử gần nhất', value: item.lastAttemptAt ? formatDate(item.lastAttemptAt) : undefined },
      { label: 'Thử lại lúc', value: item.nextAttemptAt ? formatDate(item.nextAttemptAt) : undefined },
      { label: 'Hoàn tất', value: item.completedAt ? formatDate(item.completedAt) : undefined },
      { label: 'Ghi chú xác nhận', value: item.adminConfirmationNote },
    ]} />
    {state.confirmable && <>
      <label>Mã hoàn tiền từ provider<input aria-label="Mã hoàn tiền từ provider" value={state.providerRefundId} onChange={(e) => state.setProviderRefundId(e.target.value)} placeholder="Ví dụ: mã refund hoặc mã giao dịch ngân hàng" /></label>
      <label>Ghi chú đối soát<textarea aria-label="Ghi chú đối soát refund" rows={4} value={state.confirmationNote} onChange={(e) => state.setConfirmationNote(e.target.value)} placeholder="Nêu nguồn đối chiếu, thời điểm và người kiểm tra" /></label>
    </>}
  </Drawer>;
}
