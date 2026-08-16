/// Lifecycle metadata shared by persisted ScanServe aggregates.
///
/// Mappers normalize values to UTC before they enter the domain. This type
/// never depends on a Firestore type, keeping the domain portable and testable.
class AuditMetadata {
  const AuditMetadata({
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

  AuditMetadata get utc => AuditMetadata(
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        submittedAt: submittedAt?.toUtc(),
        acceptedAt: acceptedAt?.toUtc(),
        preparedAt: preparedAt?.toUtc(),
        servedAt: servedAt?.toUtc(),
        deletedAt: deletedAt?.toUtc(),
        deletedBy: deletedBy,
        isArchived: isArchived,
      );
}
