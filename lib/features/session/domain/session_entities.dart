import 'package:scan_serve/shared/domain/audit_metadata.dart';

enum TableSessionStatus { active, completed, expired }
enum CustomerSessionStatus { active, inactive, expired }

class TableSession {
  const TableSession({required this.id, required this.restaurantId, required this.branchId, required this.tableId, required this.status, required this.customerCount, required this.startedAt, required this.expiresAt, required this.metadata, this.endedAt});
  final String id; final String restaurantId; final String branchId; final String tableId; final TableSessionStatus status; final int customerCount; final DateTime startedAt; final DateTime? endedAt; final DateTime expiresAt; final AuditMetadata metadata;
}
class CustomerSession {
  const CustomerSession({required this.id, required this.restaurantId, required this.branchId, required this.tableId, required this.tableSessionId, required this.status, required this.lastActivityAt, required this.expiresAt, required this.metadata, this.languageCode, this.deviceId});
  final String id; final String restaurantId; final String branchId; final String tableId; final String tableSessionId; final String? languageCode; final String? deviceId; final CustomerSessionStatus status; final DateTime lastActivityAt; final DateTime expiresAt; final AuditMetadata metadata;
}
