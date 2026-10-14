import { DetailList, Drawer, ErrorBanner, StatusChip, formatDate, formatMoney } from '../../components/Common';
import { Payout } from '../../types';
import { usePayoutReview } from './usePayoutReview';

export function PayoutDrawer({ item, onClose, onChanged }: { item: Payout; onClose: () => void; onChanged: () => void }) {
  const { reason, setReason, busy, error, reviewable, decide: submit } = usePayoutReview(item, onChanged);
  async function decide(approved: boolean) { await submit(approved, () => window.confirm(`Duyệt yêu cầu ${formatMoney(item.amount)} cho ${item.accountHolderName}? Hệ thống ghi sổ rút tiền nhưng chưa tự chuyển khoản ngân hàng.`)); }
  return <Drawer title={formatMoney(item.amount)} subtitle="Yêu cầu rút tiền" busy={!!busy} onClose={onClose}
    footer={reviewable && <><button className="danger" disabled={!!busy} onClick={() => void decide(false)}>Từ chối yêu cầu</button><button className="primary" disabled={!!busy} onClick={() => void decide(true)}>Duyệt yêu cầu</button></>}>
    <div className="drawer-status"><StatusChip value={item.status} /><span>{formatDate(item.requestedAt)}</span></div>{error && <ErrorBanner message={error} />}
    {reviewable && <div className="warning-box"><strong>Duyệt yêu cầu chưa phải xác nhận đã chuyển khoản</strong><p>Thao tác hiện tại ghi sổ rút tiền. Việc chuyển khoản ngân hàng cần thực hiện và đối chiếu theo quy trình vận hành.</p></div>}
    <DetailList items={[{ label: 'Người thụ hưởng', value: item.accountHolderName }, { label: 'Ngân hàng', value: item.bankName }, { label: 'Số tài khoản', value: <span className="mono copy-value">{item.accountNumber}</span> }, { label: 'Caregiver', value: item.caregiverId }, { label: 'Số tiền', value: formatMoney(item.amount) }, { label: 'Lý do từ chối', value: item.rejectReason }]} />
    {reviewable && <label>Lý do từ chối<textarea rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Nêu rõ thông tin cần caregiver cập nhật" /></label>}
  </Drawer>;
}
