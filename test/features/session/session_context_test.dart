import 'package:flutter_test/flutter_test.dart';

import 'package:scan_serve/features/session/domain/session_context.dart';

void main() {
  test('resolves QR aliases into a table-scoped customer session', () {
    final context = SessionContext.fromQueryParameters({
      'tenant': 'scanserve-demo',
      'branch': 'main-branch',
      'table': '12',
      'token': 'table-secret-12',
    });

    expect(context.restaurantId, 'scanserve-demo');
    expect(context.branchId, 'main-branch');
    expect(context.tableId, '12');
    expect(context.tableToken, 'table-secret-12');
    expect(
      context.tableSessionId,
      'table-session-scanserve-demo-main-branch-12-table-secret-12',
    );
    expect(
      context.customerSessionId,
      'customer-session-scanserve-demo-main-branch-12-table-secret-12',
    );
    expect(context.scopeKey, contains('/12/'));
  });

  test(
    'preserves explicit session IDs when the link contains canonical aliases',
    () {
      final context = SessionContext.fromQueryParameters({
        'tenant': 'scanserve-demo',
        'branch': 'main-branch',
        'table': '12',
        'token': 'table-secret-12',
        'tableSessionId': 'table-session-existing',
        'customerSessionId': 'customer-session-existing',
      });

      expect(context.tableSessionId, 'table-session-existing');
      expect(context.customerSessionId, 'customer-session-existing');
      expect(context.toQueryParameters(), {
        'restaurantId': 'scanserve-demo',
        'branchId': 'main-branch',
        'tableId': '12',
        'tableSessionId': 'table-session-existing',
        'customerSessionId': 'customer-session-existing',
        'token': 'table-secret-12',
      });
    },
  );
}
