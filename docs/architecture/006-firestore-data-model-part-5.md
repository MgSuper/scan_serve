# 24. Order Item Collection

Order Items represent the immutable products purchased within an Order.

Unlike Menu Items, Order Items are historical records.

They must preserve the exact information that existed at the time the customer submitted the order.

Future changes to the menu must never modify historical Order Items.

---

## Collection

```
orderItems
```

---

## Ownership

Order

---

## Lifecycle

```text
Created
    ↓
Immutable
```

After creation, Order Items should never be modified except for platform-level data correction performed by authorized administrators.

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Order Item identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| orderId | String | ✓ | Parent order. |
| menuItemId | String | ✓ | Original Menu Item reference. |
| categoryId | String | ✓ | Original Category reference. |
| name | String | ✓ | Product name snapshot. |
| unitPrice | Number | ✓ | Price at purchase time. |
| quantity | Number | ✓ | Purchased quantity. |
| lineTotal | Number | ✓ | Total amount for this item. |
| note | String | | Customer note. |
| modifiers | Array | | Future modifier support. |
| createdAt | Timestamp | ✓ | Creation timestamp. |

---

## Snapshot Strategy

Order Items intentionally duplicate business data.

The following values are copied from the Menu Item when the Order is created:

* Product name
* Product price
* Category
* Selected modifiers
* Customer note

Future edits to the Menu Item must never affect historical orders.

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard
* Cloud Functions
* Analytics

---

# 25. Staff Collection

The Staff collection stores authenticated restaurant employees.

Staff members access the Angular Administration Dashboard according to their assigned roles.

---

## Collection

```
staff
```

---

## Ownership

Restaurant

---

## Lifecycle

```text
Invited
    ↓
Active
    ↓
Disabled
    ↓
Archived
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Staff identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Primary branch. |
| authUid | String | ✓ | Firebase Authentication UID. |
| roleId | String | ✓ | Assigned role. |
| fullName | String | ✓ | Employee name. |
| email | String | ✓ | Login email. |
| phone | String | | Contact phone. |
| isActive | Boolean | ✓ | Employment status. |
| lastLoginAt | Timestamp | | Last successful login. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## References

Referenced by:

* Audit Logs *(future)*
* Orders *(future)*
* Activity History *(future)*

---

## Frequently Queried By

* Angular Dashboard
* Cloud Functions

---

# 26. Role Collection

Roles define the permissions granted to Staff members.

Roles remain independent from authentication.

This allows business permissions to evolve without changing authentication providers.

---

## Collection

```
roles
```

---

## Ownership

Restaurant

---

## Lifecycle

```text
Created
    ↓
Active
    ↓
Archived
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Role identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| name | String | ✓ | Role name. |
| description | String | | Role description. |
| permissions | Array | ✓ | Assigned permissions. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Example Roles

* Manager
* Kitchen Staff
* Waiter
* Cashier *(future)*

Detailed permission definitions are specified in **007 Security Model**.

---

# 27. Document Ownership Rules

Ownership determines:

* Lifecycle
* Authorization
* Security Rules
* Transaction boundaries
* Deletion behavior

Ownership must never be inferred from document references.

The following ownership hierarchy applies throughout the platform.

```text
Restaurant
│
├── Branch
│
├── Table
│
├── Table Session
│
├── Customer Session
│
├── Menu
│
├── Category
│
├── Menu Item
│
├── Order
│   └── Order Item
│
├── Staff
│
└── Role
```

Every business document ultimately belongs to exactly one Restaurant.

---

# 28. Reference Strategy

Relationships between business entities are represented using identifiers.

Example:

```
restaurantId
branchId
tableId
customerSessionId
orderId
```

Firestore `DocumentReference` objects are intentionally avoided.

Using identifiers provides several advantages:

* Simpler serialization
* Easier testing
* Better interoperability
* Reduced client complexity
* Straightforward data migration
* Language-independent implementations

References should always point to immutable document identifiers.

---

# 29. Denormalization Strategy

Cloud Firestore is optimized for read performance.

The ScanServe data model intentionally duplicates selected immutable data.

Examples include:

| Source | Copied Into |
|---------|-------------|
| Menu Item | Cart Item |
| Menu Item | Order Item |
| Category | Order Item |
| Restaurant | Analytics *(future)* |

Denormalization is permitted only when it improves read efficiency or preserves historical accuracy.

Mutable business information should not be duplicated unless justified by measurable performance benefits.

---

# 30. Metadata Standards

Business documents should use consistent metadata fields.

| Field | Description |
|-------|-------------|
| createdAt | Initial creation timestamp. |
| updatedAt | Most recent modification timestamp. |
| createdBy | Staff or system responsible for creation. |
| updatedBy | Staff or system responsible for last modification. |
| isArchived | Indicates whether the document is archived. |

Documents should not introduce custom metadata unless required by the business domain.

Consistency simplifies client implementation and administrative tooling.