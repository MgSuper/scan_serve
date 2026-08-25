import { inject, Injectable, Injector, runInInjectionContext } from '@angular/core';
import {
  collection,
  doc,
  Firestore,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from '@angular/fire/firestore';
import { catchError, from, map, Observable, of, startWith, throwError } from 'rxjs';

import { DEFAULT_BRANCH_ID, normalizeRestaurantId } from '../../../shared/restaurant-context';
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
  readonly categoryName?: unknown;
  readonly imageUrl?: unknown;
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
      return new Observable<MenuItemDto[]>((observer) => {
        const menuQuery = query(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/menu`),
        );

        const unsubscribe = onSnapshot(
          menuQuery,
          (snapshot) => {
            const documents = snapshot.docs.map(
              (snapshotDocument) =>
                ({ id: snapshotDocument.id, ...snapshotDocument.data() }) as MenuItemDto,
            );
            observer.next(documents);
          },
          (error) => observer.error(error),
        );

        return () => unsubscribe();
      }).pipe(
        map((documents) =>
          documents
            .map((document) => toMenuItem(document, resolvedRestaurantId))
            .filter((item): item is MenuItem => item !== null)
            .sort((left, right) => left.name.localeCompare(right.name)),
        ),
        startWith([] as readonly MenuItem[]),
        catchError((error: unknown) => {
          console.error('[Firestore Menu Stream Error]', error);
          return of([] as readonly MenuItem[]);
        }),
      );
    });
  }

  createMenuItem(restaurantId: string, input: CreateMenuItemInput): Observable<MenuItem> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return from(
      runInInjectionContext(this.injector, async () => {
        const timestamp = serverTimestamp();
        const restaurantReference = doc(this.firestore, `restaurants/${resolvedRestaurantId}`);
        const branchReference = doc(
          this.firestore,
          `restaurants/${resolvedRestaurantId}/branches/${DEFAULT_BRANCH_ID}`,
        );
        const menuReference = doc(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/menu`),
        );
        await setDoc(
          restaurantReference,
          {
            id: resolvedRestaurantId,
            name: resolvedRestaurantId,
            defaultBranchId: DEFAULT_BRANCH_ID,
            isActive: true,
            createdAt: timestamp,
            updatedAt: timestamp,
          },
          { merge: true },
        );
        await setDoc(
          branchReference,
          {
            id: DEFAULT_BRANCH_ID,
            restaurantId: resolvedRestaurantId,
            name: DEFAULT_BRANCH_ID,
            isActive: true,
            createdAt: timestamp,
            updatedAt: timestamp,
          },
          { merge: true },
        );
        await setDoc(menuReference, {
          id: menuReference.id,
          restaurantId: resolvedRestaurantId,
          branchId: DEFAULT_BRANCH_ID,
          name: input.name.trim(),
          description: input.description.trim(),
          category: input.category.trim(),
          categoryId: input.categoryId?.trim() || null,
          categoryName: input.categoryName?.trim() || input.category.trim(),
          imageUrl: input.imageUrl?.trim() || null,
          price: input.price,
          availability: input.availability,
          status: input.availability,
          isAvailable: input.availability === 'in_stock',
          archived: false,
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        return menuReference;
      }),
    ).pipe(
      map((reference) => ({
        id: reference.id,
        restaurantId: resolvedRestaurantId,
        branchId: DEFAULT_BRANCH_ID,
        name: input.name.trim(),
        description: input.description.trim(),
        category: input.category.trim(),
        categoryId: input.categoryId?.trim() || null,
        categoryName: input.categoryName?.trim() || input.category.trim(),
        imageUrl: input.imageUrl?.trim() || null,
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
          categoryId: input.categoryId?.trim() || null,
          categoryName: input.categoryName?.trim() || input.category.trim(),
          imageUrl: input.imageUrl?.trim() || null,
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
  // Gracefully fallback to the parent path restaurantId if missing or mismatched
  const restaurantId =
    typeof dto.restaurantId === 'string' && dto.restaurantId.trim().length > 0
      ? dto.restaurantId
      : fallbackRestaurantId;

  // Basic validation for mandatory UI fields
  if (typeof dto.name !== 'string' || typeof dto.price !== 'number') {
    return null;
  }

  const availability = toAvailability(dto);

  return {
    id: dto.id,
    restaurantId,
    branchId: typeof dto.branchId === 'string' ? dto.branchId : null,
    name: dto.name,
    description: typeof dto.description === 'string' ? dto.description : '',
    category:
      typeof dto.categoryName === 'string' && dto.categoryName.trim().length > 0
        ? dto.categoryName
        : typeof dto.category === 'string' && dto.category.trim().length > 0
          ? dto.category
          : typeof dto.categoryId === 'string' && dto.categoryId.trim().length > 0
            ? dto.categoryId
            : 'Uncategorized',
    categoryId: typeof dto.categoryId === 'string' ? dto.categoryId : null,
    categoryName: typeof dto.categoryName === 'string' ? dto.categoryName : null,
    imageUrl: typeof dto.imageUrl === 'string' ? dto.imageUrl : null,
    price: dto.price,
    availability,
    archived: dto.archived === true,
    createdAt: toDateOrDefault(dto.createdAt),
    updatedAt: toDateOrDefault(dto.updatedAt),
  };
}

function toAvailability(dto: MenuItemDto): MenuAvailability {
  if (dto.availability === 'in_stock' || dto.availability === 'out_of_stock') {
    return dto.availability;
  }
  if (dto.status === 'in_stock' || dto.status === 'out_of_stock') {
    return dto.status;
  }
  if (typeof dto.isAvailable === 'boolean') {
    return dto.isAvailable ? 'in_stock' : 'out_of_stock';
  }
  return 'in_stock';
}

function toDateOrDefault(value: unknown): Date {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }

  if (typeof value === 'number' && !Number.isNaN(value)) {
    return new Date(value);
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }

  if (typeof value === 'object' && value !== null) {
    const candidate = value as Record<string, unknown>;
    if (typeof candidate['toDate'] === 'function') {
      try {
        const date = (candidate['toDate'] as () => unknown)();
        if (date instanceof Date && !Number.isNaN(date.getTime())) return date;
      } catch {
        // Fallback if toMillis or internal property is missing
      }
    }
    if (typeof candidate['seconds'] === 'number') {
      return new Date(candidate['seconds'] * 1000);
    }
  }

  return new Date();
}
