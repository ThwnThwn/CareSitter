import { ReactNode, useEffect, useId, useRef } from 'react';
import { AlertCircle, Inbox, LoaderCircle, RefreshCw, X } from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
// Utility functions sống trong utils/format.ts — re-export ở đây để backward-compatible
export { formatMoney, formatDate, shortId } from '../utils/format';

export function StatusChip({ value }: { value?: string }) {
  const { statusDefinitions } = useAdminMetadata();
  const normalized = value || 'UNKNOWN';
  const definition = statusDefinitions[normalized]
    || statusDefinitions[normalized.toUpperCase()]
    || statusDefinitions[normalized.toLowerCase()];
  return <span className={`status-chip ${definition?.tone || 'neutral'}`}>
    {definition?.label || normalized.replaceAll('_', ' ')}
  </span>;
}

export function PageHeader({ title, description, actions }: { title: string; description?: string; actions?: ReactNode }) {
  return <header className="page-header">
    <div><h1>{title}</h1>{description && <p>{description}</p>}</div>
    {actions && <div className="page-actions">{actions}</div>}
  </header>;
}

export function ErrorBanner({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return <div className="notice error-notice" role="alert">
    <AlertCircle size={18} aria-hidden="true" />
    <div><strong>Không thể hoàn tất yêu cầu</strong><p>{message}</p></div>
    {onRetry && <button className="text-button" onClick={onRetry}><RefreshCw size={15} /> Thử lại</button>}
  </div>;
}

export function EmptyState({ title, description }: { title: string; description: string }) {
  return <div className="empty-state">
    <span className="empty-symbol"><Inbox size={24} /></span>
    <strong>{title}</strong><p>{description}</p>
  </div>;
}

export function LoadingTable({ rows = 6, columns = 5 }: { rows?: number; columns?: number }) {
  return <div className="skeleton-table" aria-label="Đang tải dữ liệu" aria-busy="true">
    {Array.from({ length: rows }).map((_, row) => <div className="skeleton-row" key={row}>
      {Array.from({ length: columns }).map((__, column) => <span key={column} />)}
    </div>)}
  </div>;
}

export function InlineLoading({ label = 'Đang xử lý…' }: { label?: string }) {
  return <span className="inline-loading"><LoaderCircle size={16} className="spin" />{label}</span>;
}

export function Pagination({ page, pageSize, total, onChange }: { page: number; pageSize: number; total: number; onChange: (page: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  if (total <= pageSize && page <= 1) return null;
  return <div className="pagination" aria-label="Phân trang">
    <span>{page > pages ? 'Trang hiện tại không còn dữ liệu.' : `Hiển thị ${total ? (page - 1) * pageSize + 1 : 0}–${Math.min(page * pageSize, total)} trong ${total}`}</span>
    <div>
      <button className="icon-page" disabled={page <= 1} onClick={() => onChange(page - 1)} aria-label="Trang trước">‹</button>
      <span>Trang {page}/{pages}</span>
      <button className="icon-page" disabled={page >= pages} onClick={() => onChange(page + 1)} aria-label="Trang sau">›</button>
    </div>
  </div>;
}

export function Drawer({ title, subtitle, onClose, children, footer, busy = false }: {
  title: string; subtitle?: string; onClose: () => void; children: ReactNode; footer?: ReactNode; busy?: boolean;
}) {
  const titleId = useId();
  const dialog = useRef<HTMLElement>(null);
  const close = useRef(onClose);
  const pending = useRef(busy);
  close.current = onClose;
  pending.current = busy;
  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    dialog.current?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !pending.current) { event.preventDefault(); close.current(); }
      if (event.key !== 'Tab') return;
      const targets = Array.from(dialog.current?.querySelectorAll<HTMLElement>('button:not(:disabled), a[href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]') || [])
        .filter((element) => !element.hidden && element.getAttribute('aria-hidden') !== 'true');
      const first = targets[0]; const last = targets.at(-1);
      if (!first) { event.preventDefault(); dialog.current?.focus(); }
      else if (event.shiftKey && (document.activeElement === first || document.activeElement === dialog.current)) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === dialog.current)) { event.preventDefault(); first.focus(); }
    };
    const keepFocus = (event: FocusEvent) => {
      // Giới hạn trong document.body — tránh conflict với portal/popup third-party.
      if (!(event.target instanceof Node) || !document.body.contains(event.target)) return;
      if (!dialog.current?.contains(event.target)) dialog.current?.focus();
    };
    document.addEventListener('keydown', onKey);
    document.addEventListener('focusin', keepFocus);
    document.body.classList.add('drawer-open');
    return () => { document.removeEventListener('keydown', onKey); document.removeEventListener('focusin', keepFocus); document.body.classList.remove('drawer-open'); previousFocus?.focus(); };
  }, []);

  return <div className="drawer-backdrop" onMouseDown={(event) => !busy && event.target === event.currentTarget && onClose()}>
    <aside ref={dialog} tabIndex={-1} className="drawer" role="dialog" aria-modal="true" aria-busy={busy} aria-labelledby={titleId}>
      <div className="drawer-head">
        <div>{subtitle && <span className="drawer-kicker">{subtitle}</span>}<h2 id={titleId}>{title}</h2></div>
        <button className="icon-button" disabled={busy} onClick={onClose} aria-label="Đóng"><X size={20} /></button>
      </div>
      <div className="drawer-body">{children}</div>
      {footer && <div className="drawer-footer">{footer}</div>}
    </aside>
  </div>;
}

export function DetailList({ items }: { items: Array<{ label: string; value: ReactNode }> }) {
  return <dl className="detail-list">{items.map((item) => <div key={item.label}>
    <dt>{item.label}</dt><dd>{item.value === '' || item.value == null ? '—' : item.value}</dd>
  </div>)}</dl>;
}

export function Tabs({ value, onChange, items }: {
  value: string; onChange: (value: string) => void; items: Array<{ value: string; label: string; count?: number }>;
}) {
  return <div className="tabs" role="tablist">{items.map((item, index) => <button
    key={item.value} role="tab" aria-selected={value === item.value} tabIndex={value === item.value ? 0 : -1}
    onKeyDown={(event) => {
      const next = event.key === 'ArrowRight' ? (index + 1) % items.length
        : event.key === 'ArrowLeft' ? (index + items.length - 1) % items.length
        : event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : -1;
      if (next < 0) return;
      event.preventDefault(); onChange(items[next].value);
      event.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>('[role="tab"]')[next]?.focus();
    }}
    className={value === item.value ? 'active' : ''} onClick={() => onChange(item.value)}>
    {item.label}{item.count !== undefined && <span>{item.count}</span>}
  </button>)}</div>;
}

export function SectionTitle({ title, description, action }: { title: string; description?: string; action?: ReactNode }) {
  return <div className="section-title"><div><h2>{title}</h2>{description && <p>{description}</p>}</div>{action}</div>;
}
