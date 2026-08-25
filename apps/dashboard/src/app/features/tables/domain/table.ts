import { Observable } from 'rxjs';

export const TABLE_STATUSES = ['AVAILABLE', 'OCCUPIED', 'INACTIVE'] as const;
export type TableStatus = (typeof TABLE_STATUSES)[number];

export interface RestaurantTable {
  readonly id: string;
  readonly restaurantId: string;
  readonly branchId: string;
  readonly tableNo: string;
  readonly zone: string;
  readonly capacity: number;
  readonly qrUrl: string;
  readonly secretToken: string;
  readonly status: TableStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface CreateTableInput {
  readonly branchId?: string | null;
  readonly tableNo: string;
  readonly zone: string;
  readonly capacity: number;
}

export abstract class TableRepository {
  abstract watchTables(
    restaurantId: string,
    branchId: string,
  ): Observable<readonly RestaurantTable[]>;

  abstract createTable(restaurantId: string, input: CreateTableInput): Observable<RestaurantTable>;
}
