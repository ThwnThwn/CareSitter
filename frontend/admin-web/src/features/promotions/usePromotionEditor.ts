import { FormEvent, useState } from 'react';
import { ApiError } from '../../api';
import { createPromotionForm, promotionPayload, PromotionForm } from '../../promotionForm';
import { AdminPromotion, CatalogService } from '../../types';
import { useResource } from '../../useResource';
import { catalogPaths } from '../catalog/catalogApi';
import { savePromotion, setPromotionActive, deletePromotion } from './promotionApi';

export function usePromotionEditor(
  promotion: AdminPromotion | null,
  onChanged: (message: string) => void,
) {
  const [form, setForm] = useState(() => createPromotionForm(promotion));
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [stale, setStale] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const locked = !!promotion?.hasHistory;
  const {
    data: services,
    loading: servicesLoading,
    error: servicesError,
    reload: reloadServices,
  } = useResource<CatalogService[]>(catalogPaths.services, []);
  const set = <K extends keyof PromotionForm>(key: K, value: PromotionForm[K]) =>
    setForm((previous) => ({ ...previous, [key]: value }));
  function failed(cause: unknown) {
    setError(cause instanceof Error ? cause.message : 'Không thể lưu chiến dịch.');
    setStale(
      !!promotion &&
        cause instanceof ApiError &&
        cause.status === 409 &&
        ['promotion.stale', 'promotion.has_history', 'promotion.rules_locked'].includes(
          cause.code || '',
        ),
    );
  }
  async function save(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setBusy('save');
    setError('');
    setStale(false);
    try {
      const payload = promotionPayload(form, promotion?.updatedAt);
      if (locked && promotion) payload.startsAt = promotion.startsAt;
      await savePromotion(promotion?.id, payload);
      onChanged(promotion ? 'Đã lưu thay đổi chiến dịch.' : 'Đã tạo chiến dịch ưu đãi.');
    } catch (cause) {
      failed(cause);
    } finally {
      setBusy('');
    }
  }
  async function changeActive() {
    if (!promotion || busy) return;
    setBusy('active');
    setError('');
    setStale(false);
    try {
      await setPromotionActive(promotion, !promotion.isActive);
      onChanged(
        promotion.isActive
          ? 'Đã tắt chiến dịch. Lượt giữ hiện có vẫn được xử lý theo booking.'
          : 'Đã bật chiến dịch. Ưu đãi áp dụng trong thời gian đã cấu hình.',
      );
    } catch (cause) {
      failed(cause);
    } finally {
      setBusy('');
    }
  }
  async function remove() {
    if (!promotion || !promotion.canDelete || busy) return;
    setBusy('delete');
    setError('');
    setStale(false);
    try {
      await deletePromotion(promotion);
      onChanged(`Đã xóa chiến dịch ${promotion.code}.`);
    } catch (cause) {
      failed(cause);
    } finally {
      setBusy('');
    }
  }
  return {
    form,
    set,
    busy,
    error,
    stale,
    locked,
    confirmDelete,
    setConfirmDelete,
    services,
    servicesLoading,
    servicesError,
    reloadServices,
    save,
    changeActive,
    remove,
  };
}
export type PromotionEditorState = ReturnType<typeof usePromotionEditor>;
