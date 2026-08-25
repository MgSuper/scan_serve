import { DestroyRef, inject, Injectable, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { catchError, finalize, Observable, throwError } from 'rxjs';

import { DEFAULT_BRANCH_ID, normalizeRestaurantId } from '../../../../shared/restaurant-context';
import { CreateTableInput, RestaurantTable, TableRepository } from '../../domain/table';

@Injectable()
export class TableStore {
  readonly tables = signal<readonly RestaurantTable[]>([]);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);

  private readonly destroyRef = inject(DestroyRef);
  private readonly repository = inject(TableRepository);
  private initializedScope = '';
  private restaurantId = '';
  private branchId = DEFAULT_BRANCH_ID;

  initialize(restaurantId: string, branchId: string): void {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const resolvedBranchId = branchId.trim() || DEFAULT_BRANCH_ID;
    const scope = `${resolvedRestaurantId}:${resolvedBranchId}`;
    if (scope === this.initializedScope) return;

    this.initializedScope = scope;
    this.restaurantId = resolvedRestaurantId;
    this.branchId = resolvedBranchId;
    this.tables.set([]);
    this.loading.set(true);
    this.error.set(null);

    this.repository
      .watchTables(resolvedRestaurantId, resolvedBranchId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (tables) => {
          this.tables.set(tables);
          this.loading.set(false);
          this.error.set(null);
        },
        error: (error: unknown) => {
          this.tables.set([]);
          this.loading.set(false);
          this.error.set(error instanceof Error ? error.message : 'Unable to load tables.');
        },
      });
  }

  create(input: CreateTableInput): Observable<RestaurantTable> {
    this.saving.set(true);
    this.error.set(null);
    return this.repository
      .createTable(this.restaurantId, {
        ...input,
        branchId: this.branchId,
      })
      .pipe(
        finalize(() => this.saving.set(false)),
        catchError((error: unknown) => {
          this.error.set(error instanceof Error ? error.message : 'Unable to create the table.');
          return throwError(() => error);
        }),
      );
  }
}
