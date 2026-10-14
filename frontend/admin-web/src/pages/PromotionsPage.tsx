import { useState } from 'react';
import { Edit3, Plus, RefreshCw, Search } from 'lucide-react';
import { qs } from '../api';
import {
  EmptyState,
  ErrorBanner,
  LoadingTable,
  PageHeader,
  Pagination,
  StatusChip,
  formatDate,
  formatMoney,
} from '../components/Common';
import { AdminPromotion } from '../types';
import { usePagedResource } from '../useResource';
import { promotionsEndpoint as endpoint } from '../features/promotions/promotionApi';
import { PromotionDrawer } from '../features/promotions/PromotionDrawer';

export function PromotionsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('');
  const [selected, setSelected] = useState<string | null>(null);
  const [notice, setNotice] = useState('');
  const { data, loading, error, reload } = usePagedResource<AdminPromotion>(
    endpoint + qs({ search: query, status, page, pageSize: 20 }),
    page,
    setPage,
  );
  function changed(message: string) {
    setSelected(null);
    setNotice(message);
    void reload();
  }
  return (
    <>
      <PageHeader
        title="Ưu đãi"
        description="Quản lý chiến dịch giảm giá, thời gian áp dụng và lượt sử dụng theo booking."
        actions={
          <button
            className="primary"
            onClick={() => {
              setNotice('');
              setSelected('new');
            }}
          >
            <Plus size={16} /> Tạo chiến dịch
          </button>
        }
      />
      {notice && (
        <div className="notice" role="status">
          {notice}
        </div>
      )}
      <form
        className="filter-bar"
        onSubmit={(event) => {
          event.preventDefault();
          setQuery(search.trim());
          setPage(1);
        }}
      >
        <label className="search-field">
          <Search size={17} aria-hidden="true" />
          <input
            aria-label="Tìm mã hoặc tên chiến dịch"
            maxLength={160}
            placeholder="Mã hoặc tên chiến dịch"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>
        <label>
          Trạng thái
          <select
            value={status}
            onChange={(event) => {
              setStatus(event.target.value);
              setPage(1);
            }}
          >
            <option value="">Tất cả trạng thái</option>
            <option value="ACTIVE">Đang hiệu lực</option>
            <option value="SCHEDULED">Sắp diễn ra</option>
            <option value="EXPIRED">Đã hết hạn</option>
            <option value="INACTIVE">Đã tắt</option>
          </select>
        </label>
        <button className="secondary" type="submit">
          Tìm kiếm
        </button>
        <button
          className="secondary"
          type="button"
          disabled={loading}
          onClick={() => void reload()}
        >
          <RefreshCw size={16} /> Làm mới
        </button>
      </form>
      {error && <ErrorBanner message={error} onRetry={() => void reload()} />}
      <section className="data-panel">
        <div className="panel-heading">
          <div>
            <h2>Chiến dịch ưu đãi</h2>
            <p>Lượt đang giữ còn hạn được tính vào giới hạn sử dụng.</p>
          </div>
          <span className="data-timestamp">
            {loading ? 'Đang tải…' : `${data.total} chiến dịch`}
          </span>
        </div>
        {loading ? (
          <LoadingTable rows={5} columns={6} />
        ) : error ? null : data.items.length === 0 ? (
          <EmptyState
            title={query || status ? 'Không tìm thấy chiến dịch' : 'Chưa có chiến dịch ưu đãi'}
            description={
              query || status
                ? 'Đổi từ khóa hoặc chọn tất cả trạng thái để tìm lại.'
                : 'Tạo chiến dịch đầu tiên, kiểm tra điều kiện rồi bật khi sẵn sàng.'
            }
          />
        ) : (
          <div className="table-wrap">
            <table className="data-table promotion-table">
              <thead>
                <tr>
                  <th>Chiến dịch</th>
                  <th>Mức giảm</th>
                  <th>Thời gian</th>
                  <th>Lượt sử dụng</th>
                  <th>Trạng thái</th>
                  <th>Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((promotion) => (
                  <tr key={promotion.id}>
                    <td>
                      <strong>
                        <button
                          className="promotion-title"
                          aria-label={`Mở chiến dịch ${promotion.code}`}
                          onClick={() => {
                            setNotice('');
                            setSelected(promotion.id);
                          }}
                        >
                          {promotion.title}
                        </button>
                      </strong>
                      <small className="mono">
                        {promotion.code}
                        {promotion.isFeatured ? ' · Nổi bật' : ''}
                      </small>
                      <small>{promotion.summary}</small>
                    </td>
                    <td>
                      {promotion.discountType === 'percentage'
                        ? `${promotion.discountValue}%`
                        : formatMoney(promotion.discountValue)}
                      {promotion.maxDiscountAmount && (
                        <small>Tối đa {formatMoney(promotion.maxDiscountAmount)}</small>
                      )}
                      <small>Đơn từ {formatMoney(promotion.minOrderAmount)}</small>
                    </td>
                    <td>
                      {formatDate(promotion.startsAt)}
                      <small>đến {formatDate(promotion.endsAt)}</small>
                    </td>
                    <td>
                      <strong>
                        {promotion.redeemedCount} đã dùng · {promotion.reservedCount} đang giữ
                      </strong>
                      <small>
                        Tổng giới hạn: {promotion.totalUsageLimit ?? 'Không giới hạn'} ·{' '}
                        {promotion.perCustomerUsageLimit} lượt/khách
                      </small>
                    </td>
                    <td>
                      <StatusChip value={promotion.status} />
                    </td>
                    <td>
                      <button
                        className="row-action"
                        aria-label={`Xem và sửa ${promotion.code}`}
                        onClick={() => {
                          setNotice('');
                          setSelected(promotion.id);
                        }}
                      >
                        <Edit3 size={14} /> Chi tiết
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!loading && !error && (
          <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={setPage} />
        )}
      </section>
      {selected && (
        <PromotionDrawer
          id={selected === 'new' ? null : selected}
          onClose={() => setSelected(null)}
          onChanged={changed}
        />
      )}
    </>
  );
}
