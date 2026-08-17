import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { distinctUntilChanged, map, Observable } from 'rxjs';

import { CreateMenuItemInput, MenuAvailability, MenuItem } from '../../domain/menu-item';
import { MenuStore } from '../state/menu.store';

interface MenuForm {
  name: string;
  description: string;
  category: string;
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
  readonly form = {
    name: '',
    description: '',
    category: '',
    price: 0,
    availability: 'in_stock' as MenuAvailability,
  };
  editingId: string | null = null;
  editorOpen = false;

  private readonly route = inject(ActivatedRoute);

  constructor() {
    this.route.paramMap
      .pipe(
        map((params) => params.get('restaurantId') ?? ''),
        distinctUntilChanged(),
        takeUntilDestroyed(),
      )
      .subscribe((restaurantId) => this.store.initialize(restaurantId));
  }

  openCreate(): void {
    this.editingId = null;
    this.form.name = '';
    this.form.description = '';
    this.form.category = '';
    this.form.price = 0;
    this.form.availability = 'in_stock';
    this.editorOpen = true;
  }

  openEdit(item: MenuItem): void {
    this.editingId = item.id;
    this.form.name = item.name;
    this.form.description = item.description;
    this.form.category = item.category;
    this.form.price = item.price;
    this.form.availability = item.availability;
    this.editorOpen = true;
  }

  closeEditor(): void {
    this.editorOpen = false;
    this.editingId = null;
  }

  save(): void {
    const input: CreateMenuItemInput = {
      name: this.form.name,
      description: this.form.description,
      category: this.form.category,
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
}
