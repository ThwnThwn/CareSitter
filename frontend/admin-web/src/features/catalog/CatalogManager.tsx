import { useState } from 'react';
import { Edit3, Plus, RefreshCw } from 'lucide-react';
import {
  EmptyState,
  ErrorBanner,
  LoadingTable,
  StatusChip,
  formatMoney,
} from '../../components/Common';
import { CatalogService } from '../../types';
import { currentPricingRule } from '../../operations';
import { useResource } from '../../useResource';
import { catalogPaths } from './catalogApi';
import { ServiceDrawer } from './ServiceDrawer';

export function CatalogManager() {
  const [selected, setSelected] = useState<CatalogService | 'new' | null>(null);
  const {
    data: services,
    loading,
    error,
    reload: load,
  } = useResource<CatalogService[]>(catalogPaths.services, []);
  return (
    <section className="data-panel tab-panel">
      <div className="panel-heading">
        <div>
          <h2>Gói dịch vụ</h2>
          <p>Chỉ gói đang hoạt động mới xuất hiện trong luồng đặt lịch.</p>
        </div>
        <div className="toolbar">
          <button className="secondary" onClick={() => void load()} disabled={loading}>
            <RefreshCw size={16} /> Làm mới
          </button>
          <button className="primary" onClick={() => setSelected('new')}>
            <Plus size={16} /> Thêm dịch vụ
          </button>
        </div>
      </div>
      {error && <ErrorBanner message={error} onRetry={() => void load()} />}
      {loading ? (
        <LoadingTable rows={5} columns={6} />
      ) : error ? null : services.length === 0 ? (
        <EmptyState
          title="Chưa có gói dịch vụ"
          description="Tạo gói đầu tiên để bắt đầu cấu hình giá và checklist."
        />
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Gói dịch vụ</th>
                <th>Mã</th>
                <th>Thời lượng</th>
                <th>Giá hiện hành</th>
                <th>Phí nền tảng</th>
                <th>Trạng thái</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {services.map((service) => {
                const activePrice = currentPricingRule(service.pricingRules || []);
                const activePlans = (service.plans || []).filter((plan) => plan.isActive);
                const planPrices = activePlans.map((plan) => plan.totalPrice);
                return (
                  <tr key={service.id}>
                    <td>
                      <strong>{service.name}</strong>
                      <small>{service.description || 'Không có mô tả'}</small>
                    </td>
                    <td className="mono">{service.code}</td>
                    <td>{service.defaultDurationMinutes} phút</td>
                    <td>
                      {planPrices.length
                        ? `${formatMoney(Math.min(...planPrices))} – ${formatMoney(Math.max(...planPrices))}`
                        : activePrice
                        ? formatMoney(activePrice.baseHourlyPrice) + '/giờ'
                        : 'Chưa cấu hình'}
                      {!!activePlans.length && <small>{activePlans.length} phương án theo buổi</small>}
                    </td>
                    <td>
                      {activePlans.length
                        ? `${activePlans[0].platformFeePercent}%`
                        : activePrice
                          ? `${activePrice.platformFeePercent}%`
                          : '—'}
                    </td>
                    <td>
                      <StatusChip value={service.isActive ? 'ACTIVE' : 'SUSPENDED'} />
                    </td>
                    <td>
                      <button className="row-action" onClick={() => setSelected(service)}>
                        <Edit3 size={14} /> Chỉnh sửa
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {selected && (
        <ServiceDrawer
          service={selected === 'new' ? null : selected}
          onClose={() => setSelected(null)}
          onChanged={() => {
            setSelected(null);
            void load();
          }}
        />
      )}
    </section>
  );
}
