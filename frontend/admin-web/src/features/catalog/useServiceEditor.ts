import { FormEvent, useEffect, useRef, useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { CatalogService, PricingRule } from '../../types';
import { fromDateTimeInput, toMinuteDateTimeInput } from '../../operations';
import {
  saveCatalogService,
  createServiceBundle,
  savePricingRule,
  uploadCatalogServiceImage,
} from './catalogApi';

function resolvePriceTime(value: string, original?: string) {
  return original && value === toMinuteDateTimeInput(original) ? original : fromDateTimeInput(value);
}

export function useServiceEditor(service: CatalogService | null, onChanged: (message: string) => void) {
  const { defaults } = useAdminMetadata();
  const createServiceForm = () => ({
    code: '',
    name: '',
    description: '',
    imageUrl: '',
    ...defaults.service,
  });
  const createPriceForm = () => ({
    ...defaults.pricingRule,
    effectiveFrom: toMinuteDateTimeInput(new Date()),
    effectiveTo: '',
  });
  const createChecklistItem = (key: number) => ({
    key,
    name: '',
    description: '',
    isRequired: defaults.checklist.isRequired,
    requiresPhoto: defaults.checklist.requiresPhoto,
  });
  const [form, setForm] = useState(() =>
    service
      ? {
          code: service.code,
          name: service.name,
          description: service.description || '',
          imageUrl: service.imageUrl || '',
          defaultDurationMinutes: service.defaultDurationMinutes,
          isActive: service.isActive,
        }
      : createServiceForm(),
  );
  const [priceForm, setPriceForm] = useState(createPriceForm);
  const [pendingImage, setPendingImage] = useState<File | null>(null);
  const [localImagePreview, setLocalImagePreview] = useState('');
  const [checklistItems, setChecklistItems] = useState(() => [createChecklistItem(0)]);
  const [editingPrice, setEditingPrice] = useState<PricingRule | null>(null);
  const lastSubmission = useRef<{ body: string; id: string } | null>(null);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const imagePreviewUrl = localImagePreview || form.imageUrl;

  useEffect(
    () => () => {
      if (localImagePreview) URL.revokeObjectURL(localImagePreview);
    },
    [localImagePreview],
  );

  function selectImage(file: File) {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError('Ảnh dịch vụ chỉ hỗ trợ JPEG, PNG hoặc WEBP.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setError('Ảnh dịch vụ không được vượt quá 5 MB.');
      return;
    }
    setError('');
    setPendingImage(file);
    setLocalImagePreview(URL.createObjectURL(file));
  }

  function removeImage() {
    if (busy) return;
    setPendingImage(null);
    setLocalImagePreview('');
    setForm((current) => ({ ...current, imageUrl: '' }));
  }
  function editPrice(rule: PricingRule) {
    setEditingPrice(rule);
    setPriceForm({
      name: rule.name,
      baseHourlyPrice: rule.baseHourlyPrice,
      nightMultiplier: rule.nightMultiplier,
      holidayMultiplier: rule.holidayMultiplier,
      platformFeePercent: rule.platformFeePercent,
      disputeWindowHours: rule.disputeWindowHours,
      effectiveFrom: toMinuteDateTimeInput(rule.effectiveFrom),
      effectiveTo: rule.effectiveTo ? toMinuteDateTimeInput(rule.effectiveTo) : '',
      isActive: rule.isActive,
    });
  }
  function pricingDraft() {
    const effectiveFrom = resolvePriceTime(priceForm.effectiveFrom, editingPrice?.effectiveFrom);
    const effectiveTo = priceForm.effectiveTo ? resolvePriceTime(priceForm.effectiveTo, editingPrice?.effectiveTo) : null;
    const datesChanged = effectiveFrom !== editingPrice?.effectiveFrom || effectiveTo !== editingPrice?.effectiveTo;
    if (datesChanged && effectiveTo && Date.parse(effectiveTo) <= Date.parse(effectiveFrom))
      throw new Error('Hiệu lực đến phải sau thời điểm bắt đầu.');
    return { ...priceForm, effectiveFrom, effectiveTo };
  }
  function checklistDrafts() {
    return checklistItems.map((item, index) => ({
      name: item.name,
      description: item.description,
      isRequired: item.isRequired,
      requiresPhoto: item.requiresPhoto,
      sortOrder: defaults.checklist.firstSortOrder + index,
    }));
  }
  function addChecklistItem() {
    if (busy) return;
    setChecklistItems((current) => [
      ...current,
      createChecklistItem(Math.max(...current.map((item) => item.key), -1) + 1),
    ]);
  }
  function updateChecklistItem(
    index: number,
    patch: Partial<Omit<(typeof checklistItems)[number], 'key'>>,
  ) {
    if (busy) return;
    setChecklistItems((current) =>
      current.map((item, itemIndex) => (itemIndex === index ? { ...item, ...patch } : item)),
    );
  }
  function removeChecklistItem(index: number) {
    if (busy || checklistItems.length === 1) return;
    setChecklistItems((current) => current.filter((_, itemIndex) => itemIndex !== index));
  }
  async function saveService(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setBusy('service');
    setError('');
    try {
      let serviceDraft = form;
      if (pendingImage) {
        const imageUrl = await uploadCatalogServiceImage(pendingImage);
        serviceDraft = { ...form, imageUrl };
        setForm(serviceDraft);
        setPendingImage(null);
        setLocalImagePreview('');
      }
      if (service) {
        await saveCatalogService(service.id, serviceDraft);
      } else {
        const priceDraft = pricingDraft();
        const initialChecklist = checklistDrafts();
        const body = JSON.stringify([serviceDraft, priceDraft, initialChecklist]);
        if (lastSubmission.current?.body !== body) lastSubmission.current = { body, id: crypto.randomUUID() };
        await createServiceBundle(lastSubmission.current.id, serviceDraft, priceDraft, initialChecklist);
      }
      onChanged(service ? 'Cập nhật dịch vụ thành công.' : 'Tạo dịch vụ mới thành công.');
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : 'Không thể lưu dịch vụ.';
      setError(message);
    } finally {
      setBusy('');
    }
  }
  async function savePrice(event: FormEvent) {
    event.preventDefault();
    if (!service || busy) return;
    setBusy('price');
    setError('');
    try {
      await savePricingRule(service.id, editingPrice?.id, pricingDraft());
      onChanged('Lưu bảng giá thành công.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể lưu bảng giá.');
    } finally {
      setBusy('');
    }
  }
  const resetPrice = () => {
    setEditingPrice(null);
    setPriceForm(createPriceForm());
  };
  return {
    form,
    setForm,
    imagePreviewUrl,
    selectImage,
    removeImage,
    priceForm,
    setPriceForm,
    checklistItems,
    addChecklistItem,
    updateChecklistItem,
    removeChecklistItem,
    editingPrice,
    busy,
    error,
    editPrice,
    saveService,
    savePrice,
    resetPrice,
  };
}
