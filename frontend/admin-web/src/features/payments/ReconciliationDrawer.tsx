import { BadgeCheck, Ban } from 'lucide-react';
import { DetailList, Drawer, ErrorBanner, formatMoney, shortId } from '../../components/Common';
import { PaymentReview } from '../../types';
import { useReconciliationEditor } from './useReconciliationEditor';

export function ReconciliationDrawer({ item, onClose, onChanged }: { item: PaymentReview; onClose: () => void; onChanged: () => void }) {
  const { reason, setReason, transactionId, setTransactionId, busy, error, resolve: submit } = useReconciliationEditor(item, onChanged);
  async function resolve(succeeded: boolean) { await submit(succeeded, () => window.confirm(`${succeeded ? 'Xác nhận đã nhận' : 'Từ chối'} ${formatMoney(item.amount)} cho booking ${shortId(item.bookingId)}?\n${succeeded ? 'Mã giao dịch: ' + transactionId.trim() : 'Booking sẽ bị hủy và slot caregiver được trả lại.'}`)); }
  return <Drawer title={item.canResolve === false ? 'Chi tiết đối soát' : 'Chốt giao dịch'} subtitle="Đối soát thủ công" busy={!!busy} onClose={onClose} footer={item.canResolve !== false && <><button className="danger" disabled={!!busy} onClick={() => void resolve(false)}><Ban size={17} /> {busy === 'reject' ? 'Đang hủy…' : 'Từ chối thanh toán'}</button><button className="primary" disabled={!!busy} onClick={() => void resolve(true)}><BadgeCheck size={17} /> {busy === 'confirm' ? 'Đang xác nhận…' : 'Xác nhận đã thanh toán'}</button></>}>
    {item.canResolve === false
      ? <div className="warning-box"><strong>Cần xử lý khoản tiền với ngân hàng</strong><p>Booking hoặc giao dịch đã đóng, hoặc có tiền chuyển thêm. Hãy đối chiếu sao kê và xử lý hoàn tiền theo quy trình vận hành; không xác nhận lại lịch hẹn.</p></div>
      : <div className="warning-box"><strong>Quyết định ảnh hưởng trực tiếp đến booking</strong><p>Xác nhận sẽ kích hoạt booking và ghi nhận khoản thanh toán; từ chối sẽ hủy booking và trả slot caregiver.</p></div>}
    {error && <ErrorBanner message={error} />}
    <DetailList items={[{ label: 'Booking', value: item.bookingId }, { label: 'Cổng thanh toán', value: item.provider || 'VNPAY' }, { label: 'Trạng thái giao dịch', value: item.intentStatus }, { label: 'Mã đơn thanh toán', value: item.providerOrderRef }, { label: 'Số tiền', value: formatMoney(item.amount) }, { label: 'Lần query', value: item.reconciliationAttempts }, { label: 'Lỗi gần nhất', value: item.lastReconciliationError || item.manualReviewReason }]} />
    <label>Mã giao dịch thanh toán<input disabled={item.canResolve === false} value={transactionId} onChange={(e) => setTransactionId(e.target.value)} placeholder="Nhập từ merchant portal" /></label>
    <label>Ghi chú đối chiếu<textarea disabled={item.canResolve === false} value={reason} onChange={(e) => setReason(e.target.value)} rows={4} placeholder="Ví dụ: Đã đối chiếu merchant portal lúc 15:42" /></label>
  </Drawer>;
}
