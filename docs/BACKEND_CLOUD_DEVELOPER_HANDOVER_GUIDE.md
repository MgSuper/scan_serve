# ScanServe Backend & Cloud Functions — Developer Handover & System Learning Guide

**Audience:** TypeScript/Firebase engineers maintaining the ScanServe backend
**Primary source trees:** `backend/src/`, `backend/scripts/`, root `firestore.rules`, root `firestore.indexes.json`
**Author:** Manus AI
**Scope:** Firestore contract, security rules, indexes, callable envelopes, order validation/transactions, status transitions, sessions/carts, emulator fallbacks, and notification extension points

## 1. Purpose and operating model

The backend is the authoritative server-side boundary for ScanServe. The customer PWA and Angular dashboard are untrusted clients: they provide identifiers and requested actions, while Cloud Functions and Firestore Rules enforce tenant ownership, valid lifecycle transitions, menu availability, price integrity, idempotency, and staff authorization.

The implementation is a small CommonJS TypeScript Cloud Functions package. [`backend/src/index.ts`](../backend/src/index.ts) initializes Firebase Admin and exports the callable handlers. The substantial business logic lives in service classes rather than in the callable wrappers. This matches the architecture principle that user interfaces consume backend contracts instead of defining business rules.[^1]

> **Mental model:** callable wrapper → envelope validator → service transaction → Firestore contract → standardized success/failure envelope. Rules provide the direct-Firestore boundary; service-layer authorization protects privileged callable mutations.

The canonical defaults are `scanserve-demo`, `main-branch`, `table-12`, `active-table-session`, and `active-customer-session`. A cart is canonically `cart_{customerSessionId}`. Menu order identity is the immutable Firestore document ID under the nested restaurant menu collection.[^2]

## 2. Backend repository map

| Responsibility | Primary location | Maintainer notes |
|---|---|---|
| Functions entrypoint | [`backend/src/index.ts`](../backend/src/index.ts) | Initializes Admin SDK and exports callable handlers. |
| Submit-order callable | [`backend/src/callable/submit_order.ts`](../backend/src/callable/submit_order.ts) | Parses request, delegates to `OrderService`, returns standard envelope. |
| Status callable | [`backend/src/callable/update_order_status.ts`](../backend/src/callable/update_order_status.ts) | Enables local CORS, requires Auth UID, delegates to `OrderStatusService`. |
| Order orchestration | [`backend/src/services/order_service.ts`](../backend/src/services/order_service.ts) | Handles cart/inline order paths, session/cart fallbacks, menu resolution, price checks, mirrored writes, and idempotency. |
| Status authorization | [`backend/src/services/order_status_service.ts`](../backend/src/services/order_status_service.ts) | Finds staff profile, validates role/tenant/branch, enforces transition map, updates orders. |
| Callable validation | [`backend/src/validators/callable_request_validator.ts`](../backend/src/validators/callable_request_validator.ts) | Validates request envelope, nested payload compatibility, items, notes, modifiers, and status. |
| Public API envelope | [`backend/src/shared/api/contracts.ts`](../backend/src/shared/api/contracts.ts) | Defines `ApiRequest`, `ApiResponse`, `success()`, and `failure()`. |
| Shared IDs | [`backend/src/shared/firestore_contract.ts`](../backend/src/shared/firestore_contract.ts) | Defines defaults, customer-session normalization, and canonical cart ID. |
| Firestore DTO/domain mapping | [`backend/src/shared/data/firestore`](../backend/src/shared/data/firestore) | Converts timestamps and shared document shapes. |
| Emulator seed | [`backend/scripts/seed-emulator-menu.cjs`](../backend/scripts/seed-emulator-menu.cjs) | Seeds tenant metadata, branch, staff/role, categories, menu, and local demo records. |
| Rules | [`firestore.rules`](../firestore.rules) | Direct Firestore authorization boundary. |
| Indexes | [`firestore.indexes.json`](../firestore.indexes.json) | Composite query index manifest. |

## 3. Firestore ownership and collection hierarchy

