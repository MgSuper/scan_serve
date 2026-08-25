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
import { CreateTableInput, RestaurantTable, TableRepository, TableStatus } from '../domain/table';
import { buildTableQrUrl } from '../domain/table-link';

interface TableDto {
  readonly id: string;
  readonly restaurantId?: unknown;
  readonly branchId?: unknown;
  readonly tableNo?: unknown;
  readonly zone?: unknown;
  readonly capacity?: unknown;
  readonly qrUrl?: unknown;
  readonly secretToken?: unknown;
  readonly status?: unknown;
  readonly createdAt?: unknown;
  readonly updatedAt?: unknown;
}

@Injectable()
export class TableRepositoryImpl extends TableRepository {
  private readonly firestore = inject(Firestore);
  private readonly injector = inject(Injector);

  watchTables(restaurantId: string, branchId: string): Observable<readonly RestaurantTable[]> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const resolvedBranchId = branchId.trim() || DEFAULT_BRANCH_ID;
    const path = `restaurants/${resolvedRestaurantId}/tables`;

    return runInInjectionContext(this.injector, () => {
      return new Observable<TableDto[]>((observer) => {
        const tableQuery = query(
          collection(this.firestore, path),
          where('branchId', '==', resolvedBranchId),
        );
        const unsubscribe = onSnapshot(
          tableQuery,
          (snapshot) => {
            observer.next(
              snapshot.docs.map(
                (snapshotDocument) =>
                  ({ id: snapshotDocument.id, ...snapshotDocument.data() }) as TableDto,
              ),
            );
          },
          (error) => observer.error(error),
        );
        return () => unsubscribe();
      }).pipe(
        map((documents) =>
          documents
            .map((document) => toRestaurantTable(document, resolvedRestaurantId, resolvedBranchId))
            .filter((table): table is RestaurantTable => table !== null)
            .sort(compareTables),
        ),
        startWith([] as readonly RestaurantTable[]),
        catchError((error: unknown) => {
          console.error('[Firestore Table Stream Error]', error);
          return of([] as readonly RestaurantTable[]);
        }),
      );
    });
  }

  createTable(restaurantId: string, input: CreateTableInput): Observable<RestaurantTable> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const resolvedBranchId = input.branchId?.trim() || DEFAULT_BRANCH_ID;
    const tableNo = input.tableNo.trim();
    const zone = input.zone.trim() || 'Main dining';
    const capacity = Math.max(1, Math.trunc(input.capacity));
    const secretToken = createSecretToken();
    const qrUrl = buildTableQrUrl({
      restaurantId: resolvedRestaurantId,
      branchId: resolvedBranchId,
      tableNo,
      secretToken,
    });

    return from(
      runInInjectionContext(this.injector, async () => {
        const tableReference = doc(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/tables`),
        );
        const timestamp = serverTimestamp();
        await setDoc(tableReference, {
          id: tableReference.id,
          restaurantId: resolvedRestaurantId,
          branchId: resolvedBranchId,
          tableNo,
          zone,
          capacity,
          qrUrl,
          secretToken,
          status: 'AVAILABLE',
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        return tableReference;
      }),
    ).pipe(
      map((reference) => ({
        id: reference.id,
        restaurantId: resolvedRestaurantId,
        branchId: resolvedBranchId,
        tableNo,
        zone,
        capacity,
        qrUrl,
        secretToken,
        status: 'AVAILABLE' as const,
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
      catchError((error: unknown) =>
        throwError(() => new Error(readableError(error, 'Unable to create the table.'))),
      ),
    );
  }
}

function toRestaurantTable(
  dto: TableDto,
  fallbackRestaurantId: string,
  fallbackBranchId: string,
): RestaurantTable | null {
  const tableNo = asNonEmptyString(dto.tableNo);
  const zone = asNonEmptyString(dto.zone) ?? 'Main dining';
  const qrUrl = asNonEmptyString(dto.qrUrl);
  const secretToken = asNonEmptyString(dto.secretToken);
  const capacity = asPositiveInteger(dto.capacity);
  if (!tableNo || !qrUrl || !secretToken || !capacity) return null;

  const status = asTableStatus(dto.status);
  return {
    id: dto.id,
    restaurantId: asNonEmptyString(dto.restaurantId) ?? fallbackRestaurantId,
    branchId: asNonEmptyString(dto.branchId) ?? fallbackBranchId,
    tableNo,
    zone,
    capacity,
    qrUrl,
    secretToken,
    status,
    createdAt: asDate(dto.createdAt),
    updatedAt: asDate(dto.updatedAt),
  };
}

function createSecretToken(): string {
  const cryptoApi = globalThis.crypto;
  if (typeof cryptoApi?.randomUUID === 'function') return cryptoApi.randomUUID();
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 14)}`;
}

function asNonEmptyString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function asPositiveInteger(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value > 0
    ? Math.trunc(value)
    : null;
}

function asTableStatus(value: unknown): TableStatus {
  return value === 'OCCUPIED' || value === 'INACTIVE' ? value : 'AVAILABLE';
}

function asDate(value: unknown): Date {
  if (value instanceof Date) return value;
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const toDate = (value as { readonly toDate?: unknown }).toDate;
    if (typeof toDate === 'function') {
      const date = toDate.call(value);
      if (date instanceof Date) return date;
    }
  }
  return new Date();
}

function compareTables(left: RestaurantTable, right: RestaurantTable): number {
  const leftNumber = Number(left.tableNo);
  const rightNumber = Number(right.tableNo);
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber) && leftNumber !== rightNumber) {
    return leftNumber - rightNumber;
  }
  return left.tableNo.localeCompare(right.tableNo, undefined, { numeric: true });
}

function readableError(error: unknown, fallback: string): string {
  if (typeof error === 'object' && error !== null && 'code' in error) {
    const code = (error as { readonly code?: unknown }).code;
    if (code === 'permission-denied') return 'You do not have permission to manage tables.';
  }
  return fallback;
}
