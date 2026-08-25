# ScanServe Flutter Customer PWA — Developer Handover & System Learning Guide

**Audience:** Flutter/Dart engineers maintaining the customer ordering PWA
**Primary source tree:** `lib/` and `test/`
**Author:** Manus AI
**Scope:** Customer QR entry, tenant/table session context, menu browsing, category filtering, cart persistence, order submission, assistance requests, and live order tracking

## 1. Purpose and operating model

The Flutter application is the anonymous customer-facing PWA. A customer does not begin with a conventional account-login workflow. Instead, the customer enters through a table QR code, and the URL establishes the restaurant, branch, table, and secret table token that scope the remainder of the visit. The PWA then reads public restaurant/menu data, creates or refreshes a customer session, persists a cart, submits an order through a callable function, and watches the customer’s active order.

The platform architecture treats Flutter as a client implementation of a shared backend contract rather than as the owner of the contract. Business concepts belong in feature domain layers, Firestore access belongs in repositories, and widgets communicate with BLoCs/use cases rather than directly with Firebase. This follows the project’s feature-first and Clean Architecture rules.[^1]

> **Mental model:** QR parameters establish scope; `SessionContext` normalizes that scope; route composition initializes `SessionBloc`; `MenuBloc` owns menu/filter state; `CartBloc` owns the in-memory order; repositories translate between Firestore/callable contracts and domain entities.

The canonical cross-stack identifiers are `scanserve-demo` for the restaurant, `main-branch` for the branch, `table-12` for the default table, `active-table-session` for the default table session, and `active-customer-session` for the default customer session. The canonical cart document ID is `cart_{customerSessionId}`. The immutable Firestore menu document ID, not a legacy `id` field inside the document, is the order-facing `menuItemId`.[^2]

## 2. Repository map

| Responsibility | Primary location | What the maintainer should expect |
|---|---|---|
| App startup and Firebase emulator setup | [`lib/main_common.dart`](../lib/main_common.dart) | Initializes Firebase, connects local emulators in non-release builds, initializes DI, and launches `App`. |
| Global route composition | [`lib/app/routes/router.dart`](../lib/app/routes/router.dart) | Converts GoRouter query parameters to `SessionContext`, creates route-scoped BLoCs, and passes scope into menu/cart/customer services. |
| Identifier defaults and contract | [`lib/core/config/scan_serve_firestore_contract.dart`](../lib/core/config/scan_serve_firestore_contract.dart) | Central source for default restaurant/branch/table/session identifiers and canonical cart IDs. |
| Dependency graph | [`lib/core/di/service_locator.dart`](../lib/core/di/service_locator.dart) | Registers Firebase clients, repositories, use cases, `MenuBloc`, and parameterized `CartBloc`. |
| QR/session normalization | [`lib/features/session/domain/session_context.dart`](../lib/features/session/domain/session_context.dart) | Maps QR aliases and canonical query keys into a table-scoped context. |
| Explicit session state | [`lib/features/session/presentation/bloc/session_bloc.dart`](../lib/features/session/presentation/bloc/session_bloc.dart) | Emits `SessionReady` after `SessionStarted`. |
| Menu Firestore adapter | [`lib/features/menu/data/menu_repository_impl.dart`](../lib/features/menu/data/menu_repository_impl.dart) | Reads menu/category collections, filters by tenant/branch/availability, merges dynamic categories, and streams catalog updates. |
| Menu state and filtering | [`lib/features/menu/presentation/bloc/menu_bloc.dart`](../lib/features/menu/presentation/bloc/menu_bloc.dart) | Owns loading/error/catalog/search/selected-category state and preserves filters during refreshes. |
| Menu drawer and item grid | [`lib/features/menu/presentation/pages/menu_page.dart`](../lib/features/menu/presentation/pages/menu_page.dart) | Renders hierarchical category navigation, aggregate badges, search, cards, and cart preview. |
| Cart Firestore/callable adapter | [`lib/features/cart/data/cart_repository_impl.dart`](../lib/features/cart/data/cart_repository_impl.dart) | Persists `carts/{cartId}`, canonicalizes menu IDs, and calls `submitOrder`. |
| Customer/session fallback adapter | [`lib/features/customer/data/firestore_customer_repository.dart`](../lib/features/customer/data/firestore_customer_repository.dart) | Handles customer sessions, active-order reads, assistance requests, and an alternate inline-order path. |
| Feature tests | [`test/features/`](../test/features) | Contains BLoC, repository, widget, and session-context tests. |

