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
    priceForm,
    setPriceForm,
    editingPrice,
    busy,
    error,
    editPrice,
    saveService,
    savePrice,
    resetPrice,
  } = useServiceEditor(service, onChanged);
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
        <button className="primary align-start" disabled={!!busy}>
          {busy === 'service' ? 'Đang lưu…' : service ? 'Lưu dịch vụ' : 'Tạo dịch vụ'}
        </button>
      </form>
      {service && (
        <>
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
            <label>
              Tên bảng giá
              <input
                required
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
                  value={priceForm.holidayMultiplier}
                  onChange={(e) =>
                    setPriceForm({ ...priceForm, holidayMultiplier: Number(e.target.value) })
                  }
                />
              </label>
            </div>
            <p>
              Thời gian theo múi giờ trình duyệt: {Intl.DateTimeFormat().resolvedOptions().timeZone}
              .
            </p>
            <div className="form-columns">
              <label>
                Hiệu lực từ
                <input
                  type="datetime-local"
                  step="0.001"
                  required
                  value={priceForm.effectiveFrom}
                  onChange={(e) => setPriceForm({ ...priceForm, effectiveFrom: e.target.value })}
                />
              </label>
              <label>
                Hiệu lực đến
                <input
                  type="datetime-local"
                  step="0.001"
                  value={priceForm.effectiveTo}
                  onChange={(e) => setPriceForm({ ...priceForm, effectiveTo: e.target.value })}
                />
              </label>
            </div>
            <div className="form-columns">
              <label>
                Thời hạn khiếu nại (giờ)
                <input
                  type="number"
                  min={constraints.disputeWindowHours.min}
                  max={constraints.disputeWindowHours.max}
                  value={priceForm.disputeWindowHours}
                  onChange={(e) =>
                    setPriceForm({ ...priceForm, disputeWindowHours: Number(e.target.value) })
                  }
                />
              </label>
              <label className="check-label">
                <input
                  type="checkbox"
                  checked={priceForm.isActive}
                  onChange={(e) => setPriceForm({ ...priceForm, isActive: e.target.checked })}
                />{' '}
                Bảng giá hoạt động
              </label>
            </div>
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
