import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { Observable, of } from 'rxjs';

import {
  CreateMenuItemInput,
  MenuItem,
  MenuRepository,
  UpdateMenuItemInput,
} from '../../domain/menu-item';
import { MenuManagementComponent } from './menu-management.component';

class FakeMenuRepository extends MenuRepository {
  createdInput: CreateMenuItemInput | null = null;

  override watchMenu(_restaurantId: string): Observable<readonly MenuItem[]> {
    return of([]);
  }

  override createMenuItem(_restaurantId: string, input: CreateMenuItemInput): Observable<MenuItem> {
    this.createdInput = input;
    return of({
      id: 'new-item',
      restaurantId: 'restaurant-1',
      branchId: input.branchId ?? null,
      name: input.name,
      description: input.description,
      category: input.category,
      categoryId: input.categoryId,
      categoryName: input.categoryName,
      parentCategoryId: input.parentCategoryId,
      imageUrl: input.imageUrl,
      price: input.price,
      availability: input.availability,
      archived: false,
    });
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
    _availability: 'in_stock' | 'out_of_stock',
  ): Observable<void> {
    return of(undefined);
  }
}

describe('MenuManagementComponent', () => {
  let fixture: ComponentFixture<MenuManagementComponent>;
  let component: MenuManagementComponent;
  let repository: FakeMenuRepository;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MenuManagementComponent],
      providers: [
        FakeMenuRepository,
        { provide: MenuRepository, useExisting: FakeMenuRepository },
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({ restaurantId: 'restaurant-1' })),
            queryParamMap: of(convertToParamMap({ branchId: 'branch-7' })),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(MenuManagementComponent);
    component = fixture.componentInstance;
    repository = TestBed.inject(FakeMenuRepository);
    fixture.detectChanges();
  });

  it('derives child category metadata and active tenant scope for a new item', () => {
    component.openCreate();
    component.form.name = 'Pho ga';
    component.form.description = 'Chicken noodle soup';
    component.form.price = 65000;
    component.onParentCategoryChanged('mains');
    component.onSubCategoryChanged('mains-soups');
    component.save();

    expect(repository.createdInput).toEqual(
      jasmine.objectContaining({
        branchId: 'branch-7',
        category: 'Mains',
        categoryId: 'mains-soups',
        categoryName: 'Soups',
        parentCategoryId: 'mains',
        imageUrl: 'https://placehold.co/640x480/png?text=ScanServe+Dish',
        availability: 'in_stock',
      }),
    );
  });

  it('sets a root category with a null parentCategoryId when no sub-category is selected', () => {
    component.openCreate();
    component.form.name = 'Iced coffee';
    component.form.price = 35000;
    component.onParentCategoryChanged('drinks');
    component.save();

    expect(repository.createdInput).toEqual(
      jasmine.objectContaining({
        branchId: 'branch-7',
        category: 'Drinks',
        categoryId: 'drinks',
        categoryName: 'Drinks',
        parentCategoryId: null,
      }),
    );
  });
});
