import { api } from '../../api';
import { promotionPayload } from '../../promotionForm';
import type { AdminPromotion } from '../../types';

export const promotionsEndpoint = '/api/v1/admin/promotions';

export function savePromotion(
  id: string | undefined,
  payload: ReturnType<typeof promotionPayload>,
) {
  return api(id ? `${promotionsEndpoint}/${id}` : promotionsEndpoint, {
    method: id ? 'PUT' : 'POST',
    body: JSON.stringify(payload),
  });
}

export function setPromotionActive(promotion: AdminPromotion, isActive: boolean) {
  return api(`${promotionsEndpoint}/${promotion.id}/active`, {
    method: 'PATCH',
    body: JSON.stringify({ isActive, expectedUpdatedAt: promotion.updatedAt }),
  });
}

export function deletePromotion(promotion: AdminPromotion) {
  return api(`${promotionsEndpoint}/${promotion.id}`, {
    method: 'DELETE',
    body: JSON.stringify({ expectedUpdatedAt: promotion.updatedAt }),
  });
}
