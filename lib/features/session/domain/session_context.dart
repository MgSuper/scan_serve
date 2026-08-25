import 'package:scan_serve/core/config/scan_serve_firestore_contract.dart';

class SessionContext {
  const SessionContext({
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.tableSessionId,
    required this.customerSessionId,
    required this.tableToken,
  });

  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;
  final String tableToken;

  factory SessionContext.fromQueryParameters(Map<String, String> parameters) {
    final restaurantId =
        _firstNonEmpty(parameters, const ['restaurantId', 'tenant']) ??
        ScanServeFirestoreContract.restaurantId;
    final branchId =
        _firstNonEmpty(parameters, const ['branchId', 'branch']) ??
        ScanServeFirestoreContract.branchId;
    final tableId =
        _firstNonEmpty(parameters, const ['tableId', 'table']) ??
        ScanServeFirestoreContract.tableId;
    final tableToken = _firstNonEmpty(parameters, const ['token']) ?? '';
    final tableSessionId =
        _firstNonEmpty(parameters, const ['tableSessionId']) ??
        _derivedSessionId(
          'table',
          restaurantId,
          branchId,
          tableId,
          tableToken,
          fallback: ScanServeFirestoreContract.tableSessionId,
        );
    final customerSessionId =
        _firstNonEmpty(parameters, const ['customerSessionId']) ??
        _derivedSessionId(
          'customer',
          restaurantId,
          branchId,
          tableId,
          tableToken,
          fallback: ScanServeFirestoreContract.customerSessionId,
        );

    return SessionContext(
      restaurantId: restaurantId,
      branchId: branchId,
      tableId: tableId,
      tableSessionId: tableSessionId,
      customerSessionId: customerSessionId,
      tableToken: tableToken,
    );
  }

  Map<String, String> toQueryParameters() {
    final parameters = <String, String>{
      'restaurantId': restaurantId,
      'branchId': branchId,
      'tableId': tableId,
      'tableSessionId': tableSessionId,
      'customerSessionId': customerSessionId,
    };
    if (tableToken.isNotEmpty) parameters['token'] = tableToken;
    return parameters;
  }

  String get scopeKey => '$restaurantId/$branchId/$tableId/$tableSessionId';

  static String? _firstNonEmpty(
    Map<String, String> parameters,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = parameters[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _derivedSessionId(
    String prefix,
    String restaurantId,
    String branchId,
    String tableId,
    String token, {
    required String fallback,
  }) {
    if (token.isEmpty &&
        restaurantId == ScanServeFirestoreContract.restaurantId &&
        branchId == ScanServeFirestoreContract.branchId &&
        tableId == ScanServeFirestoreContract.tableId) {
      return fallback;
    }
    final normalized =
        '$restaurantId-$branchId-$tableId-${token.isEmpty ? 'default' : token}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$prefix-session-${normalized.replaceAll(RegExp(r'^-+|-+$'), '')}';
  }
}