### 3.1 Canonical paths

Firestore ownership is restaurant-first for restaurant-managed resources, with top-level collections retained where the service contract requires them. The current contract is:

| Resource | Canonical path | Ownership and identity |
|---|---|---|
| Restaurant | `restaurants/{restaurantId}` | Tenant metadata; document ID is the restaurant ID. |
| Branch | `restaurants/{restaurantId}/branches/{branchId}` | Restaurant-owned branch; document ID is branch ID. |
| Category | `restaurants/{restaurantId}/categories/{categoryId}` | Restaurant/branch category metadata; `parentCategoryId` is nullable for root nodes. |
| Menu item | `restaurants/{restaurantId}/menu/{menuItemId}` | Nested restaurant menu is canonical; Firestore document ID is order-facing `menuItemId`. |
| Table | `restaurants/{restaurantId}/tables/{tableId}` | Table Management creates branch-scoped records with QR URL/token and status. |
| Table session | Project architecture supports restaurant-owned table sessions | A table session identifies an active physical-table visit. |
| Customer session | `customerSessions/{customerSessionId}` | Top-level document; links restaurant, branch, table, and table session. |
| Cart | `carts/{cartId}` | Top-level document; canonical ID `cart_{customerSessionId}`. Legacy unprefixed IDs are compatibility reads only. |
| Order | `orders/{orderId}` and `restaurants/{restaurantId}/orders/{orderId}` | One order ID is mirrored to top-level and nested paths. |
| Order item | `orderItems/{orderItemId}` | Top-level operational line item, linked to order and tenant. |
| Idempotency request | `orderRequests/{requestId}` | Top-level request record storing tenant/order summary and expiry. |
| Assistance request | `restaurants/{restaurantId}/waiterRequests/{requestId}` | Nested restaurant request with table/customer session and `WAITER`/`PAYMENT` type. |
| Staff profile | `staff/{staffId}` | Current status service queries `authUid`; profile includes tenant, branch, role, and active flags. |
| Role | `roles/{roleId}` | Role document includes `restaurantId` and permissions such as `orders.updateStatus`. |

The project’s ownership hierarchy is not identical to every URL path. A customer session is top-level for query simplicity, while its `restaurantId`, `branchId`, `tableId`, and `tableSessionId` references retain ownership context. The order service must write all of these denormalized fields because both customer and kitchen queries depend on them.[^3]

### 3.2 Menu schema and server-side validation

A menu item should contain the following interoperability fields:

```json
{
  "id": "firestore-document-id",
  "restaurantId": "scanserve-demo",
  "branchId": "main-branch",
  "name": "Phở bò",
  "description": "Slow-simmered beef noodle soup",
  "category": "Soups",
  "categoryId": "mains-soups",
  "categoryName": "Soups",
  "parentCategoryId": "mains",
  "imageUrl": "https://...",
  "price": 85000,
  "status": "in_stock",
  "availability": "in_stock",
  "isAvailable": true,
  "isArchived": false,
  "archived": false,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

`OrderService.createOrderInTransaction()` resolves every requested line against `restaurants/{restaurantId}/menu/{menuItemId}`. It accepts an item when `isAvailable === true`, `status === 'in_stock'`, or `availability === 'in_stock'`, rejects archived/deleted records, checks restaurant/branch ownership, and validates that `price` is a safe non-negative integer. In emulator development mode, missing sessions/carts/menu items can be created through explicit fallback helpers; production behavior must remain strict.

The backend calculates `unitPrice`, `lineTotal`, subtotal, and total quantity from server-resolved menu data. A client-supplied total is not authoritative. The order item preserves category ID/name, image URL, notes, modifiers, quantity, and resolved price for kitchen/customer rendering.

### 3.3 Table and QR schema

The Angular Table Management feature writes:

```text
restaurants/{restaurantId}/tables/{tableId}
```

with `tableNo`, `zone`, `capacity`, `qrUrl`, `secretToken`, `status: 'AVAILABLE'`, `restaurantId`, `branchId`, and server timestamps. The QR URL is:

```text
https://scanserve.app/menu?tenant={restaurantId}&branch={branchId}&table={tableNo}&token={secretToken}
```

The token is a capability value used by the customer route to construct `SessionContext`. The current order service validates customer session and tenant context; if token-level authenticity is strengthened later, add explicit validation against the table document and update the Rules/callable contract together.

## 4. Callable request and response contracts

### 4.1 Standard envelope

Every callable request is expected to include:

```typescript
interface ApiRequest<T> {
  requestId: string;
  payload: T;
  timestamp: string;
  clientVersion?: string;
}
```

Every response is either:

```typescript
type ApiResponse<T> =
  | { success: true; requestId: string; data: T; serverTimestamp: string }
  | { success: false; requestId: string; error: ApiError; serverTimestamp: string };
