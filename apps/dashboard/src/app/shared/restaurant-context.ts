export const DEFAULT_RESTAURANT_ID = 'scanserve-demo';

export function normalizeRestaurantId(value: string | null | undefined): string {
  const restaurantId = value?.trim();
  return restaurantId || DEFAULT_RESTAURANT_ID;
}