## 3. QR deep-link and session architecture

### 3.1 QR URL contract

The Angular Admin table feature writes a URL shaped as follows:

```text
https://scanserve.app/menu?tenant={tenantId}&branch={branchId}&table={tableNo}&token={secretToken}
```

The QR URL deliberately uses customer-friendly aliases (`tenant`, `branch`, and `table`) rather than the internal field names (`restaurantId`, `branchId`, and `tableId`). Flutter accepts both forms so that older internal links and newly printed QR tags remain compatible.

| URL key | Canonical Flutter field | Required behavior |
|---|---|---|
| `tenant` or `restaurantId` | `SessionContext.restaurantId` | Selects `/restaurants/{restaurantId}/...` paths. |
| `branch` or `branchId` | `SessionContext.branchId` | Restricts categories, menu items, sessions, carts, and orders to a branch. |
| `table` or `tableId` | `SessionContext.tableId` | Identifies the physical table and is stored on sessions/carts/orders. |
| `token` | `SessionContext.tableToken` | Retains the table secret from the QR link and is copied into session/cart/order metadata. |
| `tableSessionId` | `SessionContext.tableSessionId` | Optional internal override; otherwise a deterministic ID is derived. |
| `customerSessionId` | `SessionContext.customerSessionId` | Optional internal override; otherwise a deterministic ID is derived. |

### 3.2 `SessionContext` resolution

[`SessionContext.fromQueryParameters`](../lib/features/session/domain/session_context.dart) performs the following algorithm:

1. Read the first non-empty value from `restaurantId`, then `tenant`; otherwise use the shared restaurant default.
2. Read `branchId`, then `branch`; otherwise use the shared branch default.
3. Read `tableId`, then `table`; otherwise use the shared table default.
4. Read `token`, preserving it exactly as `tableToken`.
5. Prefer explicit `tableSessionId` and `customerSessionId` when present.
6. If a session ID is absent, derive a stable ID from restaurant, branch, table, and token. For the default no-token development tuple, retain `active-table-session` and `active-customer-session` so emulator fixtures continue to work.

The derived identifiers make two different QR tokens produce different customer/table sessions even when they point to the same physical table. This prevents cart/order state from silently crossing QR sessions.

The core implementation is intentionally small:

```dart
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
  // Explicit session IDs win; otherwise derive deterministic scoped IDs.
  ...
}
```

When generating an internal route after the landing page, `toQueryParameters()` emits the canonical internal names. It includes the token when one was supplied, so subsequent navigation does not lose table identity.

### 3.3 Router lifecycle

[`AppRouter.createRouter`](../lib/app/routes/router.dart) uses one `SessionContext` per `GoRouterState`:

```dart
final session = _sessionContext(state);
return MultiBlocProvider(
  providers: [
    BlocProvider<SessionBloc>(
      create: (_) => SessionBloc()..add(SessionStarted(session)),
    ),
    BlocProvider<MenuBloc>(create: (_) => sl<MenuBloc>()),
    BlocProvider<CartBloc>(
      create: (_) => sl<CartBloc>(
        param1: CartInitial(_cartFromState(session, state)),
      ),
    ),
  ],
  child: child,
);
```

The shell wraps `/menu`, `/cart`, and `/order-tracking`. Therefore, the BLoCs are route-scoped and receive the same restaurant/branch/table/session values. A cart created from a QR visit uses `Cart.empty()` with a canonical `cart_{customerSessionId}` ID unless an explicit `cartId` query parameter is present.

The home route constructs `LandingScreen` with the same scope and creates a customer repository with the same token:

```dart
FirestoreCustomerRepository(
  firestore: sl<FirebaseFirestore>(),
  functions: sl<FirebaseFunctions>(),
  restaurantId: session.restaurantId,
  branchId: session.branchId,
  tableId: session.tableId,
  tableSessionId: session.tableSessionId,
  customerSessionId: session.customerSessionId,
  tableToken: session.tableToken,
)
```

This is important because the default `CustomerRepository` registered by `service_locator.dart` is only a development fallback. The router overrides it for a real QR scope. Do not accidentally replace the route-scoped repository with the default singleton when adding a new customer action.

