export const FIRESTORE_CONTRACT = {
  defaultRestaurantId: 'scanserve-demo',
  defaultBranchId: 'main-branch',
  defaultTableId: 'table-12',
  defaultTableSessionId: 'active-table-session',
  defaultCustomerSessionId: 'active-customer-session',
  cartPrefix: 'cart_',
} as const;

export function normalizeCustomerSessionId(value: string | undefined): string {
  const normalized = value?.trim();
  return normalized || FIRESTORE_CONTRACT.defaultCustomerSessionId;
}

export function canonicalCartId(value: string | undefined): string {
  return `${FIRESTORE_CONTRACT.cartPrefix}${normalizeCustomerSessionId(value)}`;
}
