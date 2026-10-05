export type PageKey = 'dashboard' | 'bookings' | 'kyc' | 'payments' | 'support' | 'disputes' | 'services' | 'users';

export type StatusTone = 'neutral' | 'info' | 'success' | 'warning' | 'danger';

export type AdminOption = {
  value: string;
  label: string;
  tone: StatusTone;
  description?: string;
  actionLabel?: string;
};

export type AdminFilter = {
  defaultValue: string;
  options: AdminOption[];
};

export type AdminMetadata = {
  schemaVersion: number;
  currentUser: {
    id: string;
    email: string;
    displayName: string;
    roles: string[];
    department?: string;
  };
  navigation: Array<{ key: PageKey; label: string; workTypes: string[] }>;
  statusDefinitions: Record<string, { label: string; tone: StatusTone }>;
  filters: {
    bookings: AdminFilter;
    kyc: AdminFilter;
    payouts: AdminFilter;
    tickets: AdminFilter;
    ticketTypes: AdminFilter;
    ticketPriorities: AdminFilter;
    disputes: AdminFilter;
    userRoles: AdminFilter;
    userStatuses: AdminFilter;
  };
  roles: AdminOption[];
  userStatuses: AdminOption[];
  disputeDecisions: AdminOption[];
  transitions: { support: Record<string, string[]> };
  reviewableStatuses: {
    kyc: string[];
    payouts: string[];
    disputes: string[];
  };
  dashboard: {
    metricCards: Array<{
      key: keyof DashboardData['metrics'];
      label: string;
      note: string;
      page: PageKey;
    }>;
  };
  defaults: {
    service: { defaultDurationMinutes: number; isActive: boolean };
    pricingRule: {
      name: string;
      baseHourlyPrice: number;
      nightMultiplier: number;
      holidayMultiplier: number;
      platformFeePercent: number;
      disputeWindowHours: number;
      isActive: boolean;
    };
    checklist: { isRequired: boolean; requiresPhoto: boolean; firstSortOrder: number };
  };
  constraints: {
    serviceDurationMinutes: NumericConstraint;
    priceMultiplier: NumericConstraint;
    platformFeePercent: NumericConstraint;
    disputeWindowHours: NumericConstraint;
    rejectionReasonMinLength: number;
  };
};

export type NumericConstraint = { min: number; max: number; step?: number };

export type Paged<T> = { items: T[]; total: number; page: number; pageSize: number };

export type DashboardData = {
  generatedAt: string;
  metrics: {
    bookingsToday: number;
    pendingKyc: number;
    pendingPayouts: number;
    openTickets: number;
    openDisputes: number;
    manualPayments: number;
    activeUsers: number;
  };
  bookingStatuses: Record<string, number>;
  workItems: WorkItem[];
};

export type WorkItem = {
  priority?: string;
  type: 'PAYMENT' | 'KYC' | 'PAYOUT' | 'SUPPORT' | 'DISPUTE';
  id: string;
  title: string;
  subtitle: string;
  status: string;
  createdAt: string;
};

export type Booking = {
  id: string;
  beneficiaryId: string;
  caregiverId?: string;
  addressId: string;
  serviceTypeId: string;
  scheduledStart: string;
  scheduledEnd: string;
  actualStart?: string;
  actualEnd?: string;
  checkoutPendingReviewAt?: string;
  checkoutSource?: string;
  status: string;
  escrowAmount: number;
  platformFeeAmount: number;
  caregiverEarningAmount: number;
  cancelReason?: string;
  createdAt: string;
  updatedAt: string;
  beneficiaryName?: string;
  caregiverName?: string;
  addressText?: string;
  serviceName?: string;
  note?: string;
  beneficiaryAge?: number;
  beneficiaryCondition?: string;
  beneficiaryNotes?: string;
  needsReview?: boolean;
};

export type TimelineEvent = {
  id: string;
  eventType: string;
  title?: string;
  note?: string;
  recordedAt: string;
  source: string;
};

export type CareTask = {
  id: string;
  name: string;
  description?: string;
  isRequired: boolean;
  requiresPhoto: boolean;
  status: string;
  completedAt?: string;
  skipReason?: string;
  photoUrls?: string[];
};

export type KycProfile = {
  id: string;
  userId: string;
  fullName?: string;
  dateOfBirth?: string;
  gender?: string;
  kycStatus: string;
  cccdFrontMediaId?: string;
  cccdBackMediaId?: string;
  certificateMediaIds?: string[];
  requiresSecureResubmission?: boolean;
  createdAt: string;
  updatedAt: string;
};

export type Payout = {
  id: string;
  caregiverId: string;
  walletAccountId: string;
  amount: number;
  bankName: string;
  accountHolderName: string;
  accountNumber: string;
  status: string;
  requestedAt: string;
  reviewedAt?: string;
  rejectReason?: string;
};

export type PaymentReview = {
  intentId: string;
  bookingId: string;
  customerId: string;
  amount: number;
  currency: string;
  providerOrderRef?: string;
  providerTransactionId?: string;
  reconciliationAttempts: number;
  reconciliationStartedAt?: string;
  lastReconciliationAt?: string;
  lastReconciliationError?: string;
  manualReviewReason?: string;
  bookingStatus: string;
  paymentDeadline: string;
};

export type SupportTicket = {
  id: string;
  userId: string;
  bookingId?: string;
  type: string;
  status: string;
  priority: string;
  title: string;
  description: string;
  attachmentUrls: string[];
  assignedAdminId?: string;
  createdAt: string;
  updatedAt: string;
};

export type Dispute = {
  id: string;
  bookingId: string;
  raisedByUserId: string;
  reason?: string;
  description?: string;
  status: string;
  decision?: string;
  refundAmount?: number;
  openedAt: string;
  resolvedAt?: string;
};

export type PricingRule = {
  id: string;
  serviceTypeId: string;
  name: string;
  baseHourlyPrice: number;
  nightMultiplier: number;
  holidayMultiplier: number;
  platformFeePercent: number;
  disputeWindowHours: number;
  effectiveFrom: string;
  effectiveTo?: string;
  isActive: boolean;
};

export type CatalogService = {
  id: string;
  code: string;
  name: string;
  description?: string;
  defaultDurationMinutes: number;
  isActive: boolean;
  allowAdHocTasks: boolean;
  pricingRules: PricingRule[];
};

export type ChecklistTemplate = {
  id: string;
  serviceTypeId: string;
  name: string;
  description?: string;
  isRequired: boolean;
  requiresPhoto: boolean;
  sortOrder: number;
  isActive: boolean;
};

export type AdminUser = {
  id: string;
  email: string;
  phone?: string;
  displayName?: string;
  fullName?: string;
  avatarUrl?: string;
  status: string;
  roles: string[];
  adminDepartment?: string;
  adminRole?: string;
  adminIsActive?: boolean;
  lastLoginAt?: string;
  createdAt: string;
  updatedAt: string;
};
