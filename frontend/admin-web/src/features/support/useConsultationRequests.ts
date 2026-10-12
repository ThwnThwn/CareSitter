import { useState } from 'react';
import { qs } from '../../api';
import type { ConsultationRequest } from '../../types';
import { usePagedResource } from '../../useResource';

export function useConsultationRequests() {
  const [page, setPage] = useState(1);
  const resource = usePagedResource<ConsultationRequest>(
    `/api/v1/consultation-requests${qs({ page, pageSize: 20 })}`,
    page,
    setPage,
  );
  return { ...resource, setPage };
}
