# ScanServe Angular Admin Dashboard — Developer Handover & System Learning Guide

**Audience:** Angular/TypeScript engineers maintaining the restaurant operations dashboard
**Primary source tree:** `apps/dashboard/src/`
**Author:** Manus AI
**Scope:** Authentication, protected routes, tenant/branch context, menu/category management, kitchen queue, staff assistance, table management, QR generation, and local emulator operation

## 1. Purpose and operating model

The Angular application is the authenticated restaurant-operations dashboard. It is responsible for menu maintenance, dynamic category management, table QR-tag generation, kitchen order operations, staff assistance resolution, and authenticated staff navigation. The customer PWA is anonymous and table-scoped; the dashboard is staff-authenticated and tenant-scoped.

The dashboard follows the project’s feature-first Clean Architecture boundary: route-loaded presentation components call signal stores or use cases; stores call domain repository abstractions; repository implementations own AngularFire/Firestore/Functions details. The domain contracts are intentionally independent of Firestore SDK objects.[^1]

> **Mental model:** `AuthService` establishes staff identity; `authGuard` protects operational routes; route parameters establish `restaurantId`; query parameters establish `branchId`; signal stores subscribe to repository streams; repositories map and validate Firestore documents; callable functions enforce sensitive mutations.

The canonical development tenant is `scanserve-demo`, with branch `main-branch`. Never hardcode these values into feature logic when the active route already provides them. Use [`restaurant-context.ts`](../apps/dashboard/src/app/shared/restaurant-context.ts) for normalization and fallback behavior.[^2]

## 2. Repository map

| Responsibility | Primary location | Maintainer notes |
|---|---|---|
| Standalone app providers | [`app.config.ts`](../apps/dashboard/src/app/app.config.ts) | Initializes Firebase providers, connects local emulators, and binds abstract repositories to implementations. |
| Route definitions | [`app.routes.ts`](../apps/dashboard/src/app/app.routes.ts) | Lazy-loads Kitchen, Menu, and Tables pages and applies `authGuard`. |
| Dashboard shell | [`app.html`](../apps/dashboard/src/app/app.html), [`app.ts`](../apps/dashboard/src/app/app.ts) | Provides Kitchen/Menu/Tables navigation and logout. |
| Staff auth facade | [`auth.service.ts`](../apps/dashboard/src/app/core/auth/auth.service.ts) | Exposes `authState$`, `user`, `isAuthenticated`, `signIn()`, and `signOut()`. |
| Route guard | [`auth.guard.ts`](../apps/dashboard/src/app/core/auth/auth.guard.ts) | Redirects unauthenticated users to `/login?redirect=<requested-url>`. |
| Menu domain/store | [`features/menu/domain`](../apps/dashboard/src/app/features/menu/domain), [`menu.store.ts`](../apps/dashboard/src/app/features/menu/presentation/state/menu.store.ts) | Holds menu CRUD state and save operations. |
| Menu Firestore adapter | [`menu-repository.impl.ts`](../apps/dashboard/src/app/features/menu/data/menu-repository.impl.ts) | Streams nested restaurant menu items and writes schema-complete documents. |
| Dynamic category adapter | [`menu-category-repository.impl.ts`](../apps/dashboard/src/app/features/menu/data/menu-category-repository.impl.ts) | Streams parent/child categories and creates inline child categories. |
| Kitchen domain/store | [`features/kitchen`](../apps/dashboard/src/app/features/kitchen) | Streams active orders and assistance requests, then calls status/resolve operations. |
| Table domain/store | [`features/tables`](../apps/dashboard/src/app/features/tables) | Streams branch-scoped tables and creates QR-tagged table records. |
| Test suites | `apps/dashboard/src/**/*.spec.ts` | Karma/ChromeHeadless tests cover stores, use cases, components, QR utilities, and auth. |

## 3. Application bootstrap and dependency injection

### 3.1 Firebase providers and emulator wiring

[`app.config.ts`](../apps/dashboard/src/app/app.config.ts) registers the Angular router, Firebase app, Auth, Firestore, and Functions. When the browser hostname is `localhost` or `127.0.0.1`, the providers connect to Auth `localhost:9099`, Firestore `localhost:8080`, and Functions `localhost:5001`.

The provider registration is the central dependency-injection map:

```typescript
provideFirebaseApp(() => initializeApp(environment.firebase)),
provideAuth(() => {
  const auth = getAuth();
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    connectAuthEmulator(auth, 'http://localhost:9099', { disableWarnings: true });
  }
  return auth;
}),
provideFirestore(() => {
  const firestore = getFirestore();
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    connectFirestoreEmulator(firestore, 'localhost', 8080);
  }
  return firestore;
}),
provideFunctions(() => {
  const functions = getFunctions();
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    connectFunctionsEmulator(functions, 'localhost', 5001);
  }
  return functions;
}),
```

