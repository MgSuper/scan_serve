# ScanServe Firestore Contract

This contract is the single source of truth for the Flutter customer app, Firebase Functions, Angular Admin portal, and local emulator seed data.

| Resource | Canonical path | Document ID contract |
|---|---|---|
| Restaurant | `restaurants/{restaurantId}` | `restaurantId`, with default `scanserve-demo` |
| Branch | `restaurants/{restaurantId}/branches/{branchId}` | `branchId`, with default `main-branch` |
| Menu item | `restaurants/{restaurantId}/menu/{menuItemId}` | The immutable Firestore document ID is the order-facing `menuItemId`; the legacy `id` field is informational only. |
| Customer session | `customerSessions/{customerSessionId}` | Top-level document; default `active-customer-session` |
| Cart | `carts/{cartId}` | Canonical ID is `cart_{customerSessionId}`. Legacy unprefixed IDs may be read only for migration compatibility. |
| Order | `orders/{orderId}` and `restaurants/{restaurantId}/orders/{orderId}` | One generated `orderId` is mirrored to both paths. |

The shared development defaults are `scanserve-demo`, `main-branch`, `table-12`, `active-table-session`, and `active-customer-session`. Menu availability is represented by `isAvailable: true`, `status: 'in_stock'`, and/or `availability: 'in_stock'`; producers should write all three fields for interoperability.