```

`success()` and `failure()` in [`contracts.ts`](../backend/src/shared/api/contracts.ts) create this shape. Keep `requestId` in all logs and responses so client failures can be correlated with backend transactions.

### 4.2 `submitOrder`

The validator accepts the canonical `payload` shape and tolerates one additional `payload` or `data` wrapper from generic callable clients. A submit request requires `restaurantId`, `customerSessionId`, and either a non-empty `cartId` or non-empty `items` array. `cartId` is optional when inline items are provided; the service derives the canonical cart ID when necessary.

An order item requires a non-empty `menuItemId` and positive safe-integer `quantity`. Both `notes` and legacy singular `note` are accepted, with `notes` preferred. `modifiers`, when present, must be a string array. Branch/table/session fields are optional at the validator boundary because the session document and service defaults can supply development values.

Example canonical request:

```json
{
  "requestId": "cart_active-customer-session_1720000000000",
  "timestamp": "2026-08-25T14:00:00.000Z",
  "payload": {
    "restaurantId": "scanserve-demo",
    "customerSessionId": "active-customer-session",
    "cartId": "cart_active-customer-session"
  }
}
```

Inline clients may instead include:

```json
{
  "restaurantId": "scanserve-demo",
  "customerSessionId": "active-customer-session",
  "branchId": "main-branch",
  "tableId": "12",
  "tableSessionId": "table-session-12",
  "items": [
    { "menuItemId": "firestore-menu-id", "quantity": 2, "notes": "No cilantro" }
  ]
}
```

### 4.3 `updateOrderStatus`

The status request requires `restaurantId`, `orderId`, and one of `ACCEPTED`, `PREPARING`, `READY`, or `SERVED`. It is rejected before service execution if the envelope or status is malformed.

`update_order_status.ts` configures local CORS for `http://localhost:4200`, checks `request.auth.uid`, calls `OrderStatusService`, and returns the same success/failure envelope. The browser dashboard’s Firebase Auth token supplies the callable authentication context; Firestore Rules do not replace this service-layer staff authorization.

## 5. Order submission execution path

### 5.1 Dispatch and normalization

[`OrderService.submitOrder()`](../backend/src/services/order_service.ts) normalizes `customerSessionId`, derives `cartId` with `canonicalCartId()`, and dispatches to the inline path when `items.length > 0`; otherwise it selects the cart path. This allows Flutter cart clients and compatibility inline clients to share one server orchestration service.

### 5.2 Cart path

`submitCartOrder()` runs one Firestore transaction. It reads the idempotency record, top-level customer session, and a list of possible cart references. The reference list checks the canonical `cart_{sessionId}`, the requested cart ID, and the legacy unprefixed session ID in that order.

If `orderRequests/{requestId}` already exists for the same restaurant, the stored summary is returned and no duplicate order is created. If the session is missing and emulator fallback is enabled, a development session is constructed. If the cart is missing but inline items are available in the request, a development cart can be created inside the transaction. A real cart must contain a non-empty `items` list and must belong to the same restaurant/customer session.

### 5.3 Inline path

`submitInlineOrder()` repeats the idempotency/session/cart-reference reads, maps request items to internal cart-line records, and optionally creates a development cart so the resulting transaction has consistent cart state. The inline path still resolves each menu item from the nested canonical path and still applies all restaurant/branch/availability/archive/price checks.

