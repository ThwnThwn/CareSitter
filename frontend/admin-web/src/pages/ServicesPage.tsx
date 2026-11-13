import { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { PageHeader, Tabs } from '../components/Common';
import { CatalogManager } from '../features/catalog/CatalogManager';
import { ChecklistManager } from '../features/catalog/ChecklistManager';
import type { ShowToast } from '../useToast';

export function ServicesPage({ showToast = () => undefined }: { showToast?: ShowToast }) {
  const [tab, setTab] = useState('catalog');
  const [revision, setRevision] = useState(0);
  return (
    <>
      <PageHeader
        title="Dịch vụ"
        description="Quản lý gói chăm sóc, bảng giá và checklist được snapshot vào booking."
        actions={<button className="secondary" onClick={() => setRevision((value) => value + 1)}><RefreshCw size={16} /> Làm mới</button>}
      />
      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { value: 'catalog', label: 'Danh mục & bảng giá' },
          { value: 'checklists', label: 'Checklist dịch vụ' },
        ]}
      />
      {tab === 'catalog' ? <CatalogManager key={`catalog-${revision}`} showToast={showToast} /> : <ChecklistManager key={`checklists-${revision}`} showToast={showToast} />}
    </>
  );
}
