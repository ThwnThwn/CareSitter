/**
 * Hàm tiện ích định dạng hiển thị — tách khỏi Common.tsx
 * để phân biệt rõ UI component và pure utility function.
 */

export function formatMoney(value?: number) {
  return new Intl.NumberFormat('vi-VN').format(value || 0) + ' đ';
}

export function formatDate(value?: string, withTime = true) {
  if (!value || !Number.isFinite(Date.parse(value))) return '—';
  return new Intl.DateTimeFormat('vi-VN', withTime
    ? { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' }
    : { day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value));
}

export function shortId(value?: string) {
  return value ? `#${value.slice(0, 8).toUpperCase()}` : '—';
}