## 4. Application startup and dependency injection

### 4.1 Bootstrap sequence

[`lib/main_common.dart`](../lib/main_common.dart) executes the following sequence:

1. Call `WidgetsFlutterBinding.ensureInitialized()`.
2. Preserve native splash only on non-web targets.
3. Build `AppConfig` from the selected environment.
4. Initialize Firebase with `DefaultFirebaseOptions.currentPlatform` if no Firebase app exists.
5. In non-release mode, connect Firestore to port `8080` and Functions to port `5001`; the host defaults to `127.0.0.1` and can be overridden by `SCAN_SERVE_FIREBASE_EMULATOR_HOST`.
6. Run `setupLocator(config)`.
7. Initialize localization and install the global `AppBlocObserver`.
8. Call `runApp(const App())`.
9. Remove native splash only on supported non-web platforms and treat removal as best effort.

The web guard around `FlutterNativeSplash.remove()` is intentional. Do not reintroduce unconditional splash removal in a web bootstrap path.

### 4.2 Service locator graph

[`lib/core/di/service_locator.dart`](../lib/core/di/service_locator.dart) is the composition root. Its central graph is:

```text
FirebaseFirestore ──┬── MenuRepositoryImpl ── GetActiveMenu / WatchActiveMenu ── MenuBloc
                    └── CartRepositoryImpl ── AddToCart / RemoveFromCart /
                                               SubmitOrderUseCase ── CartBloc
FirebaseFunctions ──┘
```

The locator registers Firestore and Functions as lazy singletons, repositories as lazy singletons, use cases as lazy singletons, `MenuBloc` as a factory, and `CartBloc` as a parameterized factory. `CartBloc` must be created with the route-specific initial `CartState`; creating it without `CartInitial(_cartFromState(...))` loses table/customer scope.

The compile-time `SCAN_SERVE_*` variables are fallback values for the default `CustomerRepository` registration. QR-driven navigation takes precedence. If a new entry point is added, prefer passing a `SessionContext` rather than adding another independent set of environment variables.

## 5. End-to-end onboarding roadmap

A new engineer should trace a customer action through the layers in this order.

### Step 1 — Start at the Firestore contract

Read [`docs/specifications/firestore-contract.md`](firestore-contract.md) first. The important paths are:

```text
restaurants/{restaurantId}
restaurants/{restaurantId}/branches/{branchId}
restaurants/{restaurantId}/categories/{categoryId}
restaurants/{restaurantId}/menu/{menuItemId}
restaurants/{restaurantId}/orders/{orderId}
restaurants/{restaurantId}/waiterRequests/{requestId}
customerSessions/{customerSessionId}
carts/{cartId}
orders/{orderId}
```

The menu collection is nested under the restaurant. The cart and customer session collections are top-level. Orders are mirrored to top-level and restaurant-nested paths by the backend. Confusing these ownership paths is the most common source of local-order failures.

### Step 2 — Inspect domain entities

The menu domain is in [`lib/features/menu/domain/menu_entities.dart`](../lib/features/menu/domain/menu_entities.dart). `MenuCatalog` groups a `Menu`, `Category` records, and `MenuItem` records. A `MenuItem` carries at least `id`, `restaurantId`, `branchId`, `menuId`, `categoryId`, `name`, `price`, availability, audit metadata, and optional `categoryName`, `parentCategoryId`, `description`, and `imageUrl`.

The `id` is the Firestore document ID. `categoryId` identifies the node used by the drawer. `parentCategoryId` identifies the parent node for nested categories. `categoryName` is presentation metadata and must not be used as the stable join key.

Cart entities live in [`lib/features/cart/domain/cart_entities.dart`](../lib/features/cart/domain/cart_entities.dart). A `Cart` carries restaurant, branch, table, table-session, and customer-session fields in addition to `CartItem` entries. Every cart line uses `menuItemId`, quantity, unit price, and optional notes/modifiers.

### Step 3 — Follow DTO and mapper boundaries

The menu data layer maps Firestore documents into domain objects inside [`menu_repository_impl.dart`](../lib/features/menu/data/menu_repository_impl.dart). The repository deliberately assigns `document.id` to `MenuItem.id`:

