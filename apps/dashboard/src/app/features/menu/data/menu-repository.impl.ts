import { inject, Injectable, Injector, runInInjectionContext } from '@angular/core';
import {
  addDoc,
  collection,
  collectionData,
  doc,
  Firestore,
  serverTimestamp,
  updateDoc,
} from '@angular/fire/firestore';
import { catchError, from, map, Observable, throwError } from 'rxjs';

import { normalizeRestaurantId } from '../../../shared/restaurant-context';
import {
  CreateMenuItemInput,
  MenuAvailability,
  MenuItem,
  MenuRepository,
  UpdateMenuItemInput,
} from '../domain/menu-item';

interface MenuItemDto {
  readonly id: string;
  readonly restaurantId?: unknown;
  readonly branchId?: unknown;
  readonly name?: unknown;
  readonly description?: unknown;
  readonly category?: unknown;
  readonly categoryId?: unknown;
  readonly price?: unknown;
  readonly availability?: unknown;
  readonly status?: unknown;
  readonly isAvailable?: unknown;
  readonly archived?: unknown;
  readonly createdAt?: unknown;
  readonly updatedAt?: unknown;
}

@Injectable({ providedIn: 'root' })
export class MenuRepositoryImpl extends MenuRepository {
  private readonly firestore = inject(Firestore);
  private readonly injector = inject(Injector);

  watchMenu(restaurantId: string): Observable<readonly MenuItem[]> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return runInInjectionContext(this.injector, () => {
      const menu = collection(this.firestore, `restaurants/${resolvedRestaurantId}/menu`);
      return collectionData(menu, { idField: 'id' }).pipe(
        map((documents) =>
          documents
            .map((document) => toMenuItem(document as MenuItemDto, resolvedRestaurantId))
            .filter((item): item is MenuItem => item !== null && !item.archived)
            .sort((left, right) => left.name.localeCompare(right.name)),
        ),
        catchError((error: unknown) =>
          throwError(() => new Error(this.readableError(error, 'Unable to load the menu.'))),
        ),
      );
    });
  }

  createMenuItem(restaurantId: string, input: CreateMenuItemInput): Observable<MenuItem> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return from(
      runInInjectionContext(this.injector, () =>
        addDoc(collection(this.firestore, `restaurants/${resolvedRestaurantId}/menu`), {
          restaurantId: resolvedRestaurantId,
          name: input.name.trim(),
          description: input.description.trim(),
          category: input.category.trim(),
          price: input.price,
          availability: input.availability,
          status: input.availability,
          isAvailable: input.availability === 'in_stock',
          archived: false,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      ),
    ).pipe(
      map((reference) => ({
        id: reference.id,
        restaurantId: resolvedRestaurantId,
        branchId: null,
        name: input.name.trim(),
        description: input.description.trim(),
        category: input.category.trim(),
        price: input.price,
        availability: input.availability,
        archived: false,
        createdAt: null,
        updatedAt: null,
      })),
      catchError((error: unknown) =>
        throwError(() => new Error(this.readableError(error, 'Unable to create the menu item.'))),
      ),
    );
  }

  updateMenuItem(
    restaurantId: string,
    itemId: string,
    input: UpdateMenuItemInput,
  ): Observable<void> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return from(
      runInInjectionContext(this.injector, () =>
        updateDoc(doc(this.firestore, `restaurants/${resolvedRestaurantId}/menu/${itemId}`), {
          name: input.name.trim(),
          description: input.description.trim(),
          category: input.category.trim(),
          price: input.price,
          availability: input.availability,
          status: input.availability,
          isAvailable: input.availability === 'in_stock',
          updatedAt: serverTimestamp(),
        }),
      ),
    ).pipe(
      map(() => undefined),
      catchError((error: unknown) =>
        throwError(() => new Error(this.readableError(error, 'Unable to update the menu item.'))),
      ),
    );
  }

  archiveMenuItem(restaurantId: string, itemId: string): Observable<void> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return from(
      runInInjectionContext(this.injector, () =>
        updateDoc(doc(this.firestore, `restaurants/${resolvedRestaurantId}/menu/${itemId}`), {
          archived: true,
          availability: 'out_of_stock',
          status: 'out_of_stock',
          isAvailable: false,
          updatedAt: serverTimestamp(),
        }),
      ),
    ).pipe(
      map(() => undefined),
      catchError((error: unknown) =>
        throwError(() => new Error(this.readableError(error, 'Unable to archive the menu item.'))),
      ),
    );
  }

  toggleAvailability(
    restaurantId: string,
    itemId: string,
    availability: MenuAvailability,
  ): Observable<void> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return from(
      runInInjectionContext(this.injector, () =>
        updateDoc(doc(this.firestore, `restaurants/${resolvedRestaurantId}/menu/${itemId}`), {
          availability,
          status: availability,
          isAvailable: availability === 'in_stock',
          updatedAt: serverTimestamp(),
        }),
      ),
    ).pipe(
      map(() => undefined),
      catchError((error: unknown) =>
        throwError(
          () => new Error(this.readableError(error, 'Unable to change menu item availability.')),
        ),
      ),
    );
  }

  private readableError(error: unknown, fallback: string): string {
    if (this.isFirebaseError(error) && error.code === 'permission-denied') {
      return 'You do not have permission to manage this menu.';
    }
    return fallback;
  }

  private isFirebaseError(error: unknown): error is { readonly code: string } {
    return typeof error === 'object' && error !== null && 'code' in error;
  }
}

function toMenuItem(dto: MenuItemDto, fallbackRestaurantId: string): MenuItem | null {
  const restaurantId =
    typeof dto.restaurantId === 'string' ? dto.restaurantId : fallbackRestaurantId;
  if (
    restaurantId !== fallbackRestaurantId ||
    typeof dto.name !== 'string' ||
    typeof dto.price !== 'number'
  ) {
    return null;
  }

  const availability = toAvailability(dto);
  if (!availability) return null;

  return {
    id: dto.id,
    restaurantId,
    branchId: typeof dto.branchId === 'string' ? dto.branchId : null,
    name: dto.name,
    description: typeof dto.description === 'string' ? dto.description : '',
    category:
      typeof dto.category === 'string'
        ? dto.category
        : typeof dto.categoryId === 'string'
          ? dto.categoryId
          : 'Uncategorized',
    price: dto.price,
    availability,
    archived: dto.archived === true,
    createdAt: toDateOrNull(dto.createdAt),
    updatedAt: toDateOrNull(dto.updatedAt),
  };
}

function toAvailability(dto: MenuItemDto): MenuAvailability | null {
  if (dto.availability === 'in_stock' || dto.availability === 'out_of_stock') {
    return dto.availability;
  }
  if (dto.status === 'in_stock' || dto.status === 'out_of_stock') {
    return dto.status;
  }
  if (typeof dto.isAvailable === 'boolean') {
    return dto.isAvailable ? 'in_stock' : 'out_of_stock';
  }
  return null;
}

function toDateOrNull(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const toDate = value.toDate;
    if (typeof toDate === 'function') {
      const date = toDate();
      return date instanceof Date ? date : null;
    }
  }
  return null;
}
