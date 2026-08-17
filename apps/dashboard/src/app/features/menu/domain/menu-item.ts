import { Observable } from 'rxjs';

export const MENU_AVAILABILITIES = ['in_stock', 'out_of_stock'] as const;
export type MenuAvailability = (typeof MENU_AVAILABILITIES)[number];

export interface MenuItem {
  readonly id: string;
  readonly restaurantId: string;
  readonly branchId: string | null;
  readonly name: string;
  readonly description: string;
  readonly category: string;
  readonly price: number;
  readonly availability: MenuAvailability;
  readonly archived: boolean;
  readonly createdAt?: Date | null;
  readonly updatedAt?: Date | null;
}

export interface CreateMenuItemInput {
  readonly name: string;
  readonly description: string;
  readonly category: string;
  readonly price: number;
  readonly availability: MenuAvailability;
}

export type UpdateMenuItemInput = CreateMenuItemInput;

export abstract class MenuRepository {
  abstract watchMenu(restaurantId: string): Observable<readonly MenuItem[]>;

  abstract createMenuItem(restaurantId: string, input: CreateMenuItemInput): Observable<MenuItem>;

  abstract updateMenuItem(
    restaurantId: string,
    itemId: string,
    input: UpdateMenuItemInput,
  ): Observable<void>;

  abstract archiveMenuItem(restaurantId: string, itemId: string): Observable<void>;

  abstract toggleAvailability(
    restaurantId: string,
    itemId: string,
    availability: MenuAvailability,
  ): Observable<void>;
}