```dart
return MenuItem(
  // Use the immutable Firestore document ID for downstream order lookups.
  id: document.id,
  restaurantId: documentRestaurantId ?? restaurantId,
  branchId: resolvedBranchId,
  menuId: menuId,
  categoryId: categoryId,
  name: name,
  categoryName: _optionalString(data['categoryName']),
  parentCategoryId: _optionalString(data['parentCategoryId']) ??
      _optionalString(data['parentId']),
  price: price.toInt(),
  isAvailable: true,
  metadata: _metadata(data),
);
```

Optional fields are normalized defensively. Missing `branchId` falls back to the requested branch. Missing availability defaults to available unless `isAvailable`, `availability`, or `status` explicitly marks the item out of stock. Archived items are removed before the catalog reaches the UI.

### Step 4 — Understand menu repository reads and streams

`getActiveMenu()` reads the nested restaurant menu collection, logs the path and IDs, loads the tenant category collection, and calls `_catalogFromDocuments()`. `watchActiveMenu()` maintains two listeners: one for menu items and one for categories. It emits a catalog whenever menu data is ready and either listener changes.

Category documents are filtered by branch and active/archive flags. If the customer cannot read the staff-managed categories collection, the repository does not fail the entire menu; it derives category records from menu-item fields. A child-only item can synthesize its parent from the item’s `category` or parent ID. This resilience is important under the current public-customer rules.

The merge algorithm has three sources of category information:

1. Menu item metadata, which is the fallback and supplies item-associated nodes.
2. Firestore category documents, which are canonical and can describe empty categories.
3. Synthesized parent records, which repair a missing parent when only child metadata is available.

### Step 5 — Follow `MenuBloc`

`MenuBloc` consumes `LoadMenu` and `RefreshMenu` events with a restaurant/branch pair. It emits `MenuLoading`, loads or watches `MenuCatalog`, and preserves `searchQuery` and `selectedCategoryId` when live data refreshes. `MenuCategoryChanged` carries a nullable stable ID; `null` means all categories. `MenuSearchChanged` updates the query without reloading Firestore.

Do not revert category selection to display names. Custom Admin categories can have colliding names, while IDs remain stable. A filter state is valid only if it refers to a category node in the current catalog; the UI handles a missing node as no category filter.

### Step 6 — Understand the drawer and filtering predicates

[`menu_page.dart`](../lib/features/menu/presentation/pages/menu_page.dart) builds a private `_CategoryNode` tree from `MenuCatalog.categories`. A node contains its own ID, name, children, and an item count. Parent counts include direct parent items and all descendant items. Direct parent items are represented by a synthesized `General` child when needed so visible child badges reconcile with the parent badge.

The parent filter expands to `selectedNode.allCategoryIds`. A child filter has an ID set containing only that child. Each menu item is included when its `categoryId` belongs to that set. This is the required behavior:

```dart
final selectedCategoryIds = selectedNode?.allCategoryIds ?? const {};
final filteredItems = catalog.items.where((item) {
  final matchesCategory = selectedNode == null ||
      selectedCategoryIds.contains(item.categoryId);
  final matchesSearch = normalizedSearch.isEmpty ||
      item.name.toLowerCase().contains(normalizedSearch);
  return matchesCategory && matchesSearch;
});
```

The UI renders parents with `ExpansionTile` when children exist and renders child tiles indented beneath them. Count badges are computed from IDs, never names. Search and category state live in `MenuBloc`, so opening/closing the cart sheet does not wipe the menu context.

### Step 7 — Follow add-to-cart

Menu cards dispatch `AddToCartEvent` to `CartBloc`. The `AddToCart` use case validates quantity and delegates to `CartRepository` only when persistence is requested by the surrounding cart flow. The UI immediately updates the quantity badge and shows lightweight feedback.

The cart’s `restaurantId`, `branchId`, `tableId`, `tableSessionId`, and `customerSessionId` originate from `_cartFromState()` in the router. If a new screen creates a cart independently, copy these fields from `SessionContext`; never use global defaults for a QR session.

### Step 8 — Follow cart persistence and submission

[`CartRepositoryImpl.saveCart()`](../lib/features/cart/data/cart_repository_impl.dart) canonicalizes the cart ID to `cart_{customerSessionId}` and writes the top-level `carts/{cartId}` document. The document includes tenant/table/session scope, item lines, quantity totals, subtotal, archive flags, and timestamps.

