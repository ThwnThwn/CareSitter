import { ReactNode } from 'react';
import { BookingsPage } from './pages/BookingsPage';
import { DashboardPage } from './pages/DashboardPage';
import { DisputesPage } from './pages/DisputesPage';
import { KycPage } from './pages/KycPage';
import { PaymentsPage } from './pages/PaymentsPage';
import { PromotionsPage } from './pages/PromotionsPage';
import { ServicesPage } from './pages/ServicesPage';
import { SupportPage } from './pages/SupportPage';
import { UsersPage } from './pages/UsersPage';
import { PageKey } from './types';

export const pageRenderers: Record<PageKey, (navigate: (page: PageKey) => void) => ReactNode> = {
  dashboard: (navigate) => <DashboardPage onNavigate={navigate} />,
  bookings: () => <BookingsPage />,
  kyc: () => <KycPage />,
  payments: () => <PaymentsPage />,
  support: () => <SupportPage />,
  disputes: () => <DisputesPage />,
  services: () => <ServicesPage />,
  promotions: () => <PromotionsPage />,
  users: () => <UsersPage />,
};

export const pages = Object.keys(pageRenderers) as PageKey[];

export function pageFromHash(): PageKey {
  const value = window.location.hash.replace('#/', '') as PageKey;
  return pages.includes(value) ? value : 'dashboard';
}
