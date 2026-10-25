import { useState } from 'react';
import { Tabs } from '../components/Common';
import { ConsultationInbox } from '../features/support/ConsultationInbox';
import { SupportTickets } from '../features/support/SupportTickets';
import { SupportConversations } from '../features/support/SupportConversations';
import { BookingChatConversations } from '../features/support/BookingChatConversations';

export function SupportPage() {
  const [tab, setTab] = useState('tickets');
  return (
    <section className="support-page">
      <Tabs
        value={tab}
        onChange={setTab}
        items={[
          { value: 'tickets', label: 'Ticket hỗ trợ' },
          { value: 'consultations', label: 'Yêu cầu tư vấn' },
          { value: 'chat', label: 'Chat hỗ trợ' },
          { value: 'booking-chat', label: 'Booking Chat' },
        ]}
      />
      <div className="support-tab-content" role="tabpanel">
        {tab === 'tickets' ? <SupportTickets /> : tab === 'consultations' ? <ConsultationInbox /> :
          tab === 'chat' ? <SupportConversations /> : <BookingChatConversations />}
      </div>
    </section>
  );
}
