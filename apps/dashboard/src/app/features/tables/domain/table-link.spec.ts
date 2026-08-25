import { buildTableQrUrl } from './table-link';

describe('buildTableQrUrl', () => {
  it('builds the canonical tenant-scoped table deep link', () => {
    expect(
      buildTableQrUrl({
        restaurantId: 'scanserve-demo',
        branchId: 'main-branch',
        tableNo: '12 A',
        secretToken: 'secret+token',
      }),
    ).toBe(
      'https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12+A&token=secret%2Btoken',
    );
  });
});
