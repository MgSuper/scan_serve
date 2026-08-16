import 'package:scan_serve/shared/domain/audit_metadata.dart';

/// Firestore-facing metadata. Dates are UTC [DateTime] values; a Firestore
/// adapter may serialize them as Timestamp values at the infrastructure edge.
class FirestoreMetadataDto {
  const FirestoreMetadataDto({
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.acceptedAt,
    this.preparedAt,
    this.servedAt,
    this.deletedAt,
    this.deletedBy,
    this.isArchived = false,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? acceptedAt;
  final DateTime? preparedAt;
  final DateTime? servedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool isArchived;

  AuditMetadata toDomain() => AuditMetadata(
        createdAt: createdAt,
        updatedAt: updatedAt,
        submittedAt: submittedAt,
        acceptedAt: acceptedAt,
        preparedAt: preparedAt,
        servedAt: servedAt,
        deletedAt: deletedAt,
        deletedBy: deletedBy,
        isArchived: isArchived,
      ).utc;

  static FirestoreMetadataDto fromDomain(AuditMetadata metadata) {
    final value = metadata.utc;
    return FirestoreMetadataDto(
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
      submittedAt: value.submittedAt,
      acceptedAt: value.acceptedAt,
      preparedAt: value.preparedAt,
      servedAt: value.servedAt,
      deletedAt: value.deletedAt,
      deletedBy: value.deletedBy,
      isArchived: value.isArchived,
    );
  }

  Map<String, Object?> toFirestore() => {
        'createdAt': createdAt.toUtc(),
        'updatedAt': updatedAt.toUtc(),
        'submittedAt': submittedAt?.toUtc(),
        'acceptedAt': acceptedAt?.toUtc(),
        'preparedAt': preparedAt?.toUtc(),
        'servedAt': servedAt?.toUtc(),
        'deletedAt': deletedAt?.toUtc(),
        'deletedBy': deletedBy,
        'isArchived': isArchived,
      };

  static FirestoreMetadataDto fromFirestore(Map<String, Object?> value) =>
      FirestoreMetadataDto(
        createdAt: (value['createdAt']! as DateTime).toUtc(),
        updatedAt: (value['updatedAt']! as DateTime).toUtc(),
        submittedAt: (value['submittedAt'] as DateTime?)?.toUtc(),
        acceptedAt: (value['acceptedAt'] as DateTime?)?.toUtc(),
        preparedAt: (value['preparedAt'] as DateTime?)?.toUtc(),
        servedAt: (value['servedAt'] as DateTime?)?.toUtc(),
        deletedAt: (value['deletedAt'] as DateTime?)?.toUtc(),
        deletedBy: value['deletedBy'] as String?,
        isArchived: value['isArchived'] as bool? ?? false,
      );
}
