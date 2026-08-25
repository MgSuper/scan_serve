import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { Observable, of } from 'rxjs';

import {
  CreateMenuCategoryInput,
  MenuCategory,
  MenuCategoryRepository,
} from '../../domain/menu-category';
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

class FakeMenuCategoryRepository extends MenuCategoryRepository {
  readonly parents: readonly MenuCategory[] = [
    category('mains', 'Mains', null, 10),
    category('drinks', 'Drinks', null, 20),
  ];
  readonly children: readonly MenuCategory[] = [
    category('mains-soups', 'Soups', 'mains', 11),
    category('mains-spicy-noodles', 'Spicy Noodles', 'mains', 12),
  ];
  createdInput: CreateMenuCategoryInput | null = null;

  override watchParentCategories(
    _restaurantId: string,
    _branchId: string,
  ): Observable<readonly MenuCategory[]> {
    return of(this.parents);
  }

  override watchSubCategories(
    _restaurantId: string,
    _branchId: string,
    parentCategoryId: string,
  ): Observable<readonly MenuCategory[]> {
    return of(parentCategoryId === 'mains' ? this.children : []);
  }

  override createCategory(
    _restaurantId: string,
    input: CreateMenuCategoryInput,
  ): Observable<MenuCategory> {
    this.createdInput = input;
    return of(category(input.id, input.name, input.parentCategoryId, input.displayOrder ?? 0));
  }
}

describe('MenuManagementComponent', () => {
  let fixture: ComponentFixture<MenuManagementComponent>;
  let component: MenuManagementComponent;
  let repository: FakeMenuRepository;
  let categoryRepository: FakeMenuCategoryRepository;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MenuManagementComponent],
      providers: [
        FakeMenuRepository,
        { provide: MenuRepository, useExisting: FakeMenuRepository },
        FakeMenuCategoryRepository,
        { provide: MenuCategoryRepository, useExisting: FakeMenuCategoryRepository },
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
    categoryRepository = TestBed.inject(FakeMenuCategoryRepository);
    fixture.detectChanges();
  });

  it('loads live parent categories and cascades to matching child categories', () => {
    expect(component.parentCategories().map((category) => category.id)).toEqual([
      'mains',
      'drinks',
    ]);

    component.openCreate();
    component.onParentCategoryChanged('mains');

    expect(component.subCategories().map((category) => category.name)).toEqual([
      'Soups',
      'Spicy Noodles',
    ]);
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

  it('creates an inline child category when a parent has no children', () => {
    component.openCreate();
    component.form.name = 'Seasonal soda';
    component.form.price = 30000;
    component.onParentCategoryChanged('drinks');
    component.form.customSubCategoryName = 'Seasonal';
    component.save();

    expect(categoryRepository.createdInput).toEqual(
      jasmine.objectContaining({
        id: 'drinks-seasonal',
        branchId: 'branch-7',
        name: 'Seasonal',
        parentCategoryId: 'drinks',
      }),
    );
    expect(repository.createdInput).toEqual(
      jasmine.objectContaining({
        category: 'Drinks',
        categoryId: 'drinks-seasonal',
        categoryName: 'Seasonal',
        parentCategoryId: 'drinks',
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

function category(
  id: string,
  name: string,
  parentCategoryId: string | null,
  displayOrder: number,
): MenuCategory {
  return {
    id,
    restaurantId: 'restaurant-1',
    branchId: 'branch-7',
    name,
    parentCategoryId,
    displayOrder,
    isActive: true,
    archived: false,
  };
}
