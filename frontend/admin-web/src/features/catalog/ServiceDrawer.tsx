import { useAdminMetadata } from '../../adminMetadata';
import {
  Drawer,
  EmptyState,
  ErrorBanner,
  StatusChip,
  formatDate,
  formatMoney,
} from '../../components/Common';
import { CatalogService } from '../../types';
import { useServiceEditor } from './useServiceEditor';
import { ServiceImageField } from './ServiceImageField';

export function ServiceDrawer({
  service,
  onClose,
  onChanged,
}: {
  service: CatalogService | null;
  onClose: () => void;
  onChanged: () => void;
}) {
  const { constraints } = useAdminMetadata();
  const {
    form,
    setForm,
    imagePreviewUrl,
    selectImage,
    removeImage,
    priceForm,
    setPriceForm,
    checklistItems,
    addChecklistItem,
    updateChecklistItem,
    removeChecklistItem,
    editingPrice,
    createdServiceId,
    creationProgress,
    busy,
    error,
    editPrice,
    saveService,
    savePrice,
    resetPrice,
  } = useServiceEditor(service, onChanged);
  const pricingFields = (disabled = false) => (
    <>
      <label>
        Tên bảng giá
        <input
          required
          disabled={disabled}
          value={priceForm.name}
          onChange={(e) => setPriceForm({ ...priceForm, name: e.target.value })}
        />
      </label>
      <div className="form-columns">
        <label>
          Giá theo giờ
          <input
            type="number"
            min="0"
            required
            disabled={disabled}
            value={priceForm.baseHourlyPrice}
            onChange={(e) =>
              setPriceForm({ ...priceForm, baseHourlyPrice: Number(e.target.value) })
            }
          />
        </label>
        <label>
          Phí nền tảng (%)
          <input
            type="number"
            min={constraints.platformFeePercent.min}
            max={constraints.platformFeePercent.max}
            step={constraints.platformFeePercent.step}
            disabled={disabled}
            value={priceForm.platformFeePercent}
            onChange={(e) =>
              setPriceForm({ ...priceForm, platformFeePercent: Number(e.target.value) })
            }
          />
        </label>
      </div>
      <div className="form-columns">
        <label>
          Hệ số ban đêm
          <input
            type="number"
            min={constraints.priceMultiplier.min}
            max={constraints.priceMultiplier.max}
            step={constraints.priceMultiplier.step}
            disabled={disabled}
            value={priceForm.nightMultiplier}
            onChange={(e) =>
              setPriceForm({ ...priceForm, nightMultiplier: Number(e.target.value) })
            }
          />
        </label>
        <label>
          Hệ số ngày lễ
          <input
            type="number"
            min={constraints.priceMultiplier.min}
            max={constraints.priceMultiplier.max}
            step={constraints.priceMultiplier.step}
            disabled={disabled}
            value={priceForm.holidayMultiplier}
            onChange={(e) =>
              setPriceForm({ ...priceForm, holidayMultiplier: Number(e.target.value) })
            }
          />
        </label>
      </div>
      <div className="form-columns">
        <label>
          Hiệu lực từ
          <input
            type="datetime-local"
            step="60"
            required
            disabled={disabled}
            value={priceForm.effectiveFrom}
            onChange={(e) => setPriceForm({ ...priceForm, effectiveFrom: e.target.value })}
          />
        </label>
        <label>
          Hiệu lực đến
          <input
            type="datetime-local"
            step="60"
            disabled={disabled}
            value={priceForm.effectiveTo}
            onChange={(e) => setPriceForm({ ...priceForm, effectiveTo: e.target.value })}
          />
        </label>
      </div>
      <p className="form-help">
        Ngày giờ theo múi giờ thiết bị ({Intl.DateTimeFormat().resolvedOptions().timeZone}), chính
        xác đến phút. Có thể để trống ngày kết thúc.
      </p>
      <div className="form-columns">
        <label>
          Thời hạn khiếu nại (giờ)
          <input
            type="number"
            min={constraints.disputeWindowHours.min}
            max={constraints.disputeWindowHours.max}
            disabled={disabled}
            value={priceForm.disputeWindowHours}
            onChange={(e) =>
              setPriceForm({ ...priceForm, disputeWindowHours: Number(e.target.value) })
            }
          />
        </label>
        <label className="check-label">
          <input
            type="checkbox"
            disabled={disabled}
            checked={priceForm.isActive}
            onChange={(e) => setPriceForm({ ...priceForm, isActive: e.target.checked })}
          />{' '}
          Bảng giá hoạt động
        </label>
      </div>
    </>
  );
  return (
    <Drawer
      title={service ? service.name : 'Thêm gói dịch vụ'}
      subtitle="Danh mục dịch vụ"
      busy={!!busy}
      onClose={onClose}
    >
      {error && <ErrorBanner message={error} />}
      <form className="form-stack" onSubmit={saveService}>
        <div className="form-columns">
          <label>
            Mã dịch vụ
            <input
              required
              maxLength={100}
              value={form.code}
              onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
              placeholder="GENKI_AN"
            />
          </label>
          <label>
            Tên dịch vụ
            <input
              required
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </label>
        </div>
        <label>
          Mô tả
          <textarea
            rows={3}
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
        </label>
        <ServiceImageField
          previewUrl={imagePreviewUrl}
          disabled={!!busy}
          onSelect={selectImage}
          onRemove={removeImage}
        />
        <div className="form-columns">
          <label>
            Thời lượng mặc định (phút)
            <input
              type="number"
              min={constraints.serviceDurationMinutes.min}
              max={constraints.serviceDurationMinutes.max}
              value={form.defaultDurationMinutes}
              onChange={(e) => setForm({ ...form, defaultDurationMinutes: Number(e.target.value) })}
            />
          </label>
          <label className="check-label">
            <input
              type="checkbox"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
            />{' '}
            Đang hoạt động
          </label>
        </div>
        {!service && (
          <section className="settings-section" aria-labelledby="initial-pricing-heading">
            <h3 id="initial-pricing-heading">Giá áp dụng ban đầu</h3>
            <p>Nhập bảng giá đầu tiên để dịch vụ có thể được báo giá ngay sau khi tạo.</p>
            <div className="form-stack">{pricingFields(creationProgress.priceSaved)}</div>
          </section>
        )}
        {!service && (
          <section className="settings-section" aria-labelledby="initial-checklist-heading">
            <h3 id="initial-checklist-heading">Checklist cho caregiver</h3>
            <p>
              Caregiver sẽ tick các công việc này trong ca. Cần ít nhất một công việc cho mỗi dịch
              vụ.
            </p>
            <div className="initial-checklist-list">
              {checklistItems.map((item, index) => {
                const saved = index < creationProgress.checklistSavedCount;
                return (
                  <article className="initial-checklist-item" key={item.key}>
                    <span className="order-badge">{index + 1}</span>
                    <div className="initial-checklist-item-body">
                      <div className="initial-checklist-item-head">
                        <strong>Công việc {index + 1}</strong>
                        <div className="tag-row">
                          {saved && <span>Đã lưu</span>}
                          <button
                            type="button"
                            className="row-action danger-text"
                            disabled={!!busy || saved || checklistItems.length === 1}
                            onClick={() => removeChecklistItem(index)}
                          >
                            Xóa
                          </button>
                        </div>
                      </div>
                      <label>
                        Tên công việc
                        <input
                          required
                          minLength={3}
                          maxLength={255}
                          aria-label={`Tên công việc ${index + 1}`}
                          disabled={!!busy || saved}
                          value={item.name}
                          onChange={(event) =>
                            updateChecklistItem(index, { name: event.target.value })
                          }
                        />
                      </label>
                      <label>
                        Mô tả
                        <textarea
                          rows={2}
                          maxLength={1000}
                          aria-label={`Mô tả công việc ${index + 1}`}
                          disabled={!!busy || saved}
                          value={item.description}
                          onChange={(event) =>
                            updateChecklistItem(index, { description: event.target.value })
                          }
                        />
                      </label>
                      <div className="check-group">
                        <label className="check-label">
                          <input
                            type="checkbox"
                            aria-label={`Công việc ${index + 1} bắt buộc`}
                            disabled={!!busy || saved}
                            checked={item.isRequired}
                            onChange={(event) =>
                              updateChecklistItem(index, { isRequired: event.target.checked })
                            }
                          />{' '}
                          Bắt buộc
                        </label>
                        <label className="check-label">
                          <input
                            type="checkbox"
                            aria-label={`Công việc ${index + 1} yêu cầu ảnh`}
                            disabled={!!busy || saved}
                            checked={item.requiresPhoto}
                            onChange={(event) =>
                              updateChecklistItem(index, { requiresPhoto: event.target.checked })
                            }
                          />{' '}
                          Yêu cầu ảnh
                        </label>
                      </div>
                    </div>
                  </article>
                );
              })}
              <button
                type="button"
                className="secondary align-start"
                disabled={!!busy}
                onClick={addChecklistItem}
              >
                Thêm công việc khác
              </button>
            </div>
          </section>
        )}
        <button className="primary align-start" disabled={!!busy}>
          {busy === 'service'
            ? 'Đang lưu…'
            : service
              ? 'Lưu dịch vụ'
              : createdServiceId
                ? creationProgress.priceSaved
                  ? 'Hoàn tất checklist'
                  : 'Hoàn tất giá và checklist'
                : 'Tạo dịch vụ, giá và checklist'}
        </button>
      </form>
      {service && (
        <>
          {!!service.plans?.length && (
            <>
              <hr className="section-divider" />
              <h3 className="subheading">Phương án theo buổi</h3>
              <div className="stack-list compact-list">
                {service.plans.map((plan) => (
                  <article key={plan.id}>
                    <div>
                      <strong>{plan.name}</strong>
                      <p>
                        {formatMoney(plan.totalPrice)} · {plan.durationMinutes} phút/buổi ·{' '}
                        {plan.includedSessions} buổi
                        {plan.validityDays ? ` · dùng trong ${plan.validityDays} ngày` : ''}
                      </p>
                    </div>
                    <StatusChip value={plan.isActive ? 'ACTIVE' : 'SUSPENDED'} />
                  </article>
                ))}
              </div>
            </>
          )}
          <hr className="section-divider" />
          <h3 className="subheading">Bảng giá</h3>
          {service.pricingRules?.length ? (
            <div className="stack-list compact-list">
              {service.pricingRules.map((rule) => (
                <article key={rule.id}>
                  <div>
                    <strong>{rule.name}</strong>
                    <p>
                      {formatMoney(rule.baseHourlyPrice)}/giờ · phí {rule.platformFeePercent}% · từ{' '}
                      {formatDate(rule.effectiveFrom, false)}
                    </p>
                  </div>
                  <div>
                    <StatusChip value={rule.isActive ? 'ACTIVE' : 'SUSPENDED'} />
                    <button
                      className="row-action"
                      disabled={!!busy}
                      onClick={() => editPrice(rule)}
                    >
                      Sửa
                    </button>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState
              title="Chưa có bảng giá"
              description="Tạo bảng giá để hệ thống có thể báo giá booking."
            />
          )}
          <form className="form-stack inset-form" onSubmit={savePrice}>
            <h3>{editingPrice ? 'Chỉnh sửa bảng giá' : 'Thêm bảng giá'}</h3>
            {pricingFields()}
            <div className="button-row">
              <button className="primary" disabled={!!busy}>
                {busy === 'price' ? 'Đang lưu…' : editingPrice ? 'Lưu bảng giá' : 'Thêm bảng giá'}
              </button>
              {editingPrice && (
                <button type="button" className="secondary" disabled={!!busy} onClick={resetPrice}>
                  Hủy sửa
                </button>
              )}
            </div>
          </form>
        </>
      )}
    </Drawer>
  );
}