The dashboard uses AngularFire DI tokens (`Firestore`, `Functions`, `Auth`) and the corresponding modular functions from AngularFire. Repository streams that use `onSnapshot` are wrapped in an Observable and created inside `runInInjectionContext`; this avoids Firebase API calls occurring outside an Angular injection context.

The same file binds the domain interfaces:

```typescript
{ provide: KitchenRepository, useClass: KitchenRepositoryImpl },
{ provide: MenuRepository, useClass: MenuRepositoryImpl },
{ provide: MenuCategoryRepository, useClass: MenuCategoryRepositoryImpl },
{ provide: TableRepository, useClass: TableRepositoryImpl },
```

When adding a new feature, register its abstract repository here rather than injecting a concrete Firestore adapter into a presentation component.

### 3.2 Local startup

The dashboard package’s development startup runs Auth and Firestore seed scripts before `ng serve`. The emulator seed creates the demo staff profile, canonical restaurant/branch metadata, categories, and menu items. A clean local run should therefore follow this order:

```bash
cd apps/dashboard
npm start
```

If emulators are managed separately, run the repository’s Firebase emulator configuration first, then use the seed commands directly. The Auth test account used by the dashboard checks is `staff@scanserve.com` with the local test password defined by the seed script. Treat this account as emulator-only credentials.

## 4. Authentication and route protection

### 4.1 `AuthService`

[`AuthService`](../apps/dashboard/src/app/core/auth/auth.service.ts) is a thin facade over Firebase Auth. It exposes the raw `authState$` stream and derives signals with `toSignal`:

```typescript
readonly authState$ = authState(this.auth);
private readonly authStateSignal = toSignal(this.authState$, {
  initialValue: this.auth.currentUser,
});

readonly user = computed<User | null>(() => this.authStateSignal());
readonly isAuthenticated = computed(() => this.user() !== null);
```

`signIn()` delegates to `signInWithEmailAndPassword`. `signOut()` calls Firebase `signOut`, clears `sessionStorage`, and navigates to `/login`. Any future staff-specific session state should be added to this facade rather than duplicated in Kitchen/Menu/Table components.

### 4.2 `authGuard`

[`authGuard`](../apps/dashboard/src/app/core/auth/auth.guard.ts) takes one value from `authState$`. Authenticated users receive `true`; unauthenticated users receive a `UrlTree` with the original URL in a `redirect` query parameter:

```typescript
return authService.authState$.pipe(
  take(1),
  map((user) =>
    user
      ? true
      : router.createUrlTree(['/login'], {
          queryParams: { redirect: state.url },
        }),
  ),
);
```

Kitchen is protected as `/kitchen/:restaurantId`. Menu and Tables use a guarded parent route with `canActivateChild`, covering both the empty route and `:restaurantId` child. The Login component reads the redirect target after successful sign-in. Preserve this behavior when adding new operational routes.

### 4.3 Security boundary

The route guard is a user-experience boundary, not a security boundary. Firestore Rules and backend callable authorization remain authoritative. In particular, the `updateOrderStatus` callable requires a Firebase Auth UID, then `OrderStatusService` checks a staff profile, tenant, branch, role, and `orders.updateStatus` permission. Do not interpret a visible dashboard route as permission to write arbitrary tenant data.

## 5. Multi-tenant and branch scoping

### 5.1 Route convention

Menu and Tables use the route form:

```text
/menu/{restaurantId}?branchId={branchId}
/tables/{restaurantId}?branchId={branchId}
```

The component combines `ActivatedRoute.paramMap` and `queryParamMap`, normalizes the restaurant ID, and falls back to `main-branch` only when no branch query parameter is present. The active scope is displayed in the editor/page so an operator can see which tenant is being modified.

A feature must pass both values through its store/repository call. A repository should normalize again at its boundary because it may be called outside the component.

### 5.2 Scope invariants

| Invariant | Correct implementation |
|---|---|
| Restaurant menu reads | `restaurants/{restaurantId}/menu` with normalized route restaurant ID. |
| Category reads | `restaurants/{restaurantId}/categories`, branch-filtered in the adapter. |
| Table reads/writes | `restaurants/{restaurantId}/tables`, queried/written with `branchId`. |
| Kitchen orders | `restaurants/{restaurantId}/orders`, filtered by restaurant and active status. |
| Assistance requests | `restaurants/{restaurantId}/waiterRequests`. |
| Callable status mutation | Payload carries the same restaurant ID as the route; backend resolves the staff profile and order tenant. |
| Branch updates | Menu create uses route branch; menu updates preserve the item’s active branch rather than moving the document implicitly. |

Cross-tenant data mixing is usually caused by a stale default ID, a store initialized only once, or a component reading the parent route incorrectly. Test route changes and query-parameter branch changes separately.

