import { Observable } from 'rxjs';

export interface MenuCategory {
  readonly id: string;
  readonly restaurantId: string;
  readonly branchId: string | null;
  readonly name: string;
  readonly parentCategoryId: string | null;
  readonly displayOrder: number;
  readonly isActive: boolean;
  readonly archived: boolean;
}

export interface CreateMenuCategoryInput {
  readonly id: string;
  readonly branchId: string;
  readonly name: string;
  readonly parentCategoryId: string | null;
  readonly displayOrder?: number;
}

export abstract class MenuCategoryRepository {
  abstract watchParentCategories(
    restaurantId: string,
    branchId: string,
  ): Observable<readonly MenuCategory[]>;

  abstract watchSubCategories(
    restaurantId: string,
    branchId: string,
    parentCategoryId: string,
  ): Observable<readonly MenuCategory[]>;

  abstract createCategory(
    restaurantId: string,
    input: CreateMenuCategoryInput,
  ): Observable<MenuCategory>;
}
