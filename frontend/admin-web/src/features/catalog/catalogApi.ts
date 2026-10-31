import { api } from '../../api';
import type { CatalogService, ChecklistTemplate, PricingRule } from '../../types';

export const catalogPaths = {
  services: '/api/v1/admin/catalog/services',
  templates: (serviceId: string) => `/api/v1/admin/services/${serviceId}/checklist-templates`,
};

type ServiceDraft = Pick<
  CatalogService,
  'code' | 'name' | 'description' | 'imageUrl' | 'defaultDurationMinutes' | 'isActive'
>;
type PriceDraft = Omit<PricingRule, 'id' | 'serviceTypeId' | 'effectiveTo'> & {
  effectiveTo: string | null;
};
type ChecklistDraft = Pick<
  ChecklistTemplate,
  'name' | 'description' | 'isRequired' | 'requiresPhoto' | 'sortOrder'
>;

export function saveCatalogService(id: string | undefined, draft: ServiceDraft) {
  return api<CatalogService>(id ? `${catalogPaths.services}/${id}` : catalogPaths.services, {
    method: id ? 'PUT' : 'POST',
    body: JSON.stringify(draft),
  });
}

export async function uploadCatalogServiceImage(file: File) {
  const body = new FormData();
  body.append('file', file);
  body.append('folder', 'catalog');
  const uploaded = await api<{ url: string }>('/api/v1/media/upload', {
    method: 'POST',
    body,
  });
  return uploaded.url;
}

export function savePricingRule(serviceId: string, id: string | undefined, draft: PriceDraft) {
  const path = `${catalogPaths.services}/${serviceId}/pricing-rules`;
  return api<PricingRule>(id ? `${path}/${id}` : path, {
    method: id ? 'PUT' : 'POST',
    body: JSON.stringify(draft),
  });
}

export function saveChecklistTemplate(
  serviceId: string,
  id: string | undefined,
  draft: ChecklistDraft,
) {
  const path = catalogPaths.templates(serviceId);
  return api<ChecklistTemplate>(id ? `${path}/${id}` : path, {
    method: id ? 'PUT' : 'POST',
    body: JSON.stringify(draft),
  });
}

export function saveChecklistPolicy(serviceId: string, allowAdHocTasks: boolean) {
  return api(`/api/v1/admin/services/${serviceId}/checklist-policy`, {
    method: 'PATCH',
    body: JSON.stringify({ allowAdHocTasks }),
  });
}

export function setChecklistActive(serviceId: string, id: string, isActive: boolean) {
  return api(`${catalogPaths.templates(serviceId)}/${id}/active`, {
    method: 'PATCH',
    body: JSON.stringify({ isActive }),
  });
}

export function deleteChecklistTemplate(serviceId: string, id: string) {
  return api(`${catalogPaths.templates(serviceId)}/${id}`, { method: 'DELETE' });
}
