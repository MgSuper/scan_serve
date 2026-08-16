import 'package:flutter_test/flutter_test.dart';
import 'package:scan_serve/features/menu/data/menu_mappers.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/shared/domain/audit_metadata.dart';

void main() {
  test('menu mapper preserves data and normalizes timestamps to UTC', () {
    final metadata = AuditMetadata(
      createdAt: DateTime(2026, 8, 16, 10),
      updatedAt: DateTime(2026, 8, 16, 11),
    );
    final menu = Menu(
      id: 'menu-1',
      restaurantId: 'restaurant-1',
      branchId: 'branch-1',
      name: 'Lunch',
      isActive: true,
      metadata: metadata,
    );

    final restored = menu.toDto().toDomain();

    expect(restored.id, menu.id);
    expect(restored.metadata.createdAt.isUtc, isTrue);
    expect(restored.metadata.isArchived, isFalse);
  });
}
