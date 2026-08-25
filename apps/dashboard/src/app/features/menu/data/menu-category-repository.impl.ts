import { inject, Injectable, Injector, runInInjectionContext } from '@angular/core';
import {
  collection,
  doc,
  Firestore,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  where,
} from '@angular/fire/firestore';
import { catchError, from, map, Observable, of, startWith, throwError } from 'rxjs';

import { DEFAULT_BRANCH_ID, normalizeRestaurantId } from '../../../shared/restaurant-context';
import {
  CreateMenuCategoryInput,
  MenuCategory,
  MenuCategoryRepository,
} from '../domain/menu-category';

interface MenuCategoryDto {
  readonly id: string;
  readonly restaurantId?: unknown;
  readonly branchId?: unknown;
  readonly name?: unknown;
  readonly parentCategoryId?: unknown;
  readonly displayOrder?: unknown;
  readonly isActive?: unknown;
  readonly archived?: unknown;
  readonly isArchived?: unknown;
}

@Injectable()
export class MenuCategoryRepositoryImpl extends MenuCategoryRepository {
  private readonly firestore = inject(Firestore);
  private readonly injector = inject(Injector);

  watchParentCategories(
    restaurantId: string,
    branchId: string,
  ): Observable<readonly MenuCategory[]> {
    return this.watchCategories(restaurantId, branchId, null);
  }

  watchSubCategories(
    restaurantId: string,
    branchId: string,
    parentCategoryId: string,
  ): Observable<readonly MenuCategory[]> {
    return this.watchCategories(restaurantId, branchId, parentCategoryId);
  }

  createCategory(restaurantId: string, input: CreateMenuCategoryInput): Observable<MenuCategory> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const resolvedBranchId = input.branchId.trim() || DEFAULT_BRANCH_ID;
    const resolvedId = input.id.trim();
    const resolvedName = input.name.trim();

    return from(
      runInInjectionContext(this.injector, async () => {
        const reference = doc(
          this.firestore,
          `restaurants/${resolvedRestaurantId}/categories/${resolvedId}`,
        );
        const timestamp = serverTimestamp();
        await setDoc(reference, {
          id: resolvedId,
          restaurantId: resolvedRestaurantId,
          branchId: resolvedBranchId,
          name: resolvedName,
          parentCategoryId: input.parentCategoryId?.trim() || null,
          displayOrder: input.displayOrder ?? 0,
          isActive: true,
          isArchived: false,
          archived: false,
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        return reference;
      }),
    ).pipe(
      map((reference) => ({
        id: reference.id,
        restaurantId: resolvedRestaurantId,
        branchId: resolvedBranchId,
        name: resolvedName,
        parentCategoryId: input.parentCategoryId?.trim() || null,
        displayOrder: input.displayOrder ?? 0,
        isActive: true,
        archived: false,
      })),
      catchError((error: unknown) =>
        throwError(() => new Error(this.readableError(error, 'Unable to create the category.'))),
      ),
    );
  }

  private watchCategories(
    restaurantId: string,
    branchId: string,
    parentCategoryId: string | null,
  ): Observable<readonly MenuCategory[]> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const resolvedBranchId = branchId.trim() || DEFAULT_BRANCH_ID;
    const parentFilter = parentCategoryId?.trim() || null;

    return runInInjectionContext(this.injector, () => {
      return new Observable<MenuCategoryDto[]>((observer) => {
        const categoryQuery = query(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/categories`),
          where('parentCategoryId', '==', parentFilter),
        );
        const unsubscribe = onSnapshot(
          categoryQuery,
          (snapshot) => {
            observer.next(
              snapshot.docs.map(
                (snapshotDocument) =>
                  ({ id: snapshotDocument.id, ...snapshotDocument.data() }) as MenuCategoryDto,
              ),
            );
          },
          (error) => observer.error(error),
        );
        return () => unsubscribe();
      }).pipe(
        map((documents) =>
          documents
            .map((document) => toMenuCategory(document, resolvedRestaurantId, resolvedBranchId))
            .filter((category): category is MenuCategory => category !== null)
            .sort(
              (left, right) =>
                left.displayOrder - right.displayOrder || left.name.localeCompare(right.name),
            ),
        ),
        startWith([] as readonly MenuCategory[]),
        catchError((error: unknown) => {
          console.error('[Firestore Category Stream Error]', error);
          return of([] as readonly MenuCategory[]);
        }),
      );
    });
  }

  private readableError(error: unknown, fallback: string): string {
    if (typeof error === 'object' && error !== null && 'code' in error) {
      const code = (error as { readonly code?: unknown }).code;
      if (code === 'permission-denied') return 'You do not have permission to manage categories.';
    }
    return fallback;
  }
}

function toMenuCategory(
  dto: MenuCategoryDto,
  fallbackRestaurantId: string,
  branchId: string,
): MenuCategory | null {
  if (typeof dto.name !== 'string' || !dto.name.trim()) return null;
  const resolvedBranchId = typeof dto.branchId === 'string' ? dto.branchId.trim() : '';
  if (resolvedBranchId && resolvedBranchId !== branchId) return null;
  if (dto.isActive === false || dto.archived === true || dto.isArchived === true) return null;

  const parentCategoryId =
    typeof dto.parentCategoryId === 'string' && dto.parentCategoryId.trim()
      ? dto.parentCategoryId.trim()
      : null;
  return {
    id: dto.id,
    restaurantId:
      typeof dto.restaurantId === 'string' && dto.restaurantId.trim()
        ? dto.restaurantId.trim()
        : fallbackRestaurantId,
    branchId: resolvedBranchId || null,
    name: dto.name.trim(),
    parentCategoryId,
    displayOrder: typeof dto.displayOrder === 'number' ? dto.displayOrder : 0,
    isActive: true,
    archived: false,
  };
}
