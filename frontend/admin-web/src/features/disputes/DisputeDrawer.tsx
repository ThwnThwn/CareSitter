import { Gavel, XCircle } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../../adminMetadata';
import { DetailList, Drawer, ErrorBanner, LoadingTable, StatusChip, formatDate, formatMoney, shortId } from '../../components/Common';
import { Dispute } from '../../types';
import { useDisputeReview } from './useDisputeReview';

export function DisputeDrawer({ dispute: selected, onClose, onChanged }: { dispute: Dispute; onClose: () => void; onChanged: () => void }) {
  const { disputeDecisions } = useAdminMetadata();
  const { dispute, booking, decision, chooseDecision, refundAmount, setRefundAmount, penaltyAmount, setPenaltyAmount,
    busy, error, loading, loadError, actionable, allocation, validation, reloadDetails,
    resolve: submitResolution, cancel: submitCancellation } = useDisputeReview(selected, onChanged);
  async function resolve() {
    if (!allocation) return;
    await submitResolution(() => window.confirm(`Xác nhận phán quyết ${optionLabel(disputeDecisions, decision)}?\nHoàn khách: ${formatMoney(allocation.refund)}\nPhí nền tảng: ${formatMoney(allocation.fee)}\nChế tài: ${formatMoney(allocation.penalty)}\nCaregiver nhận: ${formatMoney(allocation.earning)}`));
  }
  async function cancel() { await submitCancellation(() => window.confirm('Hủy hồ sơ khiếu nại này? Thao tác hiện tại chỉ đóng hồ sơ, không tự hoàn tiền hoặc khôi phục trạng thái booking.')); }
  return <Drawer title={dispute.reason || 'Khiếu nại booking'} subtitle={shortId(dispute.id)} busy={!!busy} onClose={onClose}
    footer={actionable && <><button className="danger" disabled={!!busy} onClick={() => void cancel()}><XCircle size={17} /> {busy === 'cancel' ? 'Đang hủy…' : 'Hủy khiếu nại'}</button>
      <button className="primary" disabled={!!busy || !allocation || booking?.status !== 'disputed'} onClick={() => void resolve()}><Gavel size={17} /> {busy === 'resolve' ? 'Đang ghi nhận…' : 'Ghi nhận phán quyết'}</button></>}>
    {error && <ErrorBanner message={error} />}
    {loadError && <ErrorBanner message={loadError} onRetry={reloadDetails} />}
    {loading ? <LoadingTable rows={5} columns={2} /> : loadError ? null : <>
      <div className="drawer-status"><StatusChip value={dispute.status} /><span>Mở {formatDate(dispute.openedAt)}</span></div>
      <DetailList items={[{ label: 'Booking', value: dispute.bookingId }, { label: 'Người gửi', value: dispute.raisedByUserId }, { label: 'Mô tả', value: dispute.description },
        { label: 'Quyết định', value: optionLabel(disputeDecisions, dispute.decision) }, { label: 'Hoàn tiền đã ghi nhận', value: dispute.refundAmount == null ? '—' : formatMoney(dispute.refundAmount) },
        { label: 'Tiền giữ chờ của booking', value: formatMoney(booking?.escrowAmount) }]} />
      {actionable && <div className="form-stack">
        {booking?.status !== 'disputed' && <ErrorBanner message="Booking không còn ở trạng thái tranh chấp. Hãy kiểm tra sổ giao dịch trước khi xử lý tiếp." />}
        <label>Phán quyết<select disabled={!!busy} value={decision} onChange={(e) => { chooseDecision(e.target.value); }}>
          <option value="">Chọn phán quyết</option>{disputeDecisions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
        {decision === 'PARTIAL_REFUND' && <div className="form-columns">
          <label>Số tiền hoàn (VND)<input type="number" min="1" step="1" disabled={!!busy} max={(booking?.escrowAmount || 0) - 1} value={refundAmount} onChange={(e) => setRefundAmount(Number(e.target.value))} /></label>
          <label>Chế tài caregiver (VND)<input type="number" min="0" step="1" disabled={!!busy} value={penaltyAmount} onChange={(e) => setPenaltyAmount(Number(e.target.value))} /></label>
        </div>}
        {decision === 'CUSTOMER_WINS' && <p>Hoàn toàn bộ tiền giữ chờ cho khách; không khấu trừ thêm vào ví caregiver.</p>}
        {decision === 'CAREGIVER_WINS' && <p>Không hoàn tiền; caregiver nhận phần còn lại sau phí nền tảng.</p>}
        {validation && <ErrorBanner message={validation} />}
        {allocation && <section aria-label="Phân bổ tiền dự kiến" aria-live="polite"><h3>Phân bổ tiền dự kiến</h3><DetailList items={[
          { label: 'Hoàn cho khách', value: formatMoney(allocation.refund) }, { label: 'Phí nền tảng', value: formatMoney(allocation.fee) },
          { label: 'Chế tài', value: formatMoney(allocation.penalty) }, { label: 'Caregiver nhận', value: formatMoney(allocation.earning) },
        ]} /></section>}
      </div>}
    </>}
  </Drawer>;
}
