import { TestBed } from '@angular/core/testing';
import { Observable, of } from 'rxjs';

import { CreateTableInput, RestaurantTable, TableRepository } from '../../domain/table';
import { TableStore } from './table.store';

class FakeTableRepository extends TableRepository {
  readonly table: RestaurantTable = {
    id: 'table-12',
    restaurantId: 'scanserve-demo',
    branchId: 'main-branch',
    tableNo: '12',
    zone: 'Main dining',
    capacity: 4,
    qrUrl:
      'https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12&token=test',
    secretToken: 'test',
    status: 'AVAILABLE',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
  lastInput: CreateTableInput | null = null;

  override watchTables(): Observable<readonly RestaurantTable[]> {
    return of([this.table]);
  }

  override createTable(
    _restaurantId: string,
    input: CreateTableInput,
  ): Observable<RestaurantTable> {
    this.lastInput = input;
    return of(this.table);
  }
}

describe('TableStore', () => {
  it('loads live rows and forces creation to the active branch', () => {
    TestBed.configureTestingModule({
      providers: [TableStore, { provide: TableRepository, useClass: FakeTableRepository }],
    });
    const store = TestBed.inject(TableStore);
    const repository = TestBed.inject(TableRepository) as FakeTableRepository;

    store.initialize('scanserve-demo', 'main-branch');
    expect(store.tables()).toEqual([repository.table]);
    expect(store.loading()).toBeFalse();

    store
      .create({ tableNo: '13', zone: 'Patio', capacity: 2, branchId: 'other-branch' })
      .subscribe();
    expect(repository.lastInput).toEqual({
      tableNo: '13',
      zone: 'Patio',
      capacity: 2,
      branchId: 'main-branch',
    });
  });
});