## 6. Menu and category architecture

### 6.1 Menu stream and CRUD

[`MenuRepositoryImpl`](../apps/dashboard/src/app/features/menu/data/menu-repository.impl.ts) watches `restaurants/{restaurantId}/menu` with a native Firestore `onSnapshot` Observable. The adapter creates the collection/query inside the subscription scope, maps `doc.id` to the domain ID, safely maps timestamps, and emits a sorted array. The stream is resilient to empty snapshots and mapping errors.

A create operation writes a schema-complete menu document, including:

```text
id
restaurantId
branchId
name
description
category
categoryId
categoryName
parentCategoryId
imageUrl
price
status = "in_stock"
availability = "in_stock" or selected availability
isAvailable
isArchived = false
archived = false
createdAt
updatedAt
```

It also upserts the parent restaurant and branch metadata required by local/demo flows. A blank image URL becomes a deterministic placeholder rather than a null image. Archive and availability operations update both the legacy-compatible flags and the canonical status fields.

The `MenuStore` owns `items`, `activeItems`, `loading`, `saving`, `savingIds`, and `error` signals. It initializes one stream for the current restaurant and wraps mutations in shared save/error tracking. The component should call store methods and should not call `setDoc`, `updateDoc`, or `onSnapshot` itself.

### 6.2 Dynamic category cascade

[`MenuCategoryRepositoryImpl`](../apps/dashboard/src/app/features/menu/data/menu-category-repository.impl.ts) exposes two domain methods:

```typescript
watchParentCategories(restaurantId, branchId)
watchSubCategories(restaurantId, branchId, parentCategoryId)
```

Both delegate to `watchCategories()`, which queries `restaurants/{restaurantId}/categories` with `where('parentCategoryId', '==', parentFilter)`, then filters by active branch and archive flags. Parent calls use `null`; child calls use the selected parent ID. Results are sorted by `displayOrder` and name.

The menu-management controller watches parent categories immediately, then cancels/replaces the child subscription whenever the parent changes. Selecting a parent clears any previous child/custom value. Selecting a child derives:

```text
category     = parent.name
categoryId   = child.id
categoryName = child.name
parentCategoryId = parent.id
```

Selecting `None (top-level item)` derives `categoryId = parent.id`, `categoryName = parent.name`, and `parentCategoryId = null`. If no children exist, the controller exposes an inline custom child name. On save, the custom child is created first with a deterministic ID such as `{parentId}-{slug}`, then the menu item is created with the new child metadata.

This two-level design preserves the Firestore schema used by Flutter’s category tree. Stable IDs are the join key; category names are display values only.

## 7. Table Management and QR module

### 7.1 Feature structure

The Table Management feature is in [`apps/dashboard/src/app/features/tables`](../apps/dashboard/src/app/features/tables):

```text
features/tables/
├── data/
│   └── table-repository.impl.ts
├── domain/
│   ├── table.ts
│   ├── table-link.ts
│   └── table-link.spec.ts
└── presentation/
    ├── components/
    │   ├── table-management.component.ts
    │   ├── table-management.component.html
    │   └── table-management.component.scss
    ├── qr-code.pipe.ts
    ├── qr-code.pipe.spec.ts
    └── state/
        ├── table.store.ts
        └── table.store.spec.ts
```

The page is lazy-loaded by the protected `/tables` route and is linked from the dashboard shell as **Tables & QR**.

### 7.2 Domain and Firestore schema

`RestaurantTable` contains `id`, `restaurantId`, `branchId`, `tableNo`, `zone`, `capacity`, `qrUrl`, `secretToken`, `status`, `createdAt`, and `updatedAt`. Creation accepts `tableNo`, `zone`, `capacity`, and optional branch input. The store overwrites the input branch with its initialized active branch to prevent a caller from moving a table into another branch accidentally.

The repository writes:

```text
restaurants/{restaurantId}/tables/{tableId}
```

with this data shape:

```json
{
  "id": "generated-firestore-id",
  "restaurantId": "scanserve-demo",
  "branchId": "main-branch",
  "tableNo": "12",
  "zone": "Main dining",
  "capacity": 2,
  "qrUrl": "https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12&token=...",
  "secretToken": "...",
  "status": "AVAILABLE",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

The live query uses `where('branchId', '==', activeBranchId)`, so a table from a different branch does not appear in the current branch view. Timestamp mapping falls back to `new Date()` when a server timestamp is still pending.

### 7.3 Secret-token generation

`createSecretToken()` prefers `globalThis.crypto.randomUUID()` and falls back to a timestamp/random string only when the Web Crypto API is unavailable. The token is generated once per table create operation and used to build the QR URL. Do not log or expose the token in operational logs beyond local development; it is a table-entry capability and should be treated as sensitive.

The URL builder is isolated in [`table-link.ts`](../apps/dashboard/src/app/features/tables/domain/table-link.ts):

```typescript
export const TABLE_QR_BASE_URL = 'https://scanserve.app/menu';

