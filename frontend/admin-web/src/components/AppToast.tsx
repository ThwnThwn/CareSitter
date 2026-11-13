import { useEffect, useRef } from 'react';
import { CheckCircle2, XCircle, X } from 'lucide-react';

export type ToastKind = 'success' | 'error';

export interface ToastMessage {
  id: number;
  kind: ToastKind;
  message: string;
}

/** Hiển thị toast nổi ở góc dưới phải trong 4 giây. */
export function AppToast({ toast, onDismiss }: { toast: ToastMessage; onDismiss: (id: number) => void }) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    timer.current = setTimeout(() => onDismiss(toast.id), 4000);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [toast.id, onDismiss]);

  const Icon = toast.kind === 'success' ? CheckCircle2 : XCircle;

  return (
    <div className={`app-toast app-toast--${toast.kind}`} role="status" aria-live="polite">
      <Icon size={18} aria-hidden="true" />
      <span>{toast.message}</span>
      <button className="app-toast-close" onClick={() => onDismiss(toast.id)} aria-label="Đóng thông báo">
        <X size={16} />
      </button>
    </div>
  );
}

/** Vùng chứa tất cả toast; đặt ở root layout. */
export function ToastRegion({ toasts, onDismiss }: { toasts: ToastMessage[]; onDismiss: (id: number) => void }) {
  if (toasts.length === 0) return null;
  return (
    <div className="toast-region" aria-label="Thông báo hệ thống">
      {toasts.map((t) => <AppToast key={t.id} toast={t} onDismiss={onDismiss} />)}
    </div>
  );
}
