export const DEFAULT_RESTAURANT_ID = 'scanserve-demo';
export const DEFAULT_BRANCH_ID = 'main-branch';

export function normalizeRestaurantId(value: string | null | undefined): string {
  const restaurantId = value?.trim();
  return restaurantId || DEFAULT_RESTAURANT_ID;
}