export function buildTableQrUrl(input: TableLinkInput): string {
  const queryParameters = new URLSearchParams({
    tenant: input.restaurantId,
    branch: input.branchId,
    table: input.tableNo,
    token: input.secretToken,
  });
  return `${TABLE_QR_BASE_URL}?${queryParameters.toString()}`;
}
```

Keeping URL construction in a pure utility makes the exact contract unit-testable and prevents the Firestore adapter and print view from drifting apart.

### 7.4 QR rendering and print tags

The `qrcode` npm package is used client-side. [`QrCodePipe`](../apps/dashboard/src/app/features/tables/presentation/qr-code.pipe.ts) converts each URL to a PNG data URL and caches the Observable by URL. The table card binds the resulting data URL to an `<img>`; no external QR service or network request is required for rendering.

The `Print QR tag` action in [`table-management.component.ts`](../apps/dashboard/src/app/features/tables/presentation/components/table-management.component.ts) calls `QRCode.toDataURL()` with medium error correction, opens a popup window, writes a minimal print document containing table number, zone, QR image, and deep link, then calls `printWindow.print()`. If popups are blocked, the store exposes a non-blocking error message. Preserve the HTML escaping around table metadata and URL text if the print layout changes.

### 7.5 Live table status binding

Table cards are fed by the live Firestore stream, so a later backend or staff operation that changes `status` to `OCCUPIED` or `INACTIVE` is reflected without a page reload. The current Admin feature creates `AVAILABLE` records and displays the streamed status; it does not yet expose a status-transition control. Adding one should be a separate repository/store mutation with a backend authorization decision, not a client-only status write.

## 8. Kitchen and staff assistance architecture

### 8.1 Kitchen queue

[`KitchenRepositoryImpl`](../apps/dashboard/src/app/features/kitchen/data/kitchen-repository.impl.ts) watches:

```text
restaurants/{restaurantId}/orders
```

The query constrains `restaurantId` and `status in ['PENDING', 'ACCEPTED', 'PREPARING', 'READY', 'SERVED']` according to the domain status set. It maps documents with `toKitchenOrder`, filters invalid rows, and sorts FIFO by `createdAt` ascending. Keep the stream alive through component/store error handling; a root-level `retry()` loop can leave loading state unresolved when the emulator is unavailable.

The kitchen store owns live orders, assistance requests, loading/error state, selected order, filters, new-order IDs, and toast/audio notification state. The presentation component renders the Kanban/queue view and advances status through `updateOrderStatus()` rather than updating Firestore directly.

### 8.2 Assistance requests

The assistance stream watches:

```text
restaurants/{restaurantId}/waiterRequests
```

for `OPEN` and `ACKNOWLEDGED` requests. The mapped request retains table/session identity and request type (`WAITER` or `PAYMENT`). Resolving a request updates the document to `RESOLVED` with `resolvedAt`. Customer creation and staff resolution permissions are defined in the Rules and should be tested against the emulator.

### 8.3 Callable status mutation

The Angular repository sends the shared callable envelope:

```typescript
{
  requestId: `${orderId}-${Date.now()}`,
  timestamp: new Date().toISOString(),
  payload: {
    restaurantId: resolvedRestaurantId,
    orderId,
    status: nextStatus,
  },
}
```

The backend validates the envelope, requires `request.auth.uid`, finds the staff profile, checks tenant/branch/role permission, enforces the transition map, and updates top-level and nested order records. See the backend handover guide for the authoritative decision path.

## 9. Testing and quality gates

Angular testing is layered around the same contract boundaries used by production code. Pure Jasmine specs prove deterministic URL and mapping utilities; repository/store specs replace Firebase adapters with synchronous or controllable Observables; component specs exercise standalone templates through `ComponentFixture`; full Karma runs catch template, DI, and browser integration errors; emulator E2E checks prove Auth, Rules, callable authorization, and Firestore paths agree with Flutter and the backend.

Run the dashboard checks from `apps/dashboard`:

```bash
npm run lint
CHROME_BIN=/usr/bin/chromium npm test -- --watch=false --browsers=ChromeHeadless
npm run build
```

Run one Karma spec while iterating by passing the project’s supported Jasmine filter or temporarily focusing the spec. Remove any `fit`/`fdescribe` before committing. The test command must remain headless in CI so template rendering and browser APIs are exercised consistently.

### 9.1 Test taxonomy and ownership

| Layer | Current example | What it proves | What it deliberately does not prove |
|---|---|---|---|
| Pure Jasmine | [`table-link.spec.ts`](../apps/dashboard/src/app/features/tables/domain/table-link.spec.ts) | Exact QR URL base, query-key contract, and URL encoding. | Firestore write or QR image rendering. |
| Pipe/utility | [`qr-code.pipe.spec.ts`](../apps/dashboard/src/app/features/tables/presentation/qr-code.pipe.spec.ts) | `qrcode` converts the canonical link to a PNG data URL. | Browser popup/printing and persisted table data. |
| Signal store | [`table.store.spec.ts`](../apps/dashboard/src/app/features/tables/presentation/state/table.store.spec.ts) | Repository stream initialization, signal settlement, and active-branch enforcement. | Firebase Rules or actual `onSnapshot`. |
| Component | [`menu-management.component.spec.ts`](../apps/dashboard/src/app/features/menu/presentation/components/menu-management.component.spec.ts) | Route scope, dynamic parent/child cascade, inline child creation, and payload fields. | Backend callable price/status enforcement. |
| Feature store/use case | Kitchen/Menu store specs | Loading/error/save state and delegation to domain repositories. | Deployed Functions and production Auth. |
| Emulator integration | Auth/Firestore/Functions startup plus seed | Real staff login, Rules, nested paths, callable auth, and transaction writes. | Browser/device performance and external notification delivery. |
| E2E | Angular + Flutter + Functions | Admin-created table/menu → QR customer session → order → kitchen transition. | A replacement for focused unit tests; diagnosis is slower. |

### 9.2 Pure URL contract test

[`table-link.spec.ts`](../apps/dashboard/src/app/features/tables/domain/table-link.spec.ts) is deliberately a pure test with no `TestBed`:

```typescript
describe('buildTableQrUrl', () => {
  it('builds the canonical tenant-scoped table deep link', () => {
    expect(
      buildTableQrUrl({
        restaurantId: 'scanserve-demo',
        branchId: 'main-branch',
        tableNo: '12 A',
        secretToken: 'secret+token',
      }),
    ).toBe(
      'https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12+A&token=secret%2Btoken',
    );
  });
});
```

The input contains a space and a plus sign specifically to prove `URLSearchParams` encoding. The expected string protects four things at once: the stable `https://scanserve.app/menu` base, the customer-facing keys `tenant`/`branch`/`table`/`token`, the order of serialized parameters, and correct escaping. This test is valuable because a QR tag can scan successfully while still routing to the wrong tenant if one key is renamed or omitted.

