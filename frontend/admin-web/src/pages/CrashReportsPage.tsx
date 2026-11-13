import { useState } from 'react';
import { AlertCircle, CheckCircle2, ExternalLink, RefreshCw } from 'lucide-react';
import { EmptyState, ErrorBanner, LoadingTable, PageHeader, formatDate } from '../components/Common';
import { useResource } from '../useResource';
import type { CrashReportPage } from '../types';

const empty: CrashReportPage = { sourceStatus: 'not_configured', exportMode: 'batch', queriedAt: '',
  windowEnd: '', days: 7, page: 1, pageSize: 20, hasMore: false, items: [] };

const ERROR_TYPE_TONE: Record<string, string> = {
  FATAL: 'danger',
  NON_FATAL: 'warning',
  ANR: 'warning',
};

function CrashTypeBadge({ type }: { type: string }) {
  return <span className={`status-chip ${ERROR_TYPE_TONE[type] ?? 'neutral'}`}>{type}</span>;
}

function BigQueryChecklist({ title, summary }: { title: string; summary: string }) {
  return (
    <div className="notice" role="status" style={{ flexDirection: 'column', gap: '0.85rem', background: '#fff' }}>
      <div style={{ display: 'flex', gap: '0.7rem', alignItems: 'flex-start' }}>
        <AlertCircle size={19} style={{ color: 'var(--amber)', flexShrink: 0, marginTop: 2 }} aria-hidden="true" />
        <div>
          <strong>{title}</strong>
          <p>{summary}</p>
        </div>
      </div>
      <ol style={{ margin: '0 0 0 1.35rem', padding: 0, lineHeight: 1.75 }}>
        <li>
          Vào{' '}
          <a href="https://console.firebase.google.com" target="_blank" rel="noopener noreferrer">
            Firebase Console
          </a>{' '}
          → Project Settings / Crashlytics → bật <b>BigQuery export</b> (batch cho bản Customer).
        </li>
        <li>Tạo báo cáo crash thật trên thiết bị và mở lại app để Firebase tạo dataset <code>firebase_crashlytics</code> (lần đầu có thể mất 24–48 giờ).</li>
        <li>Trong Google Cloud IAM, cấp quyền <b>BigQuery Job User</b> (trên project) và <b>BigQuery Data Viewer</b> (trên dataset) cho service account backend.</li>
        <li>Kiểm tra <code>backend/.env</code>: <code>CrashReports__Enabled=true</code>, đúng <code>CrashReports__Table</code> (<code>vn_caresitter_customer_IOS</code> hoặc <code>_ANDROID</code>) và <code>CrashReports__Location</code>, sau đó khởi động lại API.</li>
      </ol>
      <div className="button-row">
        <a href="https://console.firebase.google.com" target="_blank" rel="noopener noreferrer"
          className="secondary" style={{ textDecoration: 'none' }}>
          <ExternalLink size={14} aria-hidden="true" /> Mở Firebase Console
        </a>
        <a href="https://console.cloud.google.com/bigquery" target="_blank" rel="noopener noreferrer"
          className="secondary" style={{ textDecoration: 'none' }}>
          <ExternalLink size={14} aria-hidden="true" /> Mở BigQuery Console
        </a>
      </div>
    </div>
  );
}

