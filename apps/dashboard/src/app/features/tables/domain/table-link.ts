export interface TableLinkInput {
  readonly restaurantId: string;
  readonly branchId: string;
  readonly tableNo: string;
  readonly secretToken: string;
}

export const TABLE_QR_BASE_URL = 'https://scanserve.app/menu';

export function buildTableQrUrl(input: TableLinkInput): string {
  const queryParameters = new URLSearchParams({
    tenant: input.restaurantId,
    branch: input.branchId,
    table: input.tableNo,
    token: input.secretToken,
  });
  return `${TABLE_QR_BASE_URL}?${queryParameters.toString()}`;
}