Before submission, `_canonicalizeMenuItemIds()` reads `restaurants/{restaurantId}/menu`, indexes both document IDs and legacy `data['id']` values, and rewrites a line to use the immutable document ID when a legacy ID is encountered. This prevents `A menu item is no longer available` failures caused by ID mismatch.

`submitOrder()` then sends the standard callable envelope:

```json
{
  "requestId": "cart_active-customer-session_...",
  "timestamp": "2026-08-25T...Z",
  "payload": {
    "restaurantId": "scanserve-demo",
    "customerSessionId": "active-customer-session",
    "cartId": "cart_active-customer-session"
  }
}
```

The backend reads the persisted cart and performs server-side price/menu validation. The client must not calculate or trust a final order total as authoritative.

### Step 9 — Understand the alternate customer repository

[`FirestoreCustomerRepository`](../lib/features/customer/data/firestore_customer_repository.dart) supports customer session initialization, menu retrieval for the legacy/customer flow, active-order listening, waiter/payment requests, and inline order submission. It writes the top-level customer session and can persist a cart before calling the same `submitOrder` function.

There are therefore two repository paths in the codebase:

| Flow | Repository | Main use |
|---|---|---|
| Menu/cart feature flow | `MenuRepositoryImpl` + `CartRepositoryImpl` | Current menu page, cart sheet, and standard cart submission. |
| Landing/customer facade flow | `FirestoreCustomerRepository` | Session creation, assistance, active-order lookup, and compatibility inline submission. |

When changing order fields, update both paths or explicitly retire one. The two paths must agree on canonical menu document IDs, cart IDs, session fields, notes, and callable envelopes.

## 6. Session, cart, and order data lifecycle

| Stage | Read/write | Scope that must be present |
|---|---|---|
| QR entry | Read URL only | Tenant, branch, table, token. |
| Session initialization | Write `customerSessions/{customerSessionId}` | Restaurant, branch, table, table session, active status, token metadata. |
| Menu load | Read nested `restaurants/{restaurantId}/menu` and `categories` | Restaurant and branch filtering. |
| Cart add/save | Write `carts/cart_{customerSessionId}` | Restaurant, branch, table, table session, customer session, item IDs. |
| Submit order | Call `submitOrder` | Request ID, restaurant, customer session, cart ID; item lines may be in cart or inline. |
| Backend order write | Backend writes mirrored orders | Restaurant, branch, table, table session, customer session, validated prices. |
| Customer tracking | Read nested restaurant orders | Table/customer session filters and active statuses. |

The Flutter client may create a development session when running against the emulator, but production business authorization remains a backend responsibility. A UI success state is not proof that Firestore writes or callable validation succeeded; inspect emulator documents and function logs when debugging.

## 7. Local development and debugging

### 7.1 Recommended startup

Start the Firebase emulators for Auth, Firestore, Functions, and the Emulator UI using the repository’s Firebase configuration. Then run the Flutter development target:

```bash
/home/ubuntu/flutter/bin/flutter run -d chrome --target lib/main_dev.dart
# or
/home/ubuntu/flutter/bin/flutter build web --target lib/main_dev.dart
```

The development bootstrap connects Firestore to `:8080` and Functions to `:5001`. If the browser runs inside a container or remote host, set `--dart-define=SCAN_SERVE_FIREBASE_EMULATOR_HOST=<reachable-host>` rather than assuming `127.0.0.1` is reachable from the browser.

A QR-style local test URL can use hash routing when the web server is configured for it:

```text
http://localhost:8083/#/menu?tenant=scanserve-demo&branch=main-branch&table=12&token=test-token
```

### 7.2 Logging points

The menu repository logs the menu path, restaurant/branch, document count, and document paths. The cart repository logs the canonical cart path, menu IDs, and callable response. Keep these logs during emulator debugging, but avoid logging secret tokens in production telemetry. If a menu item is visible but checkout fails, compare:

1. `MenuItem.id` in Flutter.
2. The actual Firestore document ID under `restaurants/{restaurantId}/menu`.
3. `CartItem.menuItemId` in the cart document.
4. `menuItemId` in the callable payload or cart line.
5. The backend nested menu lookup path.

### 7.3 Common failures