Add pure cases for an empty token policy, Unicode table labels, and any future canonical-key aliases. Do not call Firestore in this spec; URL construction must remain a deterministic domain utility.

### 9.3 QR pipe test and asynchronous Observables

[`qr-code.pipe.spec.ts`](../apps/dashboard/src/app/features/tables/presentation/qr-code.pipe.spec.ts) tests the pipe without a component fixture:

```typescript
it('renders a QR data URL for a table deep link', async () => {
  const dataUrl = await firstValueFrom(
    new QrCodePipe().transform(
      'https://scanserve.app/menu?tenant=scanserve-demo&branch=main-branch&table=12&token=test-token',
    ),
  );

  expect(dataUrl).toMatch(/^data:image\/png;base64,/);
});
```

`transform()` returns an Observable because QR generation is asynchronous. `firstValueFrom()` turns the first emission into a Promise, and `async/await` makes the spec fail if the Observable errors or never emits. The regular expression checks the data URL MIME/prefix and avoids asserting the entire base64 payload, which would be implementation-specific. Add an error-path test if the pipe exposes one; the expected behavior is a handled error state rather than a broken `<img>` binding.

### 9.4 Signal-store test with `TestBed` provider overrides

[`table.store.spec.ts`](../apps/dashboard/src/app/features/tables/presentation/state/table.store.spec.ts) is the canonical signal-store test. The fake repository implements the domain abstraction and returns `of([table])`, which emits synchronously and completes:

```typescript
class FakeTableRepository extends TableRepository {
  readonly table: RestaurantTable = {
    id: 'table-12',
    restaurantId: 'scanserve-demo',
    branchId: 'main-branch',
    tableNo: '12',
    zone: 'Main dining',
    capacity: 4,
    qrUrl: 'https://scanserve.app/menu?...',
    secretToken: 'test',
    status: 'AVAILABLE',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
  lastInput: CreateTableInput | null = null;

  override watchTables(): Observable<readonly RestaurantTable[]> {
    return of([this.table]);
  }

  override createTable(
    _restaurantId: string,
    input: CreateTableInput,
  ): Observable<RestaurantTable> {
    this.lastInput = input;
    return of(this.table);
  }
}
```

The spec replaces the production repository through Angular DI:

```typescript
TestBed.configureTestingModule({
  providers: [
    TableStore,
    { provide: TableRepository, useClass: FakeTableRepository },
  ],
});
const store = TestBed.inject(TableStore);
const repository = TestBed.inject(TableRepository) as FakeTableRepository;
```

