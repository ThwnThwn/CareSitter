import { ErrorBanner } from '../../components/Common';
import type { PromotionForm } from '../../promotionForm';
import type { PromotionEditorState } from './usePromotionEditor';
import { NumberField } from './NumberField';

export function PromotionFormFields({
  formId,
  editor,
}: {
  formId: string;
  editor: PromotionEditorState;
}) {
  const {
    form,
    set,
    busy,
    locked,
    services,
    servicesLoading,
    servicesError,
    reloadServices,
    save,
  } = editor;
  return (
    <form id={formId} className="form-stack promotion-form" onSubmit={save}>
      <fieldset disabled={!!busy}>
        <legend>Nội dung hiển thị</legend>
        <div className="form-columns">
          <label>
            Mã ưu đãi
            <input
              required
              pattern="[A-Za-z0-9_-]+"
              maxLength={50}
              disabled={locked}
              value={form.code}
              onChange={(e) => set('code', e.target.value.toUpperCase())}
            />
          </label>
          <label>
            Nhãn ưu đãi
            <input
              required
              maxLength={50}
              value={form.badgeText}
              onChange={(e) => set('badgeText', e.target.value)}
            />
          </label>
        </div>
        <label>
          Tên chiến dịch
          <input
            required
            maxLength={160}
            value={form.title}
            onChange={(e) => set('title', e.target.value)}
          />
        </label>
        <label>
          Tóm tắt
          <textarea
            required
            rows={2}
            maxLength={300}
            value={form.summary}
            onChange={(e) => set('summary', e.target.value)}
          />
        </label>
        <label>
          Mô tả chi tiết
          <textarea
            rows={3}
            maxLength={10000}
            value={form.description}
            onChange={(e) => set('description', e.target.value)}
          />
        </label>
        <label>
          Điều khoản (mỗi dòng một điều kiện)
          <textarea rows={3} value={form.terms} onChange={(e) => set('terms', e.target.value)} />
          <small>Tối đa 20 dòng, mỗi dòng 500 ký tự.</small>
        </label>
      </fieldset>
      <fieldset disabled={!!busy}>
        <legend>Mức giảm và thời gian</legend>
        <div className="form-columns">
          <label>
            Loại giảm
            <select
              disabled={locked}
              value={form.discountType}
              onChange={(e) => set('discountType', e.target.value as PromotionForm['discountType'])}
            >
              <option value="percentage">Theo phần trăm</option>
              <option value="fixed_amount">Số tiền cố định</option>
            </select>
          </label>
          <NumberField
            label={form.discountType === 'percentage' ? 'Mức giảm (%)' : 'Mức giảm (VND)'}
            value={form.discountValue}
            min={1}
            max={form.discountType === 'percentage' ? 100 : Number.MAX_SAFE_INTEGER}
            disabled={locked}
            onChange={(value) => set('discountValue', value)}
          />
        </div>
        <div className="form-columns">
          <NumberField
            label="Giảm tối đa (VND)"
            value={form.maxDiscountAmount}
            min={1}
            optional
            disabled={locked}
            onChange={(value) => set('maxDiscountAmount', value)}
          />
          <NumberField
            label="Đơn tối thiểu (VND)"
            value={form.minOrderAmount}
            disabled={locked}
            onChange={(value) => set('minOrderAmount', value)}
          />
        </div>
        <div className="form-columns">
          <label>
            Bắt đầu
            <input
              type="datetime-local"
              step="any"
              required
              disabled={locked}
              value={form.startsAt}
              onChange={(e) => set('startsAt', e.target.value)}
            />
          </label>
          <label>
            Kết thúc
            <input
              type="datetime-local"
              step="any"
              required
              value={form.endsAt}
              onChange={(e) => set('endsAt', e.target.value)}
            />
          </label>
        </div>
        <p className="form-help">
          Thời gian theo múi giờ thiết bị. Ưu đãi chưa hỗ trợ đơn có số tiền thanh toán bằng 0.
        </p>
      </fieldset>
      <fieldset disabled={!!busy}>
        <legend>Điều kiện và giới hạn lượt</legend>
        <label className="check-label">
          <input
            type="checkbox"
            disabled={locked}
            checked={form.firstPaidBookingOnly}
            onChange={(e) => set('firstPaidBookingOnly', e.target.checked)}
          />{' '}
          Chỉ cho booking thanh toán đầu tiên
        </label>
        <div className="form-columns">
          <NumberField
            label="Tổng lượt sử dụng"
            value={form.totalUsageLimit}
            min={1}
            max={2147483647}
            optional
            onChange={(value) => set('totalUsageLimit', value)}
          />
          <NumberField
            label="Lượt mỗi khách"
            value={form.perCustomerUsageLimit}
            min={1}
            max={2147483647}
            onChange={(value) => set('perCustomerUsageLimit', value)}
          />
        </div>
        <p className="form-help">
          Giới hạn bao gồm lượt đã dùng và lượt đang giữ còn hạn. Để trống tổng lượt nếu không giới
          hạn.
        </p>
        <label className="check-label">
          <input
            type="checkbox"
            disabled={locked || !!servicesError || servicesLoading}
            checked={form.eligibleServiceIds.length === 0}
            onChange={(e) =>
              set(
                'eligibleServiceIds',
                e.target.checked
                  ? []
                  : services.filter((service) => service.isActive).map((service) => service.id),
              )
            }
          />{' '}
          Áp dụng tất cả dịch vụ
        </label>
        {servicesError ? (
          <ErrorBanner message={servicesError} onRetry={() => void reloadServices()} />
        ) : servicesLoading ? (
          <p className="form-help" role="status">
            Đang tải danh mục dịch vụ…
          </p>
        ) : (
          <div className="promotion-scopes" role="group" aria-label="Dịch vụ áp dụng">
            {services.map((service) => (
              <label key={service.id} className="check-label">
                <input
                  type="checkbox"
                  disabled={
                    locked || (!service.isActive && !form.eligibleServiceIds.includes(service.id))
                  }
                  checked={form.eligibleServiceIds.includes(service.id)}
                  onChange={(e) =>
                    set(
                      'eligibleServiceIds',
                      e.target.checked
                        ? [...form.eligibleServiceIds, service.id]
                        : form.eligibleServiceIds.filter((id) => id !== service.id),
                    )
                  }
                />
                {service.name}
                {!service.isActive ? ' (Đã tắt)' : ''}
              </label>
            ))}
            {services.length === 0 && (
              <p className="form-help">Chưa có dịch vụ để giới hạn phạm vi.</p>
            )}
          </div>
        )}
        <p className="form-help">Không chọn dịch vụ cụ thể nghĩa là áp dụng tất cả dịch vụ.</p>
      </fieldset>
      <fieldset disabled={!!busy}>
        <legend>Hiển thị và trạng thái</legend>
        <NumberField
          label="Độ ưu tiên"
          value={form.priority}
          max={2147483647}
          onChange={(value) => set('priority', value)}
        />
        <label className="check-label">
          <input
            type="checkbox"
            checked={form.isFeatured}
            onChange={(e) => set('isFeatured', e.target.checked)}
          />{' '}
          Ưu đãi nổi bật
        </label>
        <label className="check-label">
          <input
            type="checkbox"
            checked={form.isActive}
            onChange={(e) => set('isActive', e.target.checked)}
          />{' '}
          Bật chiến dịch trong thời gian đã cấu hình
        </label>
      </fieldset>
    </form>
  );
}
