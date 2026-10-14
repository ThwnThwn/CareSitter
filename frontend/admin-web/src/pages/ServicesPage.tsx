import { useState } from 'react';
import { PageHeader, Tabs } from '../components/Common';
import { CatalogManager } from '../features/catalog/CatalogManager';
import { ChecklistManager } from '../features/catalog/ChecklistManager';

export function ServicesPage() {
  const [tab, setTab] = useState('catalog');
  return (
    <>
      <PageHeader
        title="Dịch vụ"
        description="Quản lý gói chăm sóc, bảng giá và checklist được snapshot vào booking."
      />
      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { value: 'catalog', label: 'Danh mục & bảng giá' },
          { value: 'checklists', label: 'Checklist dịch vụ' },
        ]}
      />
      {tab === 'catalog' ? <CatalogManager /> : <ChecklistManager />}
    </>
  );
}
