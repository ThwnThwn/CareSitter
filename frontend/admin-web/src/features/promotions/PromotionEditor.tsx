import { useId } from 'react';
import { TicketPercent, Trash2 } from 'lucide-react';
import { Drawer, ErrorBanner, StatusChip } from '../../components/Common';
import { AdminPromotion } from '../../types';
import { usePromotionEditor } from './usePromotionEditor';
import { PromotionFormFields } from './PromotionFormFields';

export function PromotionEditor({
  promotion,
  onClose,
  onChanged,
  onReload,
}: {
  promotion: AdminPromotion | null;
  onClose: () => void;
  onChanged: (message: string) => void;
  onReload: () => void;
}) {
  const formId = useId();
  const editor = usePromotionEditor(promotion, onChanged);
  const {
    form,
    busy,
    error,
    stale,
    locked,
    confirmDelete,
    setConfirmDelete,
    changeActive,
    remove,
  } = editor;
  return (
    <Drawer
      title={promotion ? promotion.title : 'Tạo chiến dịch'}
      subtitle="Quản lý ưu đãi"
      busy={!!busy}
      onClose={onClose}
      footer={
        <>
          <button className="secondary" disabled={!!busy} onClick={onClose}>
            Đóng
          </button>
          <button className="primary" form={formId} type="submit" disabled={!!busy || stale}>
            {busy === 'save' ? 'Đang lưu…' : promotion ? 'Lưu thay đổi' : 'Tạo chiến dịch'}
          </button>
        </>
      }
    >
      {promotion && (
        <div className="drawer-status">
          <StatusChip value={promotion.status} />
          <span>
            {promotion.redeemedCount} đã dùng · {promotion.reservedCount} đang giữ ·{' '}
            {promotion.releasedCount} đã giải phóng
          </span>
        </div>
      )}
      {error && <ErrorBanner message={error} />}
      {stale && (
        <div className="warning-box">
          <p>Tải bản mới nhất để kiểm tra lại dữ liệu. Bản nháp đang nhập sẽ được thay thế.</p>
          <button className="secondary" disabled={!!busy} onClick={onReload}>
            Tải lại chiến dịch
          </button>
        </div>
      )}
      {locked && (
        <div className="notice">
          Chiến dịch đã có lịch sử. Mã, mức giảm, thời điểm bắt đầu và điều kiện áp dụng được giữ
          nguyên. Bạn vẫn có thể sửa nội dung, thời điểm kết thúc, giới hạn lượt hoặc tắt chiến
          dịch.
        </div>
      )}
      <PromotionFormFields formId={formId} editor={editor} />
      <section className="promotion-preview" aria-label="Xem trước nội dung ưu đãi">
        <h3>
          <TicketPercent size={17} /> Khách hàng sẽ thấy
        </h3>
        <span className="status-chip success">{form.badgeText || 'Nhãn ưu đãi'}</span>
        <h4>{form.title || 'Tên chiến dịch'}</h4>
        <p>{form.summary || 'Tóm tắt nội dung ưu đãi'}</p>
        <span className="mono">{form.code || 'MÃ ƯU ĐÃI'}</span>
        {form.description && <p className="promotion-description">{form.description}</p>}
        {form.terms.trim() && (
          <ul>
            {form.terms
              .split('\n')
              .filter((term) => term.trim())
              .map((term, index) => (
                <li key={index}>{term}</li>
              ))}
          </ul>
        )}
      </section>
      {promotion && (
        <section className="promotion-actions">
          <h3>Vận hành chiến dịch</h3>
          <p className="form-help">
            Bật/tắt dùng cấu hình đã lưu. Lượt giữ hiện có vẫn được redeem hoặc release theo
            booking.
          </p>
          <button
            className="secondary"
            disabled={!!busy || stale}
            onClick={() => void changeActive()}
          >
            {busy === 'active'
              ? 'Đang cập nhật…'
              : promotion.isActive
                ? 'Tắt chiến dịch'
                : 'Bật chiến dịch'}
          </button>
          {promotion.canDelete ? (
            confirmDelete ? (
              <div className="warning-box">
                <p>
                  Xóa vĩnh viễn chiến dịch <strong>{promotion.code}</strong>? Chiến dịch chưa có
                  lịch sử sử dụng.
                </p>
                <div className="button-row">
                  <button
                    className="danger"
                    disabled={!!busy || stale}
                    onClick={() => void remove()}
                  >
                    {busy === 'delete' ? 'Đang xóa…' : `Xác nhận xóa ${promotion.code}`}
                  </button>
                  <button
                    className="secondary"
                    disabled={!!busy}
                    onClick={() => setConfirmDelete(false)}
                  >
                    Hủy xóa
                  </button>
                </div>
              </div>
            ) : (
              <button
                className="danger"
                disabled={!!busy || stale}
                onClick={() => setConfirmDelete(true)}
              >
                <Trash2 size={15} /> Xóa chiến dịch
              </button>
            )
          ) : (
            <p className="form-help">
              Không thể xóa vì đã có lịch sử giữ hoặc sử dụng. Có thể tắt để ngừng nhận lượt mới.
            </p>
          )}
        </section>
      )}
    </Drawer>
  );
}