| Symptom | Likely cause | First inspection |
|---|---|---|
| Menu is empty | Wrong restaurant/branch, permission error, or archived/out-of-stock flags | Repository log and nested menu collection. |
| Child category missing | Category read denied or `parentCategoryId` absent/mismatched | Category document and menu item metadata. |
| Parent badge does not reconcile | Name-based grouping or direct parent items have no General bucket | `_CategoryNode` construction and ID predicates. |
| Cart submits the wrong item | Legacy `id` used instead of Firestore document ID | `_canonicalizeMenuItemIds()` log and cart document. |
| `Cart was not found` | Cart was not saved or ID omitted `cart_` prefix | `carts/{cartId}` document and callable payload. |
| Customer order is not visible | Order filters omit table/customer session or status differs in case | Nested order fields and `getActiveOrder()` query. |
| Web splash error | Native splash removal called on web | `main_common.dart` `kIsWeb` guard. |
| Red screen after tracking navigation | Context used after async sheet close | `context.mounted` checks around await/navigation. |

## 8. Testing and quality gates

Run the Flutter checks from the repository root:

```bash
/home/ubuntu/flutter/bin/flutter analyze
/home/ubuntu/flutter/bin/flutter test
/home/ubuntu/flutter/bin/flutter build web --target lib/main_dev.dart
```

The most valuable tests for this guide are:

- [`test/features/session/session_context_test.dart`](../test/features/session/session_context_test.dart): QR aliases, explicit IDs, and deterministic fallback IDs.
- [`test/features/menu/menu_page_test.dart`](../test/features/menu/menu_page_test.dart): parent aggregation, child filtering, nested drawer rendering, and General buckets.
- Menu BLoC tests: loading, refresh, search, and stable category-ID persistence.
- Cart/repository tests: canonical cart IDs and menu document-ID canonicalization.

When adding a new field, update the domain entity, DTO/mapper, repository, UI state, and a test fixture. Prefer a focused pure mapper or context test before writing a Firebase integration test. For Firestore integration, seed the emulator and assert both path and document ID; a document existing under the wrong parent path is functionally absent to the other application.

## 9. Maintenance rules for future engineers

Keep the canonical identifiers in `ScanServeFirestoreContract` and `docs/specifications/firestore-contract.md` synchronized. Do not introduce a new `tenantId`/`restaurantId` interpretation without updating Angular, backend, seed scripts, rules, and tests.

Treat `SessionContext` as the only route-to-domain boundary for QR identity. Do not parse `GoRouterState.uri.queryParameters` independently in widgets. If the deep-link contract changes, add an alias rather than removing the existing names until all printed QR tags have been rotated.

Use Firestore document IDs for entity identity and keep informational `id` fields only for compatibility. Do not use category labels as joins. Do not trust client prices or availability at checkout. Do not bypass the callable for order creation.

Prefer resilient reads that can tolerate missing optional fields, but do not silently accept a cross-tenant `restaurantId` or `branchId`. Add logging with path, tenant, branch, and document ID when diagnosing emulator issues; redact QR secrets outside local development.

## References

[^1]: [Flutter Architecture Specification — Part 1](../specifications/014-flutter-architecture-part-1.md) and [System Overview](../architecture/001-system-overview.md)
[^2]: [Firestore Contract](firestore-contract.md)
[^3]: [Flutter common bootstrap](../lib/main_common.dart)
[^4]: [Flutter service locator](../lib/core/di/service_locator.dart)
[^5]: [Flutter router](../lib/app/routes/router.dart)
[^6]: [Flutter SessionContext](../lib/features/session/domain/session_context.dart)
[^7]: [Flutter SessionBloc](../lib/features/session/presentation/bloc/session_bloc.dart)
[^8]: [Flutter menu repository](../lib/features/menu/data/menu_repository_impl.dart)
[^9]: [Flutter menu domain entities](../lib/features/menu/domain/menu_entities.dart)
[^10]: [Flutter menu BLoC](../lib/features/menu/presentation/bloc/menu_bloc.dart)
[^11]: [Flutter menu page](../lib/features/menu/presentation/pages/menu_page.dart)
[^12]: [Flutter cart repository](../lib/features/cart/data/cart_repository_impl.dart)
[^13]: [Flutter customer repository](../lib/features/customer/data/firestore_customer_repository.dart)
[^14]: [Flutter feature tests](../test/features)
