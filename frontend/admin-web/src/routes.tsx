import { CrashReportsPage } from './pages/CrashReportsPage';
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
import type { ShowToast } from './useToast';

export const pageRenderers: Record<PageKey, (navigate: (page: PageKey) => void, showToast: ShowToast) => ReactNode> = {
  'crash-reports': () => <CrashReportsPage />,
  dashboard: (navigate) => <DashboardPage onNavigate={navigate} />,
  bookings: (_, showToast) => <BookingsPage showToast={showToast} />,
  kyc: (_, showToast) => <KycPage showToast={showToast} />,
  payments: (_, showToast) => <PaymentsPage showToast={showToast} />,
  support: () => <SupportPage />,
  disputes: (_, showToast) => <DisputesPage showToast={showToast} />,
  services: (_, showToast) => <ServicesPage showToast={showToast} />,
  promotions: (_, showToast) => <PromotionsPage showToast={showToast} />,
  users: (_, showToast) => <UsersPage showToast={showToast} />,
};

export const pages = Object.keys(pageRenderers) as PageKey[];

export function pageFromHash(): PageKey {
  const value = window.location.hash.replace(/^#\/?/, '').split('?')[0] as PageKey;
  return pages.includes(value) ? value : 'dashboard';
}

export function hashParam(name: string) {
  const query = window.location.hash.split('?')[1] || '';
  return new URLSearchParams(query).get(name);
}
