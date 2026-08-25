import { Pipe, PipeTransform } from '@angular/core';
import QRCode from 'qrcode';
import { catchError, from, Observable, of, shareReplay } from 'rxjs';

@Pipe({
  name: 'qrCode',
  standalone: true,
  pure: true,
})
export class QrCodePipe implements PipeTransform {
  private readonly cache = new Map<string, Observable<string>>();

  transform(value: string): Observable<string> {
    const cached = this.cache.get(value);
    if (cached) return cached;

    const generated = from(
      QRCode.toDataURL(value, {
        errorCorrectionLevel: 'M',
        margin: 2,
        width: 240,
      }),
    ).pipe(
      catchError(() => of('')),
      shareReplay({ bufferSize: 1, refCount: true }),
    );
    this.cache.set(value, generated);
    return generated;
  }
}
