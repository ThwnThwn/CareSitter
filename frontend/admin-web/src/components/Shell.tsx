import { ReactNode } from 'react';
import { Brand } from './Brand';
import { ErrorBoundary } from './ErrorBoundary';
import {
  CalendarCheck, ClipboardList, HandCoins, Headphones,
  Bug, LayoutDashboard, LogOut, Package, ShieldCheck, TicketPercent, UsersRound,
} from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { PageKey } from '../types';

const pageIcons: Record<PageKey, typeof LayoutDashboard> = {
  'crash-reports': Bug,
  dashboard: LayoutDashboard,
  bookings: CalendarCheck,
  kyc: ShieldCheck,
  payments: HandCoins,
  support: Headphones,
  disputes: ClipboardList,
  services: Package,
  promotions: TicketPercent,
  users: UsersRound,
};

export function Shell({ page, onNavigate, onLogout, children, pageLabel }: {
  page: PageKey; onNavigate: (page: PageKey) => void; onLogout: () => void;
  children: ReactNode; pageLabel?: string;
}) {
  const { currentUser, navigation } = useAdminMetadata();
  const initials = currentUser.displayName.split(/\s+/).filter(Boolean).slice(-2)
    .map((part) => part[0]?.toUpperCase()).join('') || 'AD';
  return <div className="app-shell">
    <a className="skip-link" href="#main-content" onClick={(event) => { event.preventDefault(); document.getElementById('main-content')?.focus(); }}>Bỏ qua điều hướng</a>
    <aside className="sidebar">
      <Brand />
      <select className="mobile-navigation" aria-label="Điều hướng quản trị" value={page}
        onChange={(event) => {
          const item = navigation.find((entry) => entry.key === event.target.value);
          if (item) onNavigate(item.key);
        }}>
        {navigation.map((item) => <option value={item.key} key={item.key}>{item.label}</option>)}
      </select>
      <nav aria-label="Điều hướng quản trị">{navigation.map((item) => {
        const Icon = pageIcons[item.key];
        return <button key={item.key} className={`nav-item ${page === item.key ? 'active' : ''}`}
          aria-label={item.label} title={item.label} aria-current={page === item.key ? 'page' : undefined} onClick={() => onNavigate(item.key)}>
          <Icon size={19} aria-hidden="true" /><span>{item.label}</span>
        </button>;
      })}</nav>
      <div className="sidebar-account">
        <span className="account-avatar">{initials}</span><span><strong>{currentUser.displayName}</strong><small>{currentUser.department || currentUser.roles.join(' · ')}</small></span>
      </div>
      <button className="nav-item logout" aria-label="Đăng xuất" title="Đăng xuất" onClick={onLogout}><LogOut size={19} /><span>Đăng xuất</span></button>
    </aside>
    <main className="workspace" id="main-content" tabIndex={-1}>
      <ErrorBoundary pageName={pageLabel}>{children}</ErrorBoundary>
    </main>
  </div>;
}
