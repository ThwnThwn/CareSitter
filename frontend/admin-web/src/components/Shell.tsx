import { ReactNode } from 'react';
import {
  CalendarCheck, ClipboardList, HandCoins, Headphones,
  LayoutDashboard, LogOut, Package, ShieldCheck, TicketPercent, UsersRound,
} from 'lucide-react';
import { useAdminMetadata } from '../adminMetadata';
import { PageKey } from '../types';

const pageIcons: Record<PageKey, typeof LayoutDashboard> = {
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

export function Shell({ page, onNavigate, onLogout, children }: {
  page: PageKey; onNavigate: (page: PageKey) => void; onLogout: () => void; children: ReactNode;
}) {
  const { currentUser, navigation } = useAdminMetadata();
  const initials = currentUser.displayName.split(/\s+/).filter(Boolean).slice(-2)
    .map((part) => part[0]?.toUpperCase()).join('') || 'AD';
  return <div className="app-shell">
    <a className="skip-link" href="#main-content" onClick={(event) => { event.preventDefault(); document.getElementById('main-content')?.focus(); }}>Bỏ qua điều hướng</a>
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">C</span><span><strong>CareSitter</strong><small>Operations Console</small></span></div>
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
      <button className="nav-item logout" onClick={onLogout}><LogOut size={19} /><span>Đăng xuất</span></button>
    </aside>
    <main className="workspace" id="main-content" tabIndex={-1}>{children}</main>
  </div>;
}
