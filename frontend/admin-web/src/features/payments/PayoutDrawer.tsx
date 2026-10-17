import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate, formatMoney } from '../../components/Common';
import { Payout } from '../../types';
import { usePayoutReview } from './usePayoutReview';

export function PayoutDrawer({ item, onClose, onChanged }: { item: Payout; onClose: () => void; onChanged: () => void }) {
  const { reason, setReason, busy, error, reviewable, decide: submit } = usePayoutReview(item, onChanged);
  async function decide(approved: boolean) { await submit(approved, () => window.confirm(`Duyệt yêu cầu ${formatMoney(item.amount)} cho ${item.accountHolderName}? Yêu cầu sẽ được đưa vào hàng đợi payOS; hệ thống chỉ ghi nhận đã trả sau khi provider xác nhận thành công.`)); }
  return <Drawer title={formatMoney(item.amount)} subtitle="Yêu cầu rút tiền" busy={!!busy} onClose={onClose}
    footer={reviewable && <><button className="danger" disabled={!!busy} onClick={() => void decide(false)}>Từ chối yêu cầu</button><button className="primary" disabled={!!busy} onClick={() => void decide(true)}>Duyệt yêu cầu</button></>}>
    <div className="drawer-status"><StatusChip value={item.status} /><span>{formatDate(item.requestedAt)}</span></div>{error && <ErrorBanner message={error} />}
    {reviewable && <div className="warning-box"><strong>Duyệt yêu cầu chưa phải xác nhận đã chuyển khoản</strong><p>payOS sẽ xử lý bất đồng bộ. Ledger và số dư chỉ được chốt khi trạng thái provider là thành công.</p></div>}
    <DetailList items={[{ label: 'Người thụ hưởng', value: item.accountHolderName }, { label: 'Ngân hàng', value: `${item.bankName} · BIN ${item.bankBin}` }, { label: 'Số tài khoản', value: <span className="mono copy-value">{item.accountNumber}</span> }, { label: 'Caregiver', value: item.caregiverId }, { label: 'Số tiền', value: formatMoney(item.amount) }, { label: 'Provider', value: item.provider }, { label: 'Mã tham chiếu', value: item.providerReferenceId }, { label: 'Payout ID', value: item.providerPayoutId }, { label: 'Trạng thái provider', value: item.providerState }, { label: 'Mã giao dịch', value: item.providerTransactionId }, { label: 'Lỗi provider', value: item.providerErrorCode }, { label: 'Số lần đối soát', value: item.providerAttemptCount }, { label: 'Hoàn tất', value: item.completedAt ? formatDate(item.completedAt) : undefined }, { label: 'Lý do từ chối', value: item.rejectReason }]} />
    {reviewable && <label>Lý do từ chối<textarea rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Nêu rõ thông tin cần caregiver cập nhật" /></label>}
  </Drawer>;
}
