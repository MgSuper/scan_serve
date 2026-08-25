import { AsyncPipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { combineLatest, distinctUntilChanged, map } from 'rxjs';
import QRCode from 'qrcode';

import {
  DEFAULT_BRANCH_ID,
  DEFAULT_RESTAURANT_ID,
  normalizeRestaurantId,
} from '../../../../shared/restaurant-context';
import { CreateTableInput, RestaurantTable, TableRepository } from '../../domain/table';
import { TableStore } from '../state/table.store';
import { QrCodePipe } from '../qr-code.pipe';

interface TableForm {
  tableNo: string;
  zone: string;
  capacity: number;
}

@Component({
  selector: 'app-table-management',
  standalone: true,
  imports: [AsyncPipe, FormsModule, QrCodePipe],
  templateUrl: './table-management.component.html',
  styleUrl: './table-management.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [TableStore],
})
export class TableManagementComponent {
  readonly store = inject(TableStore);
  readonly tableRepository = inject(TableRepository);
  readonly form: TableForm = this.emptyForm();
  readonly editorOpen = signal(false);
  readonly DEFAULT_RESTAURANT_ID = DEFAULT_RESTAURANT_ID;
  readonly DEFAULT_BRANCH_ID = DEFAULT_BRANCH_ID;

  activeRestaurantId = DEFAULT_RESTAURANT_ID;
  activeBranchId = DEFAULT_BRANCH_ID;

  private readonly destroyRef = inject(DestroyRef);
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
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(({ restaurantId, branchId }) => {
        this.activeRestaurantId = restaurantId;
        this.activeBranchId = branchId;
        this.store.initialize(restaurantId, branchId);
      });
  }

  openCreate(): void {
    Object.assign(this.form, this.emptyForm());
    this.editorOpen.set(true);
  }

  closeEditor(): void {
    this.editorOpen.set(false);
  }

  create(): void {
    const input: CreateTableInput = {
      branchId: this.activeBranchId,
      tableNo: this.form.tableNo.trim(),
      zone: this.form.zone.trim(),
      capacity: Number(this.form.capacity),
    };
    if (!input.tableNo || !Number.isFinite(input.capacity) || input.capacity < 1) return;

    this.store.create(input).subscribe({
      next: () => {
        this.closeEditor();
        Object.assign(this.form, this.emptyForm());
      },
      error: () => undefined,
    });
  }

  async printQrTag(table: RestaurantTable): Promise<void> {
    const qrDataUrl = await QRCode.toDataURL(table.qrUrl, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 320,
    });
    const printWindow = window.open('', '_blank', 'popup,width=460,height=700');
    if (!printWindow) {
      this.store.error.set('Allow pop-ups to print a QR tag.');
      return;
    }

    const tableNo = escapeHtml(table.tableNo);
    const zone = escapeHtml(table.zone);
    const qrUrl = escapeHtml(table.qrUrl);
    printWindow.document.write(`
      <!doctype html>
      <html>
        <head>
          <title>ScanServe Table ${tableNo}</title>
          <style>
            @page { margin: 12mm; }
            body { font-family: Arial, sans-serif; color: #0f172a; text-align: center; }
            main { width: 100%; }
            img { display: block; width: 320px; max-width: 100%; margin: 18px auto; }
            h1 { margin: 0; font-size: 28px; }
            p { margin: 6px 0; color: #475569; }
            code { display: block; font-size: 9px; overflow-wrap: anywhere; }
          </style>
        </head>
        <body>
          <main>
            <h1>Table ${tableNo}</h1>
            <p>${zone} · Scan to order</p>
            <img src="${qrDataUrl}" alt="QR code for table ${tableNo}" />
            <code>${qrUrl}</code>
          </main>
        </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.focus();
    printWindow.print();
  }

  formatCapacity(capacity: number): string {
    return `${capacity} seat${capacity === 1 ? '' : 's'}`;
  }

  private emptyForm(): TableForm {
    return {
      tableNo: '',
      zone: 'Main dining',
      capacity: 2,
    };
  }
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>'"]/g,
    (character) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        "'": '&#39;',
        '"': '&quot;',
      })[character] ?? character,
  );
}
