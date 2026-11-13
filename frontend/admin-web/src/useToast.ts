import { useCallback, useState } from 'react';
import type { ToastKind, ToastMessage } from './components/AppToast';

let nextId = 1;

/** Hook quản lý danh sách toast. Dùng ở root App rồi truyền `showToast` xuống qua prop hoặc context. */
export function useToast() {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);
  const show = useCallback((message: string, kind: ToastKind = 'success') => {
    const id = nextId++;
    setToasts((prev) => [...prev.slice(-4), { id, kind, message }]);
  }, []);
  return { toasts, showToast: show, dismissToast: dismiss };
}

/** Kiểu hàm showToast để truyền xuống các component con. */
export type ShowToast = (message: string, kind?: ToastKind) => void;
