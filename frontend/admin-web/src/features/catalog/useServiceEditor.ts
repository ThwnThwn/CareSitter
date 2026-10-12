import { FormEvent, useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { CatalogService, PricingRule } from '../../types';
import { fromDateTimeInput, toDateTimeInput } from '../../operations';
import { saveCatalogService, savePricingRule } from './catalogApi';

export function useServiceEditor(service: CatalogService | null, onChanged: () => void) {
  const { defaults } = useAdminMetadata();
  const createServiceForm = () => ({ code: '', name: '', description: '', ...defaults.service });
  const createPriceForm = () => ({
    ...defaults.pricingRule,
    effectiveFrom: toDateTimeInput(new Date()),
    effectiveTo: '',
  });
  const [form, setForm] = useState(() =>
    service
      ? {
          code: service.code,
          name: service.name,
          description: service.description || '',
          defaultDurationMinutes: service.defaultDurationMinutes,
          isActive: service.isActive,
        }
      : createServiceForm(),
  );
  const [priceForm, setPriceForm] = useState(createPriceForm);
  const [editingPrice, setEditingPrice] = useState<PricingRule | null>(null);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  function editPrice(rule: PricingRule) {
    setEditingPrice(rule);
    setPriceForm({
      name: rule.name,
      baseHourlyPrice: rule.baseHourlyPrice,
      nightMultiplier: rule.nightMultiplier,
      holidayMultiplier: rule.holidayMultiplier,
      platformFeePercent: rule.platformFeePercent,
      disputeWindowHours: rule.disputeWindowHours,
      effectiveFrom: toDateTimeInput(rule.effectiveFrom),
      effectiveTo: rule.effectiveTo ? toDateTimeInput(rule.effectiveTo) : '',
      isActive: rule.isActive,
    });
  }
  async function saveService(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setBusy('service');
    setError('');
    try {
      await saveCatalogService(service?.id, form);
      onChanged();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể lưu dịch vụ.');
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
      if (
        priceForm.effectiveTo &&
        Date.parse(fromDateTimeInput(priceForm.effectiveTo)) <=
          Date.parse(fromDateTimeInput(priceForm.effectiveFrom))
      )
        throw new Error('Hiệu lực đến phải sau thời điểm bắt đầu.');
      await savePricingRule(service.id, editingPrice?.id, {
        ...priceForm,
        effectiveFrom: fromDateTimeInput(priceForm.effectiveFrom),
        effectiveTo: priceForm.effectiveTo ? fromDateTimeInput(priceForm.effectiveTo) : null,
      });
      onChanged();
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
    priceForm,
    setPriceForm,
    editingPrice,
    busy,
    error,
    editPrice,
    saveService,
    savePrice,
    resetPrice,
  };
}
