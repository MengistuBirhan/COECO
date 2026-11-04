import { type ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useRole, canAccess, getHomeTab, type TabId, type RoleId } from '@/lib/rbac';
import { useAdminAuth } from '@/lib/adminAuth';

const PATH_TO_TAB: Record<string, TabId> = {
  '/dashboard': 'dashboard',
  '/pos': 'pos',
  '/invoice': 'pos',
  '/approvals': 'approvals',
  '/trucks': 'trucks',
  '/truck': 'truck',
  '/gate-pass': 'gatepass',
  '/gatepass': 'gatepass',
  '/dispatch': 'dispatch',
  '/ledger': 'ledger',
  '/inventory': 'inventory',
};

export function getTabForPath(path: string): TabId | undefined {
  return PATH_TO_TAB[path];
}

function redirectForRole(role: RoleId): string {
  if (canAccess(role, 'dashboard')) return '/dashboard';
  return `/${getHomeTab(role)}`;
}

export default function ProtectedRoute({
  tab,
  children,
}: {
  tab: TabId;
  children: ReactNode;
}) {
  const { role } = useRole();
  const { loading: authLoading } = useAdminAuth();
  const location = useLocation();

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="flex flex-col items-center gap-3 text-slate-400 dark:text-slate-500">
          <div className="w-6 h-6 border-2 border-amber-400 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm">Verifying access…</span>
        </div>
      </div>
    );
  }

  if (!canAccess(role, tab)) {
    return <Navigate to={redirectForRole(role)} replace state={{ from: location.pathname }} />;
  }

  return <>{children}</>;
}