### 5.4 Transactional writes

`createOrderInTransaction()` reads the restaurant document, branch document, and every nested menu item before building the order. It then:

1. Generates one `orderId`.
2. Resolves each menu item and computes server prices/line totals.
3. Creates top-level `orderItems/{orderItemId}` documents.
4. Creates `orders/{orderId}`.
5. Creates `restaurants/{restaurantId}/orders/{orderId}` with the same order data.
6. Creates the idempotency record at `orderRequests/{requestId}`.
7. Creates missing development restaurant/branch/session/cart/menu fallback records when emulator mode is enabled.
8. Clears the source cart after the order is created.

The mirrored order contains restaurant, branch, table, table session, customer session, cart ID, status `PENDING`, items, totals, timestamps, and lifecycle fields such as `acceptedAt`, `preparedAt`, `servedAt`, `isArchived`, and deletion metadata.

## 6. Order status authorization and transitions

[`OrderStatusService`](../backend/src/services/order_status_service.ts) executes status changes in one transaction. It queries `staff` by `authUid`, reads the top-level and nested order documents, then validates:

- A staff profile exists for the authenticated Firebase UID.
- Staff profile and order belong to the requested restaurant.
- Staff profile and order are active and not archived/deleted.
- A staff branch restriction, when present, matches the order branch.
- `roleId` exists and the role document belongs to the same restaurant.
- The role permissions include `orders.updateStatus`.
- The requested status is the exact next state for the current order state.

The transition map is:

```text
PENDING   → ACCEPTED
ACCEPTED  → PREPARING
PREPARING → READY
READY     → SERVED
```

The service updates both top-level and nested order documents and adds milestone timestamps: `acceptedAt` for `ACCEPTED`, `preparedAt` for `READY`, and `servedAt` for `SERVED`. The current map does not permit arbitrary transitions or a direct `PENDING → READY` jump.

The local seed must create a staff document whose `authUid` matches the emulator login account and a role whose permissions include `orders.updateStatus`. A missing staff profile produces `UNAUTHORIZED: No staff profile is associated with this account.`

## 7. Firestore Security Rules

### 7.1 Helper predicates

[`firestore.rules`](../firestore.rules) defines `isAuthenticated()`, `isStaff()`, `hasRestaurantId()`, `isActiveMenuItem()`, `isValidCustomerOrderCreate()`, and `isActiveCustomerOrder()`. The current `isStaff()` predicate means `request.auth != null`; detailed staff-profile and role authorization for callable mutations is performed in `OrderStatusService`.

Rules are evaluated independently of Cloud Functions. Admin SDK writes from Functions bypass Rules, but callable handlers still validate input and authorization. Do not weaken Rules merely to make a client flow pass; fix the path/field/auth contract instead.

### 7.2 Current access matrix

| Path | Anonymous customer | Authenticated staff |
|---|---|---|
| `restaurants/{restaurantId}` | Read | Read/write |
| `restaurants/{restaurantId}/menu/{menuItemId}` | Read | Read/write |
| `restaurants/{restaurantId}/orders/{orderId}` | Create valid `PENDING` order; read active order | Read/write |
| `customerSessions/{sessionId}` | Create own-shaped active session; customer update of own tenant-preserving record | Read/write/delete |
| `carts/{cartId}` | Create/update own-shaped cart | Read/write/delete |
| `restaurants/{restaurantId}/waiterRequests/{requestId}` | Create valid open request | Read/write/delete |
| `restaurants/{restaurantId}/{document=**}` | Denied by broad operational rule unless a specific match allows it | Read/write |
| Top-level `orders`, `orderItems`, `orderRequests` | Denied | Read/write |
| Legacy `menus`, `categories`, `menuItems` | Read | Read/write |
| `staff`, `roles` | Denied | Read/write |
| Everything else | Denied | Denied unless a more specific rule exists |

