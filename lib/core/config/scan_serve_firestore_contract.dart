abstract final class ScanServeFirestoreContract {
  static const restaurantId = 'scanserve-demo';
  static const branchId = 'main-branch';
  static const tableId = 'table-12';
  static const tableSessionId = 'active-table-session';
  static const customerSessionId = 'active-customer-session';

  static String normalize(String? value, String fallback) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  static String normalizeCustomerSessionId(String? value) =>
      normalize(value, customerSessionId);

  static String canonicalCartId(String? value) =>
      'cart_${normalizeCustomerSessionId(value)}';
}
