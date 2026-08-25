export const STAFF_ASSISTANCE_TYPES = ['WAITER', 'PAYMENT'] as const;
export type StaffAssistanceType = (typeof STAFF_ASSISTANCE_TYPES)[number];

export const STAFF_ASSISTANCE_ACTIVE_STATUSES = ['OPEN', 'ACKNOWLEDGED'] as const;
export type StaffAssistanceActiveStatus = (typeof STAFF_ASSISTANCE_ACTIVE_STATUSES)[number];
export type StaffAssistanceStatus = StaffAssistanceActiveStatus | 'RESOLVED';

export interface StaffAssistanceRequest {
  readonly id: string;
  readonly restaurantId: string;
  readonly tableId: string;
  readonly tableSessionId: string;
  readonly customerSessionId: string;
  readonly type: StaffAssistanceType;
  readonly status: StaffAssistanceStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly resolvedAt: Date | null;
  readonly resolvedBy: string | null;
}
