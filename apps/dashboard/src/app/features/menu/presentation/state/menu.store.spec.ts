import { TestBed } from '@angular/core/testing';
import { Observable, of, ReplaySubject } from 'rxjs';

import {
  CreateMenuItemInput,
  MenuAvailability,
  MenuItem,
  MenuRepository,
  UpdateMenuItemInput,
} from '../../domain/menu-item';
import { MenuStore } from './menu.store';

describe('MenuStore', () => {
  it('projects live menu items into categories and delegates availability changes', () => {
    TestBed.configureTestingModule({
      providers: [MenuStore, { provide: MenuRepository, useClass: FakeMenuRepository }],
    });

    const repository = TestBed.inject(MenuRepository) as FakeMenuRepository;
    const store = TestBed.inject(MenuStore);
    repository.itemsSubject.next([menuItem]);
    store.initialize('restaurant-1');

    expect(store.items()).toEqual([menuItem]);
    expect(store.categories()).toEqual(['Drinks']);

    store.toggleAvailability(menuItem).subscribe();

    expect(repository.lastAvailability).toBe('out_of_stock');
  });
});

const menuItem: MenuItem = {
  id: 'item-1',
  restaurantId: 'restaurant-1',
  branchId: null,
  name: 'Iced coffee',
  description: 'Cold brew with condensed milk',
  category: 'Drinks',
  price: 35000,
  availability: 'in_stock',
  archived: false,
};

class FakeMenuRepository extends MenuRepository {
  readonly itemsSubject = new ReplaySubject<readonly MenuItem[]>(1);
  lastAvailability: MenuAvailability | null = null;

  override watchMenu(_restaurantId: string): Observable<readonly MenuItem[]> {
    return this.itemsSubject.asObservable();
  }

  override createMenuItem(
    _restaurantId: string,
    _input: CreateMenuItemInput,
  ): Observable<MenuItem> {
    return of(menuItem);
  }

  override updateMenuItem(
    _restaurantId: string,
    _itemId: string,
    _input: UpdateMenuItemInput,
  ): Observable<void> {
    return of(undefined);
  }

  override archiveMenuItem(_restaurantId: string, _itemId: string): Observable<void> {
    return of(undefined);
  }

  override toggleAvailability(
    _restaurantId: string,
    _itemId: string,
    availability: MenuAvailability,
  ): Observable<void> {
    this.lastAvailability = availability;
    return of(undefined);
  }
}
