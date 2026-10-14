import { SupportDrawer } from './SupportDrawer';
import { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { optionLabel, useAdminMetadata } from '../../adminMetadata';
import { qs } from '../../api';
import {
  EmptyState,
  ErrorBanner,
  LoadingTable,
  PageHeader,
  Pagination,
  StatusChip,
  formatDate,
  shortId,
} from '../../components/Common';
import { SupportTicket } from '../../types';
import { usePagedResource } from '../../useResource';

export function SupportTickets() {
  const { filters } = useAdminMetadata();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState(filters.tickets.defaultValue);
  const [type, setType] = useState(filters.ticketTypes.defaultValue);
  const [priority, setPriority] = useState(filters.ticketPriorities.defaultValue);
  const [selected, setSelected] = useState<SupportTicket | null>(null);
  const {
    data: result,
    loading,
    error,
    reload: load,
  } = usePagedResource<SupportTicket>(
    `/api/v1/support/tickets${qs({ status, type, priority, page, pageSize: 20 })}`,
    page,
    setPage,
  );

  return (
    <>
      <PageHeader
        title="Hỗ trợ"
        description="Tiếp nhận, phân công và theo dõi yêu cầu hỗ trợ của khách hàng và caregiver."
        actions={
          <button className="secondary" onClick={() => void load()} disabled={loading}>
            <RefreshCw size={16} /> Làm mới
          </button>
        }
      />
      <section className="filter-bar filter-grid">
        <label>
          Trạng thái
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
          >
            {filters.tickets.options.map((option) => (
              <option value={option.value} key={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Loại ticket
          <select
            value={type}
            onChange={(e) => {
              setType(e.target.value);
              setPage(1);
            }}
          >
            {filters.ticketTypes.options.map((option) => (
              <option value={option.value} key={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Độ ưu tiên
          <select
            value={priority}
            onChange={(e) => {
              setPriority(e.target.value);
              setPage(1);
            }}
          >
            {filters.ticketPriorities.options.map((option) => (
              <option value={option.value} key={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
      </section>
      {error && <ErrorBanner message={error} onRetry={() => void load()} />}
      <section className="data-panel">
        {loading ? (
          <LoadingTable rows={7} columns={6} />
        ) : error ? null : result.items.length === 0 ? (
          <EmptyState
            title="Không có ticket phù hợp"
            description="Hãy đổi bộ lọc hoặc kiểm tra lại sau."
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Ticket</th>
                  <th>Loại</th>
                  <th>Ưu tiên</th>
                  <th>Người gửi</th>
                  <th>Cập nhật</th>
                  <th>Trạng thái</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {result.items.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <strong>{item.title}</strong>
                      <small>{shortId(item.id)}</small>
                    </td>
                    <td>{optionLabel(filters.ticketTypes.options, item.type)}</td>
                    <td>
                      <StatusChip value={item.priority} />
                    </td>
                    <td>{shortId(item.userId)}</td>
                    <td>{formatDate(item.updatedAt)}</td>
                    <td>
                      <StatusChip value={item.status} />
                    </td>
                    <td>
                      <button className="row-action" onClick={() => setSelected(item)}>
                        Mở ticket
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
            page={result.page}
            pageSize={result.pageSize}
            total={result.total}
            onChange={setPage}
          />
        )}
      </section>
      {selected && (
        <SupportDrawer
          key={selected.id}
          ticket={selected}
          onClose={() => setSelected(null)}
          onChanged={() => {
            setSelected(null);
            void load();
          }}
        />
      )}
    </>
  );
}