`TestBed` creates the same injectable graph used by the application while `useClass` prevents any Firebase connection. The spec initializes scope and asserts signals as functions:

```typescript
store.initialize('scanserve-demo', 'main-branch');
expect(store.tables()).toEqual([repository.table]);
expect(store.loading()).toBeFalse();

store
  .create({
    tableNo: '13',
    zone: 'Patio',
    capacity: 2,
    branchId: 'other-branch',
  })
  .subscribe();

expect(repository.lastInput).toEqual({
  tableNo: '13',
  zone: 'Patio',
  capacity: 2,
  branchId: 'main-branch',
});
```

Calling `store.tables()` reads the current Angular Signal value; it is not a property access. The first assertion proves the synchronous stream reached the signal, and the second proves `loading` settled to false rather than remaining stuck. The final assertion is a security-oriented state test: a caller-supplied `other-branch` is rewritten to the active branch before the repository sees it.

If the fake uses `Subject` or `ReplaySubject` instead of `of`, retain the subject in the test and call `next()` after initialization. Then assert each signal after the emission and complete the subject in teardown. This tests live update propagation without opening a native Firestore listener.

### 9.5 ComponentFixture and dynamic menu form tests

[`menu-management.component.spec.ts`](../apps/dashboard/src/app/features/menu/presentation/components/menu-management.component.spec.ts) demonstrates how to test a standalone Angular component while keeping route and repositories deterministic. `imports: [MenuManagementComponent]` imports the standalone component directly; no NgModule is needed. `ComponentFixture<MenuManagementComponent>` owns the component instance and rendered DOM:

```typescript
let fixture: ComponentFixture<MenuManagementComponent>;
let component: MenuManagementComponent;
let repository: FakeMenuRepository;
let categoryRepository: FakeMenuCategoryRepository;

beforeEach(async () => {
  await TestBed.configureTestingModule({
    imports: [MenuManagementComponent],
    providers: [
      FakeMenuRepository,
      { provide: MenuRepository, useExisting: FakeMenuRepository },
      FakeMenuCategoryRepository,
      { provide: MenuCategoryRepository, useExisting: FakeMenuCategoryRepository },
      {
        provide: ActivatedRoute,
        useValue: {
          paramMap: of(convertToParamMap({ restaurantId: 'restaurant-1' })),
          queryParamMap: of(convertToParamMap({ branchId: 'branch-7' })),
        },
      },
    ],
  }).compileComponents();

  fixture = TestBed.createComponent(MenuManagementComponent);
  component = fixture.componentInstance;
  repository = TestBed.inject(FakeMenuRepository);
  categoryRepository = TestBed.inject(FakeMenuCategoryRepository);
  fixture.detectChanges();
});
```

The `useExisting` bindings ensure the token used by the component resolves to the same fake instance retrieved by the spec, so the test can inspect `createdInput`. The `ActivatedRoute` override emits `ParamMap` values through `of`, which simulates the route observables without a real router. `fixture.detectChanges()` runs the initial template/effect cycle and starts category subscriptions; omitting it can make the component appear uninitialized even though construction succeeded.

The fake category repository emits two parents and two children only when the requested parent is `mains`:

```typescript
override watchParentCategories(
  _restaurantId: string,
  _branchId: string,
): Observable<readonly MenuCategory[]> {
  return of(this.parents);
}

override watchSubCategories(
  _restaurantId: string,
  _branchId: string,
  parentCategoryId: string,
): Observable<readonly MenuCategory[]> {
  return of(parentCategoryId === 'mains' ? this.children : []);
}
```

The cascade assertion first proves route-scoped parent loading, then calls the same handler used by the template:

```typescript
expect(component.parentCategories().map((category) => category.id)).toEqual([
  'mains',
  'drinks',
]);

component.openCreate();
component.onParentCategoryChanged('mains');

expect(component.subCategories().map((category) => category.name)).toEqual([
  'Soups',
  'Spicy Noodles',
]);
```

The returned signal is read with `subCategories()`. This verifies both the Observable-to-signal update and the parent-ID cascade. The child payload test selects `mains-soups`, calls `save()`, and uses `jasmine.objectContaining`:

```typescript
expect(repository.createdInput).toEqual(
  jasmine.objectContaining({
    branchId: 'branch-7',
    category: 'Mains',
    categoryId: 'mains-soups',
    categoryName: 'Soups',
    parentCategoryId: 'mains',
    imageUrl: 'https://placehold.co/640x480/png?text=ScanServe+Dish',
    availability: 'in_stock',
  }),
);
```

`objectContaining` focuses the test on contract fields while allowing unrelated audit values to evolve. The inline-child test also checks the category repository input (`drinks-seasonal`, `parentCategoryId: 'drinks'`) before checking the menu payload. The root-category test asserts `parentCategoryId: null`, which prevents stale child selection from leaking into a top-level menu item.

