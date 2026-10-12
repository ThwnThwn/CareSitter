import { FormEvent, useState } from 'react';
import { useAdminMetadata } from '../../adminMetadata';
import { CatalogService, ChecklistTemplate } from '../../types';
import { useResource } from '../../useResource';
import {
  catalogPaths,
  saveChecklistTemplate,
  saveChecklistPolicy,
  setChecklistActive,
  deleteChecklistTemplate,
} from './catalogApi';

export function useChecklistEditor(
  service: CatalogService,
  onBusy: (value: boolean) => void,
  onPolicyChanged: (value: boolean) => void,
) {
  const { defaults } = useAdminMetadata();
  const {
    data: templates,
    loading,
    error: loadError,
    reload,
  } = useResource<ChecklistTemplate[]>(catalogPaths.templates(service.id), []);
  const initialForm = () => ({
    name: '',
    description: '',
    isRequired: defaults.checklist.isRequired,
    requiresPhoto: defaults.checklist.requiresPhoto,
    sortOrder: null as number | null,
  });
  const nextSortOrder = Math.max(
    defaults.checklist.firstSortOrder,
    ...templates.map((template) => template.sortOrder + 1),
  );
  const [editing, setEditing] = useState<ChecklistTemplate | null>(null);
  const [form, setForm] = useState(initialForm);
  const [allowAdHocTasks, setAllowAdHocTasks] = useState(service.allowAdHocTasks);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const disabled = !!busy || loading || !!loadError;
  function reset() {
    setEditing(null);
    setForm(initialForm());
  }
  async function mutate(action: string, operation: () => Promise<unknown>) {
    if (disabled) return;
    setBusy(action);
    onBusy(true);
    setError('');
    try {
      await operation();
      if (action === 'policy') {
        setAllowAdHocTasks(!allowAdHocTasks);
        onPolicyChanged(!allowAdHocTasks);
      } else {
        reset();
        await reload();
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không thể cập nhật checklist.');
    } finally {
      setBusy('');
      onBusy(false);
    }
  }
  function save(event: FormEvent) {
    event.preventDefault();
    void mutate('save', () =>
      saveChecklistTemplate(service.id, editing?.id, {
        ...form,
        sortOrder: form.sortOrder ?? nextSortOrder,
      }),
    );
  }
  const togglePolicy = () =>
    mutate('policy', () => saveChecklistPolicy(service.id, !allowAdHocTasks));
  const toggleTemplate = (template: ChecklistTemplate) =>
    mutate(template.id, () => setChecklistActive(service.id, template.id, !template.isActive));
  const removeTemplate = (template: ChecklistTemplate) =>
    mutate(template.id, () => deleteChecklistTemplate(service.id, template.id));
  const editTemplate = (template: ChecklistTemplate) => {
    setEditing(template);
    setForm({
      name: template.name,
      description: template.description || '',
      isRequired: template.isRequired,
      requiresPhoto: template.requiresPhoto,
      sortOrder: template.sortOrder,
    });
  };
  return {
    templates,
    loading,
    loadError,
    reload,
    editing,
    form,
    setForm,
    allowAdHocTasks,
    busy,
    error,
    disabled,
    nextSortOrder,
    reset,
    save,
    togglePolicy,
    toggleTemplate,
    removeTemplate,
    editTemplate,
  };
}
