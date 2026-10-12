import { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import {
  DetailList,
  Drawer,
  EmptyState,
  ErrorBanner,
  LoadingTable,
  PageHeader,
  Pagination,
  formatDate,
  shortId,
} from '../../components/Common';
import type { ConsultationRequest } from '../../types';
import { useConsultationRequests } from './useConsultationRequests';

const serviceLabels: Record<string, string> = {
  elderly_care: 'Chăm sóc người cao tuổi',
  daily_companionship: 'Đồng hành hằng ngày',
  mobility_support: 'Hỗ trợ vận động',
};

function preferredDate(value: string) {
  const parts = value.split('-');
  return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : value;
}

export function ConsultationInbox() {
  const { data, loading, error, reload, setPage } = useConsultationRequests();
  const [selected, setSelected] = useState<ConsultationRequest | null>(null);
  return (
    <>
      <PageHeader
        title="Yêu cầu tư vấn"
        description="Thông tin khách gửi từ landing page để CareSitter liên hệ và xác nhận nhu cầu."
        actions={
          <button className="secondary" disabled={loading} onClick={() => void reload()}>
            <RefreshCw size={16} /> Làm mới
          </button>
        }
      />
      {error && <ErrorBanner message={error} onRetry={() => void reload()} />}
      <section className="data-panel">
        {loading ? (
          <LoadingTable rows={5} columns={5} />
        ) : error ? null : !data.items.length ? (
          <EmptyState
            title="Chưa có yêu cầu tư vấn"
            description="Yêu cầu mới sẽ xuất hiện sau khi khách gửi thông tin."
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Khách hàng</th>
                  <th>Nhu cầu</th>
                  <th>Ngày dự kiến</th>
                  <th>Đã gửi</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {data.items.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <strong>{item.contactName}</strong>
                      <small>{item.phone}</small>
                    </td>
                    <td>
                      {serviceLabels[item.serviceCategory] ?? item.serviceCategory}
                      <small>{item.hours} giờ</small>
                    </td>
                    <td>{preferredDate(item.preferredDate)}</td>
                    <td>{formatDate(item.createdAt)}</td>
                    <td>
                      <button className="row-action" onClick={() => setSelected(item)}>
                        Xem yêu cầu
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!loading && !error && (
          <Pagination
            page={data.page}
            pageSize={data.pageSize}
            total={data.total}
            onChange={setPage}
          />
        )}
      </section>
      {selected && (
        <Drawer
          title={selected.contactName}
          subtitle={`Yêu cầu ${shortId(selected.id)}`}
          onClose={() => setSelected(null)}
        >
          <DetailList
            items={[
              { label: 'Số điện thoại', value: selected.phone },
              {
                label: 'Nhu cầu',
                value: serviceLabels[selected.serviceCategory] ?? selected.serviceCategory,
              },
              { label: 'Ngày dự kiến', value: preferredDate(selected.preferredDate) },
              { label: 'Thời lượng', value: `${selected.hours} giờ` },
              {
                label: 'Người chăm sóc quan tâm',
                value: selected.caregiverPreference || 'Chưa chọn',
              },
              { label: 'Đồng ý liên hệ lúc', value: formatDate(selected.consentAt) },
              { label: 'Mã yêu cầu', value: selected.id },
            ]}
          />
          <section className="prose-block">
            <h3>Ghi chú</h3>
            <p>{selected.note || 'Không có ghi chú.'}</p>
          </section>
        </Drawer>
      )}
    </>
  );
}
