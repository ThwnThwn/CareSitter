import { useState } from 'react';
import { Tabs } from '../components/Common';
import { ConsultationInbox } from '../features/support/ConsultationInbox';
import { SupportTickets } from '../features/support/SupportTickets';
import { SupportConversations } from '../features/support/SupportConversations';

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
          { value: 'chat', label: 'Chat hỗ trợ' },
        ]}
      />
      {tab === 'tickets' ? <SupportTickets /> :
        tab === 'consultations' ? <ConsultationInbox /> : <SupportConversations />}
    </>
  );
}
