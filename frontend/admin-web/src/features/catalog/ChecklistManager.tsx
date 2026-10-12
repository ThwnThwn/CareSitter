import { useState } from 'react';
import { EmptyState, ErrorBanner, LoadingTable } from '../../components/Common';
import { CatalogService } from '../../types';
import { useResource } from '../../useResource';
import { catalogPaths } from './catalogApi';
import { ChecklistEditor } from './ChecklistEditor';

export function ChecklistManager() {
  const {
    data: services,
    loading,
    error,
    reload,
  } = useResource<CatalogService[]>(catalogPaths.services, []);
  const [selectedId, setSelectedId] = useState('');
  const [policies, setPolicies] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState(false);
  const selectedService = services.find((service) => service.id === selectedId) || services[0];
  if (loading) return <LoadingTable rows={5} columns={4} />;
  if (error) return <ErrorBanner message={error} onRetry={() => void reload()} />;
  if (!selectedService)
    return (
      <EmptyState
        title="Chưa có gói dịch vụ"
        description="Tạo gói ở tab Danh mục & bảng giá trước khi thêm checklist."
      />
    );
  return (
    <div className="checklist-layout tab-panel">
      <aside className="service-rail">
        <h2>Gói dịch vụ</h2>
        {services.map((service) => (
          <button
            key={service.id}
            disabled={busy}
            className={selectedService.id === service.id ? 'active' : ''}
            onClick={() => setSelectedId(service.id)}
          >
            <strong>{service.name}</strong>
            <small>{service.code}</small>
          </button>
        ))}
      </aside>
      <ChecklistEditor
        key={selectedService.id}
        service={{
          ...selectedService,
          allowAdHocTasks: policies[selectedService.id] ?? selectedService.allowAdHocTasks,
        }}
        onBusy={setBusy}
        onPolicyChanged={(value) =>
          setPolicies((current) => ({ ...current, [selectedService.id]: value }))
        }
      />
    </div>
  );
}