### 9.6 RxJS stream testing: synchronous, async, and marble styles

Most current feature fakes use `of(...)` because it makes store tests deterministic and synchronous. Use `firstValueFrom()` for one asynchronous emission, `Subject`/`ReplaySubject` to control multiple emissions, and `fakeAsync`/`tick` when the production code schedules work with timers or Angular change detection.

A repository stream test with a controllable subject can look like this:

```typescript
it('updates the menu signal when a new snapshot arrives', fakeAsync(() => {
  const snapshots$ = new ReplaySubject<readonly MenuItem[]>(1);
  const repository = jasmine.createSpyObj<MenuRepository>('MenuRepository', [
    'watchMenu',
  ]);
  repository.watchMenu.and.returnValue(snapshots$.asObservable());

  TestBed.configureTestingModule({
    providers: [MenuStore, { provide: MenuRepository, useValue: repository }],
  });
  const store = TestBed.inject(MenuStore);

  store.initialize('scanserve-demo', 'main-branch');
  snapshots$.next([item('first')]);
  tick();
  expect(store.items().map((item) => item.name)).toEqual(['first']);

  snapshots$.next([item('first'), item('second')]);
  tick();
  expect(store.items()).toHaveSize(2);

  snapshots$.complete();
}));
```

Use `fakeAsync` only when the code under test requires virtual time; otherwise a normal spec with `firstValueFrom` is easier to understand. Always complete custom subjects in teardown to avoid listener leaks.

The repository does not currently check in marble tests, but marble testing is appropriate for complex debounce, retry, error-recovery, or combination logic. A `TestScheduler` test should describe cold inputs and expected output frames:

```typescript
it('debounces menu search before querying', () => {
  testScheduler.run(({ cold, expectObservable }) => {
    const search$ = cold('a--b----|', { a: 'ph', b: 'pho' });
    const result$ = search$.pipe(debounceTime(300, testScheduler));
    expectObservable(result$).toBe('---b---|', { b: 'pho' });
  });
});
```

Use the project’s RxJS version and inject the scheduler into operators that need deterministic virtual time. Do not add a marble test merely to test a Firestore `onSnapshot` wrapper; a subject-based repository fake better expresses the document-stream contract there.

### 9.7 Kitchen/Menu store and callable tests

Kitchen and Menu stores should be tested with three scenarios: initial synchronous/first snapshot, a later snapshot, and an error. Assert `loading()` becomes false on both data and handled-error paths. Assert the mapped item/order IDs, not only array length. For callable operations, replace the Functions adapter with a spy returning `of(successEnvelope)` or `throwError(() => error)`, call the store/use-case method, subscribe, and assert the exact payload contains restaurant ID, order ID, and permitted next status.

The kitchen status test should cover the production transition map: `PENDING → ACCEPTED → PREPARING → READY → SERVED`. A test that merely expects “the method was called” can miss an invalid jump or a stale tenant value. Add a negative assertion that an error response populates the store error signal and does not optimistically mutate the order status.

### 9.8 Angular emulator integration and E2E procedure

The current repository’s checked-in specs are primarily unit/component/store tests; emulator validation is an operational integration procedure rather than a large separate suite. Run it when changing Rules, callable payloads, Firestore paths, Auth, or seed data:

1. Start Auth, Firestore, and Functions emulators.
2. Run `cd backend && npm run seed:menu` and confirm the staff/Auth profile exists.
3. Load the dashboard against localhost and verify unauthenticated `/menu` redirects to `/login?redirect=%2Fmenu`.
4. Log in with the emulator staff account and confirm Kitchen, Menu, and Tables routes open.
5. Create or inspect a category and menu item under `restaurants/scanserve-demo`, then verify `categoryId`, `categoryName`, `parentCategoryId`, `branchId`, flags, and timestamps.
6. Create table 12 in `main-branch`; verify `restaurants/scanserve-demo/tables/{tableId}` and the exact QR URL.
7. Open the QR URL in Flutter, add the menu item, and verify `carts/cart_{customerSessionId}` uses the actual menu document ID.
8. Submit the order and verify both order mirrors plus `orderItems` and `orderRequests`.
9. Return to Angular Kitchen and advance each valid status through the callable. Confirm an invalid transition is rejected and the UI remains consistent.
10. Click Logout and verify Firebase Auth state is cleared and the next protected navigation returns to Login.

Do not use a browser screenshot alone to assert a write. Verify the actual document path, document ID, authenticated UID, callable response envelope, and all required fields. When an emulator integration fails, first compare path and ID values, then inspect Rules/function logs, then inspect mapper behavior.

### 9.9 Coverage additions checklist

