import { firstValueFrom } from 'rxjs';

import { QrCodePipe } from './qr-code.pipe';

describe('QrCodePipe', () => {
  it('renders a QR data URL for a table deep link', async () => {
    const dataUrl = await firstValueFrom(
      new QrCodePipe().transform(
        'https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12&token=test-token',
      ),
    );

    expect(dataUrl).toMatch(/^data:image\/png;base64,/);
  });
});