The nested restaurant order read rule permits only active statuses (`PENDING`, `ACCEPTED`, `PREPARING`, `READY`) for anonymous customers. Customer queries must include the same session/table filters expected by the client and contract; broad collection reads should not be introduced.

### 7.3 Rule maintenance warnings

Firestore Rules cannot prove that an anonymous QR token is cryptographically valid unless the rule reads a table document and compares the token. If token authorization becomes mandatory, add a `tableToken` field to the order/session request and a rule predicate that validates the table document. Ensure the callable service performs the same validation so direct Firestore and callable flows cannot diverge.

Keep the `restaurantId` comparison on every customer-create path. Keep `isArchived`/`deletedAt` checks on orders, sessions, carts, and menu records. Test both authenticated and unauthenticated emulator clients after every Rules change.

## 8. Composite indexes and query design

[`firestore.indexes.json`](../firestore.indexes.json) currently declares collection-group indexes for:

| Collection group | Fields | Intended use |
|---|---|---|
| `menus` | `isActive ASC`, `updatedAt DESC` | Active menu ordering. |
| `categories` | `menuId ASC`, `displayOrder ASC` | Categories within a menu. |
| `menuItems` | `categoryId ASC`, `isAvailable ASC`, `displayOrder ASC` | Available items within a category. |
| `orders` | `customerSessionId ASC`, `tableId ASC`, `status ASC` | Customer active-order queries. |
| `orders` | `customerSessionId ASC`, `createdAt DESC` | Customer order history. |
| `orders` | `status ASC`, `createdAt ASC` | Kitchen FIFO/status queue. |
| `orders` | `businessDate ASC`, `createdAt DESC` | Daily operational reporting. |
| `tableSessions` | `tableId ASC`, `isActive ASC`, `startedAt DESC` | Active table sessions. |

The current Angular and Flutter implementations use nested collection listeners and simple where clauses in several places, so not every declared index is exercised by the present code. When adding a compound query, deploy/update the index manifest and test against the emulator and a staging project. Firestore error messages that include a generated index URL should be treated as a deployment/configuration issue, not swallowed.

## 9. Cloud Functions and notification architecture

### 9.1 Current callable functions

The active exported callables are `submitOrder` and `updateOrderStatus`. Both are v2 `onCall` functions. They use structured logging, standardized responses, and service-layer delegation. The callable wrappers should remain thin; new business rules belong in services or validators.

The backend package uses:

```bash
cd backend
npm run lint   # tsc --noEmit
npm run build  # emits lib/index.js
npm run seed:menu
```

`backend/package.json` points `main` to `lib/index.js` and targets Node 20. Do not edit generated `backend/lib` source by hand; rebuild from `backend/src`.

### 9.2 FCM push notification status

There is currently no Firebase Cloud Messaging send implementation under `backend/src`. The platform architecture identifies notifications as a backend responsibility, but the current codebase does not export an FCM notification function, register device tokens, or call `admin.messaging().send()` in the order/status services.[^4]

When implementing FCM, use a deliberate extension rather than adding a side effect to a transaction:

1. Store a customer device token or notification subscription under a tenant/session-safe path with appropriate Rules.
2. Commit the order/status transaction first.
3. Trigger notification delivery from a trusted event path, such as a Firestore trigger or an outbox record written in the transaction.
4. Resolve recipient tokens by customer session/order and restaurant staff role/branch.
5. Send a minimal payload containing order ID, restaurant ID, table/session context as appropriate, and new status.
6. Remove invalid tokens and log delivery IDs/errors without logging QR secrets.
7. Make retries idempotent so a function retry does not duplicate business writes or produce confusing user notifications.

Do not claim FCM is active until the messaging dependency, token lifecycle, trigger/service, Rules, and tests exist.

## 10. Emulator and debugging workflow

A reliable local workflow is:

```bash
# From the repository root, start the configured emulators.
firebase emulators:start --project scanserve-app-1010

# In another shell, seed Auth/Firestore as appropriate.
cd backend
npm run seed:menu

# Build and validate backend code.
npm run lint
npm run build
```

For an end-to-end order diagnosis:

