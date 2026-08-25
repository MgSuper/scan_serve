import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import {
  combineLatest,
  distinctUntilChanged,
  map,
  Observable,
  Subscription,
  switchMap,
} from 'rxjs';

import {
  DEFAULT_BRANCH_ID,
  DEFAULT_RESTAURANT_ID,
  normalizeRestaurantId,
} from '../../../../shared/restaurant-context';
import {
  CreateMenuCategoryInput,
  MenuCategory,
  MenuCategoryRepository,
} from '../../domain/menu-category';
import { CreateMenuItemInput, MenuAvailability, MenuItem } from '../../domain/menu-item';
import { MenuStore } from '../state/menu.store';

const DEFAULT_IMAGE_URL = 'https://placehold.co/640x480/png?text=ScanServe+Dish';

interface MenuForm {
  name: string;
  description: string;
  category: string;
  parentCategorySelectionId: string | null;
  subCategorySelectionId: string;
  categoryId: string;
  categoryName: string;
  parentCategoryId: string | null;
  customSubCategoryName: string;
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
  readonly categoryRepository = inject(MenuCategoryRepository);
  readonly availabilityOptions: readonly MenuAvailability[] = ['in_stock', 'out_of_stock'];
  readonly parentCategories = signal<readonly MenuCategory[]>([]);
  readonly subCategories = signal<readonly MenuCategory[]>([]);
  readonly categoriesLoading = signal(false);
  readonly categoryError = signal<string | null>(null);
  readonly form: MenuForm = this.emptyForm();
  activeRestaurantId = DEFAULT_RESTAURANT_ID;
  activeBranchId = DEFAULT_BRANCH_ID;
  editingId: string | null = null;
  editorOpen = false;

