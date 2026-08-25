import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { combineLatest, distinctUntilChanged, map, Observable } from 'rxjs';

import {
  DEFAULT_BRANCH_ID,
  DEFAULT_RESTAURANT_ID,
  normalizeRestaurantId,
} from '../../../../shared/restaurant-context';
import { CreateMenuItemInput, MenuAvailability, MenuItem } from '../../domain/menu-item';
import { MenuStore } from '../state/menu.store';

const DEFAULT_IMAGE_URL = 'https://placehold.co/640x480/png?text=ScanServe+Dish';

interface CategoryOption {
  readonly id: string;
  readonly name: string;
  readonly parentCategoryId: string | null;
}

const DEFAULT_CATEGORY_OPTIONS: readonly CategoryOption[] = [
  { id: 'mains', name: 'Mains', parentCategoryId: null },
  { id: 'mains-soups', name: 'Soups', parentCategoryId: 'mains' },
  { id: 'mains-spicy-noodles', name: 'Spicy Noodles', parentCategoryId: 'mains' },
  { id: 'starters', name: 'Starters', parentCategoryId: null },
  { id: 'desserts', name: 'Desserts', parentCategoryId: null },
  { id: 'drinks', name: 'Drinks', parentCategoryId: null },
];

interface MenuForm {
  name: string;
  description: string;
  category: string;
  parentCategoryId: string | null;
  categoryId: string;
  categoryName: string;
  imageUrl: string;
  price: number;
  availability: MenuAvailability;
}

@Component({
  selector: 'app-menu-management',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './menu-management.component.html',
  styleUrl: './menu-management.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [MenuStore],
})
export class MenuManagementComponent {
  readonly store = inject(MenuStore);
  readonly availabilityOptions: readonly MenuAvailability[] = ['in_stock', 'out_of_stock'];
  readonly form: MenuForm = this.emptyForm();
  activeRestaurantId = DEFAULT_RESTAURANT_ID;
  activeBranchId = DEFAULT_BRANCH_ID;
  editingId: string | null = null;
  editorOpen = false;

  private readonly route = inject(ActivatedRoute);

  constructor() {
    combineLatest([this.route.paramMap, this.route.queryParamMap])
      .pipe(
        map(([params, queryParams]) => ({
          restaurantId: normalizeRestaurantId(params.get('restaurantId') ?? ''),
          branchId: queryParams.get('branchId')?.trim() || DEFAULT_BRANCH_ID,
        })),
        distinctUntilChanged(
          (left, right) =>
            left.restaurantId === right.restaurantId && left.branchId === right.branchId,
        ),
        takeUntilDestroyed(),
      )
      .subscribe(({ restaurantId, branchId }) => {
        this.activeRestaurantId = restaurantId;
        this.activeBranchId = branchId;
        this.store.initialize(restaurantId);
      });
  }

  get categoryOptions(): readonly CategoryOption[] {
    const options = new Map(DEFAULT_CATEGORY_OPTIONS.map((option) => [option.id, option]));
    for (const item of this.store.activeItems()) {
      const name = (item.categoryName ?? item.category).trim();
      if (!name) continue;
      const id = (item.categoryId ?? slugify(name)).trim();
      if (!id) continue;
      const parentCategoryId = item.parentCategoryId?.trim() || null;
      if (parentCategoryId && !options.has(parentCategoryId)) {
        options.set(parentCategoryId, {
          id: parentCategoryId,
          name: item.category.trim() || parentCategoryId,
          parentCategoryId: null,
        });
      }
      options.set(id, { id, name, parentCategoryId });
    }
    return [...options.values()].sort((left, right) => left.name.localeCompare(right.name));
  }

  get parentCategoryOptions(): readonly CategoryOption[] {
    return this.categoryOptions.filter((option) => option.parentCategoryId === null);
  }

  childCategoriesFor(parentCategoryId: string | null): readonly CategoryOption[] {
    if (!parentCategoryId) return [];
    return this.categoryOptions.filter((option) => option.parentCategoryId === parentCategoryId);
  }

  openCreate(): void {
    this.editingId = null;
    Object.assign(this.form, this.emptyForm());
    this.editorOpen = true;
  }