1. Confirm the Flutter URL resolves the intended `restaurantId`, `branchId`, `tableId`, token, and session IDs.
2. Inspect `restaurants/{restaurantId}/menu` and record actual Firestore document IDs.
3. Inspect `carts/cart_{customerSessionId}` and compare every `menuItemId` to the menu document IDs.
4. Inspect `customerSessions/{customerSessionId}` for active status and tenant/branch/table fields.
5. Invoke `submitOrder` with a unique request ID and inspect its structured logs.
6. Verify both `orders/{orderId}` and `restaurants/{restaurantId}/orders/{orderId}`.
7. Sign into Angular with the seeded staff account and invoke `updateOrderStatus` through the dashboard.
8. Verify the staff profile/role documents if authorization fails.

The backend logs menu paths, IDs, snapshot existence, selected nested paths, tenant/branch matches, and availability decisions. Use those logs to identify exact path mismatches instead of adding more broad fallback reads.

## 11. Testing and quality gates

Backend code should pass:

```bash
cd backend
npm run lint
npm run build
```

The most important test categories are:

| Test category | Assertions |
|---|---|
| Validator tests | Envelope, timestamp, required IDs, cart-vs-inline requirement, item quantity, notes, modifiers, status enum. |
| Order service tests | Idempotency, canonical cart lookup, nested menu resolution, price/availability/branch validation, mirrored writes, cart clearing. |
| Status service tests | Staff profile lookup, tenant/branch/role permission, transition map, top-level/nested updates. |
| Rules tests | Anonymous menu/session/cart/order behavior, authenticated staff access, cross-tenant denial, legacy path behavior. |
| Emulator integration | Seeded Auth + Firestore, real callable request, order documents, status transition, and staff authorization. |

When writing a new service test, assert both the document path and the document ID. A Firestore document with the right fields under a different collection path is not an equivalent record.

## 12. Maintenance rules

Keep `docs/specifications/firestore-contract.md`, `backend/src/shared/firestore_contract.ts`, Flutter `ScanServeFirestoreContract`, Angular `restaurant-context.ts`, seed scripts, Rules, indexes, and UI payload builders synchronized. Any new collection or renamed field must be reviewed across all three applications.

Keep security decisions in two layers: Rules for direct Firestore access and services for callable business operations. Keep callable wrappers small and make errors structured. Use transactions for order/status mutations and idempotency records for retry safety.

Treat emulator fallbacks as development-only. The development switch is derived from `FIRESTORE_EMULATOR_HOST` or `FUNCTIONS_EMULATOR === 'true'`. Never let a missing production menu/session silently become a mock record.

Do not log QR secret tokens, passwords, Firebase credentials, or full personal data. Request IDs, order IDs, restaurant IDs, branch IDs, and menu document IDs are appropriate correlation fields, subject to the project’s privacy policy.

## References

[^1]: [System Overview](../architecture/001-system-overview.md) and [Cloud Functions Specification](../specifications/013-cloud-functions-part-1.md)
[^2]: [Firestore Contract](firestore-contract.md)
[^3]: [Firestore Design](../architecture/003-firestore-design.md)
[^4]: [Cloud Functions source tree](../backend/src)
[^5]: [Backend package scripts](../backend/package.json)
[^6]: [OrderService](../backend/src/services/order_service.ts)
[^7]: [OrderStatusService](../backend/src/services/order_status_service.ts)
[^8]: [Callable request validator](../backend/src/validators/callable_request_validator.ts)
[^9]: [Callable API contracts](../backend/src/shared/api/contracts.ts)
[^10]: [Firestore DTOs](../backend/src/shared/data/firestore/dtos.ts)
[^11]: [Firestore Rules](../firestore.rules)
[^12]: [Firestore indexes](../firestore.indexes.json)
[^13]: [Submit-order callable](../backend/src/callable/submit_order.ts)
[^14]: [Update-order-status callable](../backend/src/callable/update_order_status.ts)
[^15]: [Emulator seed script](../backend/scripts/seed-emulator-menu.cjs)