export function CrashReportsPage() {
  const [filter, setFilter] = useState(() => ({ until: new Date().toISOString(), errorType: '', page: 1 }));
  const query = new URLSearchParams({ until: filter.until, days: '7', page: String(filter.page), pageSize: '20' });
  if (filter.errorType) query.set('errorType', filter.errorType);
  const reports = useResource<CrashReportPage>(`/api/v1/admin/crash-reports?${query}`, empty);
  const data = reports.data;
  const notConfigured = !reports.loading && !reports.error && data.sourceStatus === 'not_configured';
  const refresh = () => setFilter((previous) => ({ ...previous, page: 1, until: new Date().toISOString() }));

  return (
    <section>
      <PageHeader
        title="Lỗi ứng dụng"
        description="Báo cáo Crashlytics thực tế từ Firebase BigQuery export."
        actions={
          <button className="secondary" onClick={refresh} disabled={reports.loading || notConfigured}>
            <RefreshCw size={15} aria-hidden="true" /> Cập nhật dữ liệu
          </button>
        }
      />

      {!notConfigured && (
        <div className="filter-bar">
          <label>
            Loại lỗi
            <select
              value={filter.errorType}
              onChange={(event) => setFilter((previous) => ({ ...previous, errorType: event.target.value, page: 1 }))}
            >
              <option value="">Tất cả</option>
              <option value="FATAL">Fatal</option>
              <option value="NON_FATAL">Nonfatal</option>
              <option value="ANR">ANR</option>
            </select>
          </label>
          <span className="data-timestamp">Khoảng thời gian: 7 ngày · 20 báo cáo mỗi trang</span>
        </div>
      )}

      {reports.error && (
        <>
          <ErrorBanner message={reports.error} onRetry={() => void reports.reload()} />
          <BigQueryChecklist
            title="Chưa đọc được dữ liệu từ Firebase BigQuery export"
            summary="Backend đã gọi BigQuery nhưng chưa lấy được bảng export. Nếu đã bật BigQuery export trong .env, hãy rà lại các điều kiện sau:"
          />
        </>
      )}

      {reports.loading ? (
        <div className="data-panel"><LoadingTable columns={5} /></div>
      ) : reports.error ? null : notConfigured ? (
        <BigQueryChecklist
          title="Nguồn báo cáo chưa được cấu hình"
          summary="Cần bật Crashlytics export trên Firebase và cấu hình backend đọc từ BigQuery. Chưa thể kết luận ứng dụng không có lỗi."
        />
      ) : (
        <>
          <div className="notice" role="status" style={{ background: '#fff' }}>
            <CheckCircle2 size={18} style={{ color: 'var(--green)', flexShrink: 0, marginTop: 1 }} aria-hidden="true" />
            <div>
              <strong>Nguồn Firebase Crashlytics · {data.exportMode === 'streaming' ? 'Streaming' : 'Batch hằng ngày'}</strong>
              <p>Truy vấn lúc {formatDate(data.queriedAt)}. Cửa sổ kết thúc {formatDate(data.windowEnd)}.</p>
              <p>
                {data.exportMode === 'streaming'
                  ? 'Dữ liệu có độ trễ từ lúc ứng dụng gửi và Firebase export.'
                  : 'Batch cập nhật hằng ngày; lần xuất đầu có thể mất tới 48 giờ.'}
              </p>
            </div>
          </div>

          <div className="data-panel">
            {data.items.length === 0 ? (
              <EmptyState
                title="Chưa có báo cáo trong cửa sổ này"
                description="Nguồn đã đọc được. Thực hiện crash demo trên thiết bị, mở lại app rồi chờ chu kỳ export trước khi kết luận."
              />
            ) : (
              <div className="table-wrap">
                <table className="data-table">
                  <caption className="sr-only">Báo cáo Crashlytics đã xuất từ Firebase</caption>
                  <thead>
                    <tr>
                      <th>Thời điểm</th>
                      <th>Loại</th>
                      <th>App / build</th>
                      <th>Màn hình</th>
                      <th>Đối chiếu</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.map((item) => (
                      <tr key={item.eventId}>
                        <td style={{ whiteSpace: 'nowrap' }}>{formatDate(item.occurredAt)}</td>
                        <td><CrashTypeBadge type={item.errorType} /></td>
                        <td>
                          <span className="status-chip info">{item.platform}</span>{' '}
                          <span style={{ color: 'var(--muted)' }}>
                            {item.appVersion} ({item.buildVersion})
                          </span>
                        </td>
                        <td><code className="mono">{item.screen || '—'}</code></td>
                        <td>
                          <details>
                            <summary style={{ cursor: 'pointer' }}>Mã báo cáo</summary>
                            <p>Issue: <code className="mono">{item.issueId}</code></p>
                            <p>Event: <code className="mono">{item.eventId}</code></p>
                            {item.demoRunId && <p>Lần thử: <code className="mono">{item.demoRunId}</code></p>}
                          </details>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            <div className="pagination" aria-label="Phân trang báo cáo">
              <span>Trang {data.page}</span>
              <div>
                <button
                  className="secondary"
                  disabled={filter.page <= 1}
                  onClick={() => setFilter((previous) => ({ ...previous, page: previous.page - 1 }))}
                >
                  Trang trước
                </button>
                <button
                  className="secondary"
                  disabled={!data.hasMore || filter.page >= 100}
                  onClick={() => setFilter((previous) => ({ ...previous, page: previous.page + 1 }))}
                >
                  Trang sau
                </button>
              </div>
            </div>
          </div>
        </>
      )}
    </section>
  );
}
