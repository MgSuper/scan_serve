import { computed, DestroyRef, inject, Injectable, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { catchError, finalize, Observable, Subscription, take, throwError } from 'rxjs';

import {
  CreateMenuItemInput,
  MenuAvailability,
  MenuItem,
  MenuRepository,
  UpdateMenuItemInput,
} from '../../domain/menu-item';

@Injectable()
export class MenuStore {
  private readonly destroyRef = inject(DestroyRef);
  private readonly repository = inject(MenuRepository);
  private subscription: Subscription | null = null;
  private restaurantId = '';

  readonly items = signal<readonly MenuItem[]>([]);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly savingIds = signal<ReadonlySet<string>>(new Set<string>());

  readonly categories = computed(() =>
    [...new Set(this.items().map((item) => item.category))].sort((left, right) =>
      left.localeCompare(right),
    ),
  );

  initialize(restaurantId: string): void {
    if (!restaurantId.trim()) {
      this.error.set('A restaurantId is required to manage the menu.');
      return;
    }
    this.restaurantId = restaurantId;
    this.subscription?.unsubscribe();
    this.loading.set(true);
    this.error.set(null);
    this.subscription = this.repository
      .watchMenu(restaurantId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (items) => {
          this.items.set(items);
          this.loading.set(false);
          this.error.set(null);
        },
        error: (error: unknown) => {
          this.loading.set(false);
          this.error.set(this.messageFor(error, 'Unable to load the menu.'));
        },
      });
  }

  create(input: CreateMenuItemInput): Observable<MenuItem> {
    this.validate(input);
    return this.track(this.repository.createMenuItem(this.restaurantId, input));
  }

  update(itemId: string, input: UpdateMenuItemInput): Observable<void> {
    this.validate(input);
    return this.track(this.repository.updateMenuItem(this.restaurantId, itemId, input), itemId);
  }

  archive(itemId: string): Observable<void> {
    return this.track(this.repository.archiveMenuItem(this.restaurantId, itemId), itemId);
  }

  toggleAvailability(item: MenuItem): Observable<void> {
    const availability: MenuAvailability =
      item.availability === 'in_stock' ? 'out_of_stock' : 'in_stock';
    return this.track(
      this.repository.toggleAvailability(this.restaurantId, item.id, availability),
      item.id,
    );
  }

  isSaving(itemId: string): boolean {
    return this.savingIds().has(itemId);
  }

  private track<T>(operation: Observable<T>, itemId?: string): Observable<T> {
    this.saving.set(true);
    if (itemId) {
      this.savingIds.update((ids) => new Set(ids).add(itemId));
    }
    this.error.set(null);
    return operation.pipe(
      take(1),
      takeUntilDestroyed(this.destroyRef),
      catchError((error: unknown) => {
        this.error.set(this.messageFor(error, 'Unable to save the menu item.'));
        return throwError(() => error);
      }),
      finalize(() => {
        this.saving.set(false);
        if (itemId) {
          this.savingIds.update((ids) => {
            const next = new Set(ids);
            next.delete(itemId);
            return next;
          });
        }
      }),
    );
  }

  private validate(input: CreateMenuItemInput | UpdateMenuItemInput): void {
    if (!input.name.trim() || !input.category.trim()) {
      throw new Error('Name and category are required.');
    }
    if (!Number.isFinite(input.price) || input.price < 0) {
      throw new Error('Price must be a non-negative number.');
    }
  }

  private messageFor(error: unknown, fallback: string): string {
    return error instanceof Error ? error.message : fallback;
  }
}