  openEdit(item: MenuItem): void {
    this.editingId = item.id;
    const categoryId = item.categoryId ?? slugify(item.categoryName ?? item.category);
    const selectedCategory = this.categoryOptions.find((option) => option.id === categoryId);
    const parentCategoryId =
      item.parentCategoryId ?? selectedCategory?.parentCategoryId ?? selectedCategory?.id ?? null;
    const selectedSubCategoryId =
      selectedCategory?.parentCategoryId === parentCategoryId ? categoryId : '';
    Object.assign(this.form, {
      name: item.name,
      description: item.description,
      category: item.category,
      parentCategoryId,
      categoryId: selectedSubCategoryId,
      categoryName: item.categoryName ?? item.category,
      imageUrl: item.imageUrl ?? '',
      price: item.price,
      availability: item.availability,
    });
    this.activeBranchId = item.branchId ?? this.activeBranchId;
    this.editorOpen = true;
  }

  onParentCategoryChanged(parentCategoryId: string | null): void {
    const parent = this.categoryOptions.find((option) => option.id === parentCategoryId);
    this.form.parentCategoryId = parent?.parentCategoryId
      ? parent.parentCategoryId
      : (parent?.id ?? null);
    this.form.categoryName = parent?.name ?? '';
    this.form.category = this.form.categoryName;

    const children = this.childCategoriesFor(parent?.id ?? null);
    if (children.length === 0) {
      this.form.categoryId = parent?.id ?? '';
      return;
    }

    if (!children.some((child) => child.id === this.form.categoryId)) {
      this.form.categoryId = '';
    }
  }

  onSubCategoryChanged(categoryId: string): void {
    const parent = this.categoryOptions.find((option) => option.id === this.form.parentCategoryId);
    if (!categoryId) {
      this.form.categoryId = parent?.id ?? '';
      this.form.categoryName = parent?.name ?? '';
      this.form.category = parent?.name ?? '';
      return;
    }

    const child = this.childCategoriesFor(this.form.parentCategoryId).find(
      (option) => option.id === categoryId,
    );
    if (!child) return;
    this.form.categoryId = child.id;
    this.form.categoryName = child.name;
    this.form.category = parent?.name ?? this.form.category;
  }

  closeEditor(): void {
    this.editorOpen = false;
    this.editingId = null;
  }

  save(): void {
    const selectedCategory = this.categoryOptions.find(
      (option) => option.id === (this.form.categoryId || this.form.parentCategoryId),
    );
    const categoryName = (
      this.form.categoryName.trim() ||
      selectedCategory?.name ||
      this.form.category.trim()
    ).trim();
    if (!this.form.name.trim() || !categoryName) return;

    const categoryId = (
      this.form.categoryId.trim() ||
      this.form.parentCategoryId?.trim() ||
      slugify(categoryName)
    ).trim();
    const parentCategory = this.categoryOptions.find(
      (option) => option.id === this.form.parentCategoryId,
    );
    const compatibilityCategory = (
      this.form.category.trim() ||
      parentCategory?.name ||
      categoryName
    ).trim();
    const hasSubCategory = Boolean(
      this.form.parentCategoryId &&
      this.childCategoriesFor(this.form.parentCategoryId).some(
        (child) => child.id === this.form.categoryId,
      ),
    );
    const input: CreateMenuItemInput = {
      name: this.form.name,
      description: this.form.description,
      category: compatibilityCategory,
      branchId: this.activeBranchId,
      categoryId,
      categoryName,
      parentCategoryId: hasSubCategory ? this.form.parentCategoryId : null,
      imageUrl: this.form.imageUrl.trim() || DEFAULT_IMAGE_URL,
      price: Number(this.form.price),
      availability: this.form.availability,
    };
    const operation: Observable<unknown> = this.editingId
      ? this.store.update(this.editingId, input)
      : this.store.create(input);
    operation.subscribe({ next: () => this.closeEditor(), error: () => undefined });
  }

  archive(item: MenuItem): void {
    this.store.archive(item.id).subscribe({ error: () => undefined });
  }

  toggleAvailability(item: MenuItem): void {
    this.store.toggleAvailability(item).subscribe({ error: () => undefined });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(value);
  }

  private emptyForm(): MenuForm {
    return {
      name: '',
      description: '',
      category: '',
      parentCategoryId: null,
      categoryId: '',
      categoryName: '',
      imageUrl: '',
      price: 0,
      availability: 'in_stock',
    };
  }
}

function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