  private readonly destroyRef = inject(DestroyRef);
  private readonly route = inject(ActivatedRoute);
  private parentSubscription: Subscription | null = null;
  private subCategorySubscription: Subscription | null = null;

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
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(({ restaurantId, branchId }) => {
        this.activeRestaurantId = restaurantId;
        this.activeBranchId = branchId;
        this.store.initialize(restaurantId);
        this.watchParentCategories();
      });
  }

  openCreate(): void {
    this.editingId = null;
    Object.assign(this.form, this.emptyForm());
    this.subCategories.set([]);
    this.editorOpen = true;
  }

  openEdit(item: MenuItem): void {
    this.editingId = item.id;
    const categoryId = item.categoryId ?? slugify(item.categoryName ?? item.category);
    const parentCategorySelectionId = item.parentCategoryId ?? categoryId;
    const subCategorySelectionId = item.parentCategoryId ? categoryId : '';
    Object.assign(this.form, {
      name: item.name,
      description: item.description,
      category: item.category,
      parentCategorySelectionId,
      subCategorySelectionId,
      categoryId,
      categoryName: item.categoryName ?? item.category,
      parentCategoryId: item.parentCategoryId ?? null,
      customSubCategoryName: '',
      imageUrl: item.imageUrl ?? '',
      price: item.price,
      availability: item.availability,
    });
    this.activeBranchId = item.branchId ?? this.activeBranchId;
    this.editorOpen = true;
    this.watchSubCategories(parentCategorySelectionId);
  }

  onParentCategoryChanged(parentCategoryId: string | null): void {
    const parent = this.parentCategories().find((category) => category.id === parentCategoryId);
    this.form.parentCategorySelectionId = parent?.id ?? null;
    this.form.subCategorySelectionId = '';
    this.form.customSubCategoryName = '';
    this.form.category = parent?.name ?? '';
    this.form.categoryId = parent?.id ?? '';
    this.form.categoryName = parent?.name ?? '';
    this.form.parentCategoryId = null;
    this.watchSubCategories(parent?.id ?? null);
  }

  onSubCategoryChanged(categoryId: string): void {
    const parent = this.parentCategories().find(
      (category) => category.id === this.form.parentCategorySelectionId,
    );
    if (!categoryId) {
      this.form.subCategorySelectionId = '';
      this.form.category = parent?.name ?? '';
      this.form.categoryId = parent?.id ?? '';
      this.form.categoryName = parent?.name ?? '';
      this.form.parentCategoryId = null;
      return;
    }

    const child = this.subCategories().find((category) => category.id === categoryId);
    if (!child || !parent) return;
    this.form.subCategorySelectionId = child.id;
    this.form.category = parent.name;
    this.form.categoryId = child.id;
    this.form.categoryName = child.name;
    this.form.parentCategoryId = parent.id;
  }

  closeEditor(): void {
    this.editorOpen = false;
    this.editingId = null;
  }

  save(): void {
    const parent = this.parentCategories().find(
      (category) => category.id === this.form.parentCategorySelectionId,
    );
    if (!this.form.name.trim() || !parent) return;

    const child = this.subCategories().find(
      (category) => category.id === this.form.subCategorySelectionId,
    );
    const customSubCategoryName = this.form.customSubCategoryName.trim();
    const isNewCustomSubCategory = !child && customSubCategoryName.length > 0;
    const categoryId =
      child?.id ??
      (isNewCustomSubCategory ? `${parent.id}-${slugify(customSubCategoryName)}` : parent.id);
    const categoryName =
      child?.name ?? (isNewCustomSubCategory ? customSubCategoryName : parent.name);
    const parentCategoryId = child || isNewCustomSubCategory ? parent.id : null;
    if (!categoryId || !categoryName) return;

    const input: CreateMenuItemInput = {
      name: this.form.name,
      description: this.form.description,
      category: parent.name,
      branchId: this.activeBranchId,
      categoryId,
      categoryName,
      parentCategoryId,
      imageUrl: this.form.imageUrl.trim() || DEFAULT_IMAGE_URL,
      price: Number(this.form.price),
      availability: this.form.availability,
    };
    const saveMenuItem = (): Observable<unknown> =>
      this.editingId ? this.store.update(this.editingId, input) : this.store.create(input);
    const operation = isNewCustomSubCategory
      ? this.createInlineSubCategory(parent, customSubCategoryName).pipe(
          switchMap(() => saveMenuItem()),
        )
      : saveMenuItem();
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

  private watchParentCategories(): void {
    this.parentSubscription?.unsubscribe();
    this.parentCategories.set([]);
    this.categoryError.set(null);
    this.categoriesLoading.set(true);
    this.parentSubscription = this.categoryRepository
      .watchParentCategories(this.activeRestaurantId, this.activeBranchId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (categories) => {
          this.parentCategories.set(categories);
          this.categoriesLoading.set(false);
        },
        error: (error: unknown) => {
          this.parentCategories.set([]);
          this.categoriesLoading.set(false);
          this.categoryError.set(
            error instanceof Error ? error.message : 'Unable to load categories.',
          );
        },
      });
  }

  private watchSubCategories(parentCategoryId: string | null): void {
    this.subCategorySubscription?.unsubscribe();
    this.subCategories.set([]);
    if (!parentCategoryId) return;

    this.categoriesLoading.set(true);
    this.subCategorySubscription = this.categoryRepository
      .watchSubCategories(this.activeRestaurantId, this.activeBranchId, parentCategoryId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (categories) => {
          this.subCategories.set(categories);
          this.categoriesLoading.set(false);
        },
        error: (error: unknown) => {
          this.subCategories.set([]);
          this.categoriesLoading.set(false);
          this.categoryError.set(
            error instanceof Error ? error.message : 'Unable to load sub-categories.',
          );
        },
      });
  }

  private createInlineSubCategory(parent: MenuCategory, name: string): Observable<MenuCategory> {
    const input: CreateMenuCategoryInput = {
      id: `${parent.id}-${slugify(name)}`,
      branchId: this.activeBranchId,
      name,
      parentCategoryId: parent.id,
      displayOrder: this.subCategories().length,
    };
    return this.categoryRepository.createCategory(this.activeRestaurantId, input);
  }

  private emptyForm(): MenuForm {
    return {
      name: '',
      description: '',
      category: '',
      parentCategorySelectionId: null,
      subCategorySelectionId: '',
      categoryId: '',
      categoryName: '',
      parentCategoryId: null,
      customSubCategoryName: '',
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
