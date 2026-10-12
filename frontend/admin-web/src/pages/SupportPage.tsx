import { useState } from 'react';
import { Tabs } from '../components/Common';
import { ConsultationInbox } from '../features/support/ConsultationInbox';
import { SupportTickets } from '../features/support/SupportTickets';

export function SupportPage() {
  const [tab, setTab] = useState('tickets');
  return (
    <>
      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { value: 'tickets', label: 'Ticket hỗ trợ' },
          { value: 'consultations', label: 'Yêu cầu tư vấn' },
        ]}
      />
      {tab === 'tickets' ? <SupportTickets /> : <ConsultationInbox />}
    </>
  );
}
