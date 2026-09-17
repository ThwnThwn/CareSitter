import { createContext, ReactNode, useContext } from 'react';
import { AdminMetadata, AdminOption } from './types';

const AdminMetadataContext = createContext<AdminMetadata | null>(null);

export function AdminMetadataProvider({ value, children }: { value: AdminMetadata; children: ReactNode }) {
  return <AdminMetadataContext.Provider value={value}>{children}</AdminMetadataContext.Provider>;
}

export function useAdminMetadata() {
  const metadata = useContext(AdminMetadataContext);
  if (!metadata) throw new Error('Admin metadata is not available.');
  return metadata;
}

export function optionLabel(options: AdminOption[], value?: string) {
  return options.find((option) => option.value === value)?.label || value || '—';
}