When changing the QR contract, update the pure URL test with reserved-character cases and add a Flutter `SessionContext` round-trip case. When changing TableStore, keep one test for live stream settlement and one for active-branch rewriting. When changing menu category behavior, cover parent-only, child-selected, inline child, and explicit `null` parent cases. When changing a repository Observable, test first emission, subsequent emission, empty collection, mapping error, and unsubscribe behavior. When changing a callable payload, assert the exact tenant/order/status fields and test both success and error responses.

Do not use `TestBed` in pure functions or URL specs; it adds setup noise and hides what is deterministic. Do use `TestBed` for providers, route observables, standalone components, and signal stores. Keep fakes at domain boundaries so tests fail for contract mistakes rather than for Firebase SDK internals.

## 10. Troubleshooting playbook

| Symptom | Likely cause | Diagnostic action |
|---|---|---|
| Redirect to login | Auth emulator session missing or guard is correctly rejecting the request | Check Auth emulator, browser session, and `authState$`. |
| Table page is empty | Wrong branch query, missing `branchId`, or Firestore stream error | Inspect route URL, emulator data, and repository stream logs. |
| QR image is blank | `qrcode` generation rejected the URL or data URL Observable errored | Test `QrCodePipe` and inspect the table’s persisted `qrUrl`. |
| Print button does nothing | Browser popup blocked | Allow popups; the component reports a non-blocking error. |
| Table appears under wrong branch | Caller bypassed store scope or write omitted branch ID | Verify `TableStore.create()` and persisted `branchId`. |
| Dynamic category child missing | Child query uses a display label or wrong parent ID | Inspect `parentCategoryId` in category documents. |
| Kitchen stream shows zero orders | Nested order path/status mismatch or rules error | Compare order path and status casing with `KitchenRepositoryImpl`. |
| `updateOrderStatus` returns unauthorized | No staff profile, wrong branch, missing role permission, or auth emulator mismatch | Inspect `/staff` and `/roles`, then backend logs. |
| Firestore API injection error | SDK call created outside Angular injection context | Keep query/listener creation inside `runInInjectionContext`. |

## 11. Maintenance rules

Use route-derived tenant and branch scope for every feature. The default IDs are fallbacks for local navigation, not substitutes for active context. Keep the menu, category, table, kitchen, seed, Rules, Flutter, and backend contracts synchronized when changing a field or path.

Keep domain repositories framework-independent at the interface level. AngularFire types belong in `data/` implementations. Keep mapping tolerant of pending timestamps and optional legacy fields, but never let a mapper silently accept a document from another tenant or branch.

Use `onSnapshot` wrappers carefully. Firestore stream creation must be lazy at subscription time, and a mapping error should be observable and diagnosable without leaving the signal store in an indefinite loading state.

Treat QR tokens as sensitive capability values. They are needed by the customer route but should not be printed into application logs or analytics. If token validation is strengthened later, update the Flutter `SessionContext`, Firestore Rules, and callable/session logic together.

## References

[^1]: [Angular Architecture Specification — Part 1](./specifications/015-angular-architecture-part-1.md) and [System Overview](./architecture/001-system-overview.md)
[^2]: [Angular restaurant context](../apps/dashboard/src/app/shared/restaurant-context.ts)
[^3]: [Angular app providers](../apps/dashboard/src/app/app.config.ts)
[^4]: [Angular routes](../apps/dashboard/src/app/app.routes.ts)
[^5]: [Angular AuthService](../apps/dashboard/src/app/core/auth/auth.service.ts)
[^6]: [Angular auth guard](../apps/dashboard/src/app/core/auth/auth.guard.ts)
[^7]: [Angular menu repository](../apps/dashboard/src/app/features/menu/data/menu-repository.impl.ts)
[^8]: [Angular dynamic category repository](../apps/dashboard/src/app/features/menu/data/menu-category-repository.impl.ts)
[^9]: [Angular menu management component](../apps/dashboard/src/app/features/menu/presentation/components/menu-management.component.ts)
[^10]: [Angular kitchen repository](../apps/dashboard/src/app/features/kitchen/data/kitchen-repository.impl.ts)
[^11]: [Angular TableRepositoryImpl](../apps/dashboard/src/app/features/tables/data/table-repository.impl.ts)
[^12]: [Angular Table domain](../apps/dashboard/src/app/features/tables/domain/table.ts)
[^13]: [Angular QR URL utility](../apps/dashboard/src/app/features/tables/domain/table-link.ts)
[^14]: [Angular Table Management component](../apps/dashboard/src/app/features/tables/presentation/components/table-management.component.ts)
[^15]: [Angular QR code pipe](../apps/dashboard/src/app/features/tables/presentation/qr-code.pipe.ts)
[^16]: [Angular table tests](../apps/dashboard/src/app/features/tables)
[^17]: [Firestore contract](specifications/firestore-contract.md)
